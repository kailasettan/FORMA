import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import sessionmaker

from app.database import get_db
from app.main import app
from app.models import (
    Base,
    Drop,
    DropComment,
    DropProp,
    OrphanedCloudinaryAsset,
    PlayerProfile,
    ScoutShortlist,
    SportCatalog,
    SportCategory,
    User,
)
from app.security import hash_password

# Testing database URL
TEST_DATABASE_URL = "postgresql+psycopg://localhost:5432/forma_test"
from app.config import settings
settings.database_url = TEST_DATABASE_URL

engine = create_engine(TEST_DATABASE_URL)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    # Create extensions first
    with engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS citext"))
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto"))
        conn.commit()

    # Drop and recreate tables
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    # Seed sports
    db = TestingSessionLocal()
    sports_data = [
        {"name": "Football", "slug": "football"},
        {"name": "Cricket", "slug": "cricket"},
        {"name": "Basketball", "slug": "basketball"},
        {"name": "Athletics", "slug": "athletics"},
        {"name": "Swimming", "slug": "swimming"},
        {"name": "Volleyball", "slug": "volleyball"},
    ]
    
    categories_data = {
        "football": ["dribbling", "finishing", "passing", "defending", "goalkeeping"],
        "cricket": ["batting", "pace bowling", "spin bowling", "fielding"],
        "basketball": ["shooting", "ball handling", "passing", "defending"],
        "athletics": ["sprinting", "jumping", "throwing"],
        "swimming": ["freestyle", "backstroke", "breaststroke", "butterfly"],
        "volleyball": [
            "serving",
            "setting",
            "spiking",
            "blocking",
            "digging",
            "receiving",
            "defense",
            "match highlight",
            "training drill",
        ],
    }

    for sport in sports_data:
        sp = SportCatalog(name=sport["name"], slug=sport["slug"], is_active=True)
        db.add(sp)
        db.flush()
        
        if sport["slug"] in categories_data:
            for idx, cat_name in enumerate(categories_data[sport["slug"]]):
                cat = SportCategory(
                    sport_id=sp.id,
                    name=cat_name.title(),
                    slug=cat_name.lower().replace(" ", "_"),
                    is_active=True,
                    display_order=idx
                )
                db.add(cat)
                
    db.commit()
    db.close()
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(autouse=True)
def clean_tables():
    # Clean tables after each test to ensure isolation
    db = TestingSessionLocal()
    db.execute(text("TRUNCATE TABLE scout_shortlists, orphaned_cloudinary_assets, drop_comments, drop_props, drops, player_profiles, users CASCADE"))
    db.commit()
    db.close()


# Override get_db dependency
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


def create_test_user(username: str, role: str = "athlete") -> tuple[User, str]:
    db = TestingSessionLocal()
    user = User(
        username=username,
        email=f"{username}@example.com",
        password_hash=hash_password("password123"),
        full_name=f"{username.capitalize()} Test",
        role=role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    db.close()
    
    # Login to get token
    response = client.post("/auth/login", json={"email": f"{username}@example.com", "password": "password123"})
    token = response.json()["access_token"]
    return user, token


def test_signup_missing_role_creates_athlete_user():
    response = client.post(
        "/auth/signup",
        json={
            "username": "beta_athlete",
            "email": "beta_athlete@example.com",
            "password": "password123",
            "full_name": "Beta Athlete",
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["user"]["role"] == "athlete"

    db = TestingSessionLocal()
    try:
        user = db.scalar(select(User).where(User.username == "beta_athlete"))
        assert user is not None
        assert user.role == "athlete"
    finally:
        db.close()


def test_signup_rejects_public_scout_role():
    response = client.post(
        "/auth/signup",
        json={
            "username": "public_scout",
            "email": "public_scout@example.com",
            "password": "password123",
            "full_name": "Public Scout",
            "role": "scout",
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Scout accounts cannot be created from public signup."

    db = TestingSessionLocal()
    try:
        user = db.scalar(select(User).where(User.username == "public_scout"))
        assert user is None
    finally:
        db.close()


def test_signed_upload_signature_requires_auth():
    # Unauthenticated should receive 401
    response = client.post("/drops/upload-signature")
    assert response.status_code == 401


def test_upload_signature_excludes_api_secret():
    _, token = create_test_user("athlete_a")
    headers = {"Authorization": f"Bearer {token}"}
    
    response = client.post("/drops/upload-signature", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert "signature" in data
    assert "timestamp" in data
    assert data["resource_type"] == "video"
    # API Secret should not be anywhere in the payload keys or values
    assert "api_secret" not in data
    # Default secret in test environment is change-me-in-production
    assert "change-me-in-production" not in data.values()


def test_profile_photo_upload_signature_route_is_registered_once():
    matching_routes = [
        route
        for route in app.routes
        if getattr(route, "path", None) == "/uploads/profile-photo/signature"
        and "POST" in getattr(route, "methods", set())
    ]

    assert len(matching_routes) == 1


def test_profile_photo_upload_signature_requires_auth():
    response = client.post("/uploads/profile-photo/signature")
    assert response.status_code == 401


def test_profile_photo_upload_signature_excludes_api_secret():
    user, token = create_test_user("athlete_a")
    headers = {"Authorization": f"Bearer {token}"}

    response = client.post("/uploads/profile-photo/signature", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["folder"] == "forma/profile_photos"
    assert "upload_preset" not in data or data["upload_preset"] is None
    assert data["resource_type"] == "image"
    assert data["allowed_formats"] == "jpg,jpeg,png,webp"
    assert data["public_id"] == f"profile_{user.id}"
    assert "signature" in data
    assert "timestamp" in data
    assert "api_secret" not in data
    assert "change-me-in-production" not in data.values()


def test_volleyball_catalog_is_available():
    _, token = create_test_user("athlete_a")
    headers = {"Authorization": f"Bearer {token}"}

    sports_response = client.get("/sports", headers=headers)
    assert sports_response.status_code == 200
    volleyball = next(
        (sport for sport in sports_response.json() if sport["slug"] == "volleyball"),
        None,
    )
    assert volleyball is not None
    assert volleyball["name"] == "Volleyball"
    assert volleyball["is_active"] is True

    categories_response = client.get(f"/sports/{volleyball['id']}/categories", headers=headers)
    assert categories_response.status_code == 200
    assert [category["name"] for category in categories_response.json()] == [
        "Serving",
        "Setting",
        "Spiking",
        "Blocking",
        "Digging",
        "Receiving",
        "Defense",
        "Match Highlight",
        "Training Drill",
    ]


def test_drop_creation_verifies_cloudinary_metadata():
    athlete, token = create_test_user("athlete_a")
    headers = {"Authorization": f"Bearer {token}"}

    # Fetch football sport id
    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    sport_id = str(sport.id)
    category = db.query(SportCategory).filter_by(sport_id=sport.id, slug="dribbling").first()
    category_id = str(category.id)
    db.close()

    # Valid creation payload (verified through mock bypass or local validations in test mode)
    payload = {
        "provider_asset_id": "asset_123",
        "public_id": "forma/skill_clips/drop_123",
        "playback_url": "https://res.cloudinary.com/nyuzzi3x/video/upload/v1/drop_123.mp4",
        "thumbnail_url": "https://res.cloudinary.com/nyuzzi3x/video/upload/v1/drop_123.jpg",
        "duration_seconds": 15.5,
        "width": 1080,
        "height": 1920,
        "format": "mp4",
        "bytes": 1024 * 1024 * 5,  # 5MB
        "sport_id": sport_id,
        "category_id": category_id,
        "caption": "Check my dribbling!",
        "visibility": "public"
    }

    # Valid drop creation
    response = client.post("/drops", json=payload, headers=headers)
    assert response.status_code == 201
    drop_data = response.json()
    assert drop_data["public_id"] == "forma/skill_clips/drop_123"
    assert drop_data["playback_url"] == payload["playback_url"]

    # Re-submitting the same asset is idempotent for the owner.
    response2 = client.post("/drops", json=payload, headers=headers)
    assert response2.status_code == 201
    assert response2.json()["id"] == drop_data["id"]

    payload_same_asset = payload.copy()
    payload_same_asset["public_id"] = "forma/skill_clips/drop_123_retry"
    response3 = client.post("/drops", json=payload_same_asset, headers=headers)
    assert response3.status_code == 201
    assert response3.json()["id"] == drop_data["id"]

    db = TestingSessionLocal()
    assert db.query(Drop).filter_by(provider_asset_id="asset_123").count() == 1
    db.close()

    user_drops = client.get(f"/users/{athlete.id}/drops", headers=headers)
    assert user_drops.status_code == 200
    assert drop_data["id"] in {drop["id"] for drop in user_drops.json()}

    feed = client.get("/drops/feed", headers=headers)
    assert feed.status_code == 200
    assert drop_data["id"] in {drop["id"] for drop in feed.json()["items"]}


def test_drop_creation_validation_limits():
    athlete, token = create_test_user("athlete_a")
    headers = {"Authorization": f"Bearer {token}"}

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    sport_id = str(sport.id)
    db.close()

    base_payload = {
        "provider_asset_id": "asset_123",
        "public_id": "forma/skill_clips/drop_123",
        "playback_url": "https://res.cloudinary.com/nyuzzi3x/video/upload/v1/drop_123.mp4",
        "sport_id": sport_id,
        "format": "mp4",
        "bytes": 1024 * 1024 * 5,
        "duration_seconds": 15.5
    }

    # Rejects duration > 60s
    payload = base_payload.copy()
    payload["duration_seconds"] = 60.1
    response = client.post("/drops", json=payload, headers=headers)
    assert response.status_code == 422
    assert "longer than 60 seconds" in response.json()["detail"]

    # Rejects bytes > 50MB
    payload = base_payload.copy()
    payload["bytes"] = 50 * 1024 * 1024 + 1
    response = client.post("/drops", json=payload, headers=headers)
    assert response.status_code == 422
    assert "exceeds the 50 MB limit" in response.json()["detail"]

    # Rejects invalid formats
    payload = base_payload.copy()
    payload["format"] = "avi"
    response = client.post("/drops", json=payload, headers=headers)
    assert response.status_code == 422
    assert "format must be one of: mp4, mov, webm" in response.json()["detail"]

    db = TestingSessionLocal()
    orphan = (
        db.query(OrphanedCloudinaryAsset)
        .filter_by(provider_asset_id="asset_123")
        .first()
    )
    assert orphan is not None
    assert orphan.status == "pending_cleanup"
    db.close()


def test_only_owner_can_delete_drop():
    athlete_a, token_a = create_test_user("athlete_a")
    athlete_b, token_b = create_test_user("athlete_b")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    
    # Create Drop owned by A
    drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_a",
        public_id="drop_a",
        playback_url="url",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public"
    )
    db.add(drop)
    db.commit()
    db.refresh(drop)
    drop_id = str(drop.id)
    db.close()

    # B tries to delete A's Drop -> Forbidden
    headers_b = {"Authorization": f"Bearer {token_b}"}
    response = client.delete(f"/drops/{drop_id}", headers=headers_b)
    assert response.status_code == 403

    # A deletes own Drop -> Success
    headers_a = {"Authorization": f"Bearer {token_a}"}
    response = client.delete(f"/drops/{drop_id}", headers=headers_a)
    assert response.status_code == 204


def test_owner_can_delete_player_profile_without_deleting_user_or_drops():
    athlete_a, token_a = create_test_user("athlete_a")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    profile = PlayerProfile(
        user_id=athlete_a.id,
        sport_id=sport.id,
        role_or_discipline="Striker",
        skill_level="advanced",
    )
    db.add(profile)
    db.flush()
    drop = Drop(
        user_id=athlete_a.id,
        player_profile_id=profile.id,
        sport_id=sport.id,
        provider_asset_id="asset_a",
        public_id="drop_a",
        playback_url="url",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public",
    )
    db.add(drop)
    db.commit()
    profile_id = profile.id
    drop_id = drop.id
    user_id = athlete_a.id
    db.close()

    headers_a = {"Authorization": f"Bearer {token_a}"}
    response = client.delete(f"/player-profiles/{profile_id}", headers=headers_a)
    assert response.status_code == 204

    db = TestingSessionLocal()
    try:
        assert db.get(PlayerProfile, profile_id) is None
        assert db.get(User, user_id) is not None
        saved_drop = db.get(Drop, drop_id)
        assert saved_drop is not None
        assert saved_drop.user_id == user_id
        assert saved_drop.player_profile_id is None
    finally:
        db.close()


def test_another_user_cannot_delete_player_profile():
    athlete_a, _ = create_test_user("athlete_a")
    _, token_b = create_test_user("athlete_b")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    profile = PlayerProfile(
        user_id=athlete_a.id,
        sport_id=sport.id,
        role_or_discipline="Striker",
        skill_level="advanced",
    )
    db.add(profile)
    db.commit()
    profile_id = profile.id
    db.close()

    headers_b = {"Authorization": f"Bearer {token_b}"}
    response = client.delete(f"/player-profiles/{profile_id}", headers=headers_b)
    assert response.status_code == 403

    db = TestingSessionLocal()
    try:
        assert db.get(PlayerProfile, profile_id) is not None
    finally:
        db.close()


def test_private_drop_not_visible_publicly():
    athlete_a, token_a = create_test_user("athlete_a")
    athlete_b, token_b = create_test_user("athlete_b")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    
    # Create Private Drop owned by A
    drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_a",
        public_id="drop_a",
        playback_url="url",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="private"
    )
    db.add(drop)
    db.commit()
    db.refresh(drop)
    drop_id = str(drop.id)
    db.close()

    # B tries to get Drop -> Forbidden
    headers_b = {"Authorization": f"Bearer {token_b}"}
    response = client.get(f"/drops/{drop_id}", headers=headers_b)
    assert response.status_code == 403

    # B fetches public profile of A -> Drop should not be returned
    response_profile = client.get(f"/users/{athlete_a.id}/public-profile", headers=headers_b)
    assert response_profile.status_code == 200
    assert len(response_profile.json()["drops"]) == 0

    # A fetches own public profile -> Private Drop should be returned
    headers_a = {"Authorization": f"Bearer {token_a}"}
    response_profile_own = client.get(f"/users/{athlete_a.id}/public-profile", headers=headers_a)
    assert response_profile_own.status_code == 200
    assert len(response_profile_own.json()["drops"]) == 1


def test_user_drops_public_profile_and_feed_visibility():
    athlete_a, token_a = create_test_user("athlete_a")
    athlete_b, token_b = create_test_user("athlete_b")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    public_drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_public",
        public_id="drop_public",
        playback_url="https://example.com/public.mp4",
        thumbnail_url="https://example.com/public.jpg",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public",
        moderation_status="approved",
    )
    private_drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_private",
        public_id="drop_private",
        playback_url="https://example.com/private.mp4",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="private",
        moderation_status="approved",
    )
    rejected_drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_rejected",
        public_id="drop_rejected",
        playback_url="https://example.com/rejected.mp4",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public",
        moderation_status="rejected",
    )
    db.add_all([public_drop, private_drop, rejected_drop])
    db.commit()
    db.close()

    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    own_drops = client.get(f"/users/{athlete_a.id}/drops", headers=headers_a)
    assert own_drops.status_code == 200
    own_public_ids = {drop["public_id"] for drop in own_drops.json()}
    assert own_public_ids == {"drop_public", "drop_private"}

    other_drops = client.get(f"/users/{athlete_a.id}/drops", headers=headers_b)
    assert other_drops.status_code == 200
    other_public_ids = {drop["public_id"] for drop in other_drops.json()}
    assert other_public_ids == {"drop_public"}

    public_profile = client.get(f"/users/{athlete_a.id}/public-profile", headers=headers_b)
    assert public_profile.status_code == 200
    profile_public_ids = {drop["public_id"] for drop in public_profile.json()["drops"]}
    assert profile_public_ids == {"drop_public"}

    feed = client.get("/drops/feed", headers=headers_b)
    assert feed.status_code == 200
    feed_public_ids = {drop["public_id"] for drop in feed.json()["items"]}
    assert feed_public_ids == {"drop_public"}


def test_props_uniqueness_and_toggling():
    athlete_a, token_a = create_test_user("athlete_a")
    athlete_b, token_b = create_test_user("athlete_b")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    
    # Create Drop owned by A
    drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_a",
        public_id="drop_a",
        playback_url="url",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public"
    )
    db.add(drop)
    db.commit()
    db.refresh(drop)
    drop_id = str(drop.id)
    db.close()

    # B gives props -> Success
    headers_b = {"Authorization": f"Bearer {token_b}"}
    response = client.post(f"/drops/{drop_id}/props", headers=headers_b)
    assert response.status_code == 201

    # B tries to give props again -> Bad Request (duplicate)
    response_dup = client.post(f"/drops/{drop_id}/props", headers=headers_b)
    assert response_dup.status_code == 400

    # Retrieve drop details -> count is 1
    response_drop = client.get(f"/drops/{drop_id}", headers=headers_b)
    assert response_drop.json()["props_count"] == 1
    assert response_drop.json()["has_propped"] is True

    # B removes props -> Success
    response_del = client.delete(f"/drops/{drop_id}/props", headers=headers_b)
    assert response_del.status_code == 204

    # Retrieve drop details -> count is 0
    response_drop = client.get(f"/drops/{drop_id}", headers=headers_b)
    assert response_drop.json()["props_count"] == 0
    assert response_drop.json()["has_propped"] is False


def test_comment_creation_validation_and_deletion_ownership():
    athlete_a, token_a = create_test_user("athlete_a")
    athlete_b, token_b = create_test_user("athlete_b")
    athlete_c, token_c = create_test_user("athlete_c")

    db = TestingSessionLocal()
    sport = db.query(SportCatalog).filter_by(slug="football").first()
    
    # Create Drop owned by A
    drop = Drop(
        user_id=athlete_a.id,
        sport_id=sport.id,
        provider_asset_id="asset_a",
        public_id="drop_a",
        playback_url="url",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public"
    )
    db.add(drop)
    db.commit()
    db.refresh(drop)
    drop_id = str(drop.id)
    db.close()

    # B comments with empty text -> Bad Request
    headers_b = {"Authorization": f"Bearer {token_b}"}
    response_empty = client.post(f"/drops/{drop_id}/comments", json={"body": "  "}, headers=headers_b)
    assert response_empty.status_code == 400

    # B comments with valid text -> Success
    response_comment = client.post(f"/drops/{drop_id}/comments", json={"body": "Great run!"}, headers=headers_b)
    assert response_comment.status_code == 201
    comment_id = response_comment.json()["id"]

    # C tries to delete B's comment -> Forbidden
    headers_c = {"Authorization": f"Bearer {token_c}"}
    response_forbidden = client.delete(f"/drops/{drop_id}/comments/{comment_id}", headers=headers_c)
    assert response_forbidden.status_code == 403

    # B deletes own comment -> Success
    response_del_b = client.delete(f"/drops/{drop_id}/comments/{comment_id}", headers=headers_b)
    assert response_del_b.status_code == 204

    # Re-post comment
    response_comment2 = client.post(f"/drops/{drop_id}/comments", json={"body": "Nice!"}, headers=headers_b)
    comment_id2 = response_comment2.json()["id"]

    # A (Drop Owner) deletes B's comment (moderation) -> Success
    headers_a = {"Authorization": f"Bearer {token_a}"}
    response_del_a = client.delete(f"/drops/{drop_id}/comments/{comment_id2}", headers=headers_a)
    assert response_del_a.status_code == 204


def test_scout_only_shortlist_access_and_privacy():
    athlete_a, token_a = create_test_user("athlete_a")
    scout_c, token_c = create_test_user("scout_c", role="scout")

    # Athlete A tries to shortlist -> Forbidden
    headers_a = {"Authorization": f"Bearer {token_a}"}
    response_a = client.post(f"/scout/shortlist/{athlete_a.id}", headers=headers_a)
    assert response_a.status_code == 403

    # Scout C shortlists Athlete A -> Success
    headers_c = {"Authorization": f"Bearer {token_c}"}
    response_c = client.post(f"/scout/shortlist/{athlete_a.id}", json={"private_note": "Future star!"}, headers=headers_c)
    assert response_c.status_code == 201
    assert response_c.json()["private_note"] == "Future star!"

    # Athlete A views own public profile -> is_shortlisted and private notes are completely absent
    response_profile_a = client.get(f"/users/{athlete_a.id}/public-profile", headers=headers_a)
    assert response_profile_a.status_code == 200
    profile_data = response_profile_a.json()
    assert profile_data["is_shortlisted"] is False
    assert "private_note" not in profile_data

    # Scout C views Athlete A public profile -> is_shortlisted is True
    response_profile_c = client.get(f"/users/{athlete_a.id}/public-profile", headers=headers_c)
    assert response_profile_c.status_code == 200
    assert response_profile_c.json()["is_shortlisted"] is True


def test_username_search_case_insensitivity_and_ranking():
    athlete_b, token_b = create_test_user("athlete_b")
    athlete_best, token_best = create_test_user("athlete_best")

    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Search with partial prefix "ATHLETE" (case-insensitive)
    response = client.get("/users/search?q=ATHLETE", headers=headers_b)
    assert response.status_code == 200
    results = response.json()
    assert len(results) >= 2
    
    # Exact match for "athlete_b" should rank first if searched for "athlete_b"
    response_exact = client.get("/users/search?q=athlete_b", headers=headers_b)
    assert response_exact.status_code == 200
    results_exact = response_exact.json()
    assert results_exact[0]["username"] == "athlete_b"
