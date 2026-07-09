import uuid
import pytest
from fastapi import HTTPException, status
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
    EmailOTP,
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


@pytest.fixture(autouse=True)
def mock_send_email():
    from unittest.mock import patch
    with patch("app.routers.auth.send_otp_email") as mock:
        yield mock


# Override get_db dependency
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_signup_verification_setting():
    original = settings.require_signup_email_verification
    settings.require_signup_email_verification = True
    yield
    settings.require_signup_email_verification = original


def create_test_user(username: str, role: str = "athlete") -> tuple[User, str]:
    db = TestingSessionLocal()
    user = User(
        username=username,
        email=f"{username}@example.com",
        password_hash=hash_password("password123"),
        full_name=f"{username.capitalize()} Test",
        role=role,
        email_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    db.close()
    
    # Login to get token
    response = client.post("/auth/login", json={"identifier": f"{username}@example.com", "password": "password123"})
    token = response.json()["access_token"]
    return user, token


def test_debug_version_exposes_safe_deployment_state():
    response = client.get("/debug/version")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "environment" in data
    assert "commit" in data
    assert "resend_key_present" in data
    assert "from_email_configured" in data
    assert "from_name_configured" in data
    assert "RESEND_API_KEY" not in data


def test_cors_allows_local_flutter_web_preflight():
    response = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:54321",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:54321"
    assert "GET" in response.headers["access-control-allow-methods"]
    assert "Authorization" in response.headers["access-control-allow-headers"]
    assert "Content-Type" in response.headers["access-control-allow-headers"]


def test_cors_allows_nadha_labs_origin():
    response = client.get("/health", headers={"Origin": "https://nadhalabs.com"})

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "https://nadhalabs.com"


def test_cors_rejects_unlisted_origin():
    response = client.get("/health", headers={"Origin": "https://example.com"})

    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers


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


@pytest.mark.parametrize("username", ["kailas", "kailas07", "kailas_07", "kailas.07"])
def test_signup_accepts_valid_usernames(username):
    response = client.post(
        "/auth/signup",
        json={
            "username": username,
            "email": f"{username.replace('.', '_')}@example.com",
            "password": "password123",
            "full_name": "Valid User",
            "role": "athlete",
        },
    )

    assert response.status_code == 201
    assert response.json()["user"]["username"] == username


def test_signup_normalizes_uppercase_username_before_saving():
    response = client.post(
        "/auth/signup",
        json={
            "username": "  Kailas07  ",
            "email": "normalized_username@example.com",
            "password": "password123",
            "full_name": "Normalized User",
            "role": "athlete",
        },
    )

    assert response.status_code == 201
    assert response.json()["user"]["username"] == "kailas07"

    db = TestingSessionLocal()
    try:
        user = db.scalar(select(User).where(User.username == "kailas07"))
        assert user is not None
    finally:
        db.close()


@pytest.mark.parametrize(
    "username",
    [
        "kailas 07",
        "kailas-07",
        "kailas@07",
        ".kailas",
        "kailas.",
        "_kailas",
        "kailas_",
        "ka",
        "kailas..07",
        "a" * 31,
    ],
)
def test_signup_rejects_invalid_usernames(username):
    response = client.post(
        "/auth/signup",
        json={
            "username": username,
            "email": "invalid_username@example.com",
            "password": "password123",
            "full_name": "Invalid User",
            "role": "athlete",
        },
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Username can only use lowercase letters, numbers, dots, and underscores."


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


def test_password_is_hashed_not_stored_plain_text():
    response = client.post(
        "/auth/signup",
        json={
            "username": "hash_test_user",
            "email": "hash_test@example.com",
            "password": "my_secret_password_123",
            "full_name": "Hash Test User",
            "role": "athlete"
        }
    )
    assert response.status_code == 201

    db = TestingSessionLocal()
    try:
        user = db.scalar(select(User).where(User.username == "hash_test_user"))
        assert user is not None
        assert user.password_hash != "my_secret_password_123"
        # Verify it is indeed a bcrypt hash
        from app.security import verify_password
        assert verify_password("my_secret_password_123", user.password_hash)
    finally:
        db.close()


def test_signup_duplicate_email_rejected():
    # First signup
    client.post(
        "/auth/signup",
        json={
            "username": "unique_user1",
            "email": "duplicate@example.com",
            "password": "password123",
            "full_name": "Unique One",
            "role": "athlete"
        }
    )

    # Second signup with same email, different username
    response = client.post(
        "/auth/signup",
        json={
            "username": "unique_user2",
            "email": "duplicate@example.com",
            "password": "password123",
            "full_name": "Unique Two",
            "role": "athlete"
        }
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "Email is already registered."


def test_signup_duplicate_username_rejected():
    # First signup
    client.post(
        "/auth/signup",
        json={
            "username": "duplicate_user",
            "email": "user1@example.com",
            "password": "password123",
            "full_name": "User One",
            "role": "athlete"
        }
    )

    # Second signup with same username, different email
    response = client.post(
        "/auth/signup",
        json={
            "username": "duplicate_user",
            "email": "user2@example.com",
            "password": "password123",
            "full_name": "User Two",
            "role": "athlete"
        }
    )
    assert response.status_code == 409
    assert response.json()["detail"] == "Username is already taken."


def test_signup_duplicate_username_rejected_case_insensitively():
    client.post(
        "/auth/signup",
        json={
            "username": "case_user",
            "email": "case1@example.com",
            "password": "password123",
            "full_name": "Case One",
            "role": "athlete",
        },
    )

    response = client.post(
        "/auth/signup",
        json={
            "username": "Case_User",
            "email": "case2@example.com",
            "password": "password123",
            "full_name": "Case Two",
            "role": "athlete",
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Username is already taken."


def test_expired_token_returns_unauthorized():
    from jose import jwt
    from datetime import datetime, timedelta, timezone
    from app.config import settings

    # Create an expired token (expired 10 minutes ago)
    expires_at = datetime.now(timezone.utc) - timedelta(minutes=10)
    user_id = "00000000-0000-0000-0000-000000000000" # dummy uuid
    expired_token = jwt.encode(
        {"sub": user_id, "exp": expires_at},
        settings.secret_key,
        algorithm=settings.algorithm,
    )

    headers = {"Authorization": f"Bearer {expired_token}"}
    response = client.get("/users/me", headers=headers)
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or missing token"


def test_signup_creates_unverified_user_and_sends_email():
    from unittest.mock import patch
    with patch("app.routers.auth.send_otp_email") as mock_send:
        username = "unverified_test_user"
        email = "unverified@example.com"

        response = client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": "password123",
                "full_name": "Unverified User",
                "role": "athlete"
            }
        )

        assert response.status_code == 201
        data = response.json()
        assert data["user"]["email_verified"] is False
        assert data["verification_required"] is True

        mock_send.assert_called_once()
        assert mock_send.call_args[0][0] == email
        assert mock_send.call_args.kwargs["purpose"] == "email_verification"
        otp = mock_send.call_args[0][1]
        assert len(otp) == 6

        db = TestingSessionLocal()
        try:
            user = db.scalar(select(User).where(User.username == username))
            otp_entry = db.scalar(select(EmailOTP).where(EmailOTP.user_id == user.id))
            assert otp_entry is not None
            from app.security import verify_password
            assert verify_password(otp, otp_entry.otp_hash)
            assert otp_entry.attempts == 0
        finally:
            db.close()


def test_signup_verification_disabled_creates_verified_user_without_signup_otp(mock_send_email):
    settings.require_signup_email_verification = False
    username = "verified_signup_user"
    email = "verified_signup@example.com"

    response = client.post(
        "/auth/signup",
        json={
            "username": username,
            "email": email,
            "password": "password123",
            "full_name": "Verified Signup User",
            "role": "athlete",
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["verification_required"] is False
    assert data["user"]["email_verified"] is True
    mock_send_email.assert_not_called()

    db = TestingSessionLocal()
    try:
        user = db.scalar(select(User).where(User.username == username))
        assert user is not None
        assert user.email_verified is True
        otp_entry = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "email_verification",
            )
        )
        assert otp_entry is None
    finally:
        db.close()

    login_response = client.post(
        "/auth/login",
        json={"identifier": email, "password": "password123"},
    )
    assert login_response.status_code == 200


def test_signup_creates_otp_even_if_email_send_fails(mock_send_email):
    mock_send_email.side_effect = HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Failed to send verification email. Please try again later.",
    )
    username = "send_failure_user"
    email = "send_failure@example.com"

    response = client.post(
        "/auth/signup",
        json={
            "username": username,
            "email": email,
            "password": "password123",
            "full_name": "Send Failure User",
            "role": "athlete",
        },
    )

    assert response.status_code == 201
    mock_send_email.assert_called_once()
    assert mock_send_email.call_args.kwargs["purpose"] == "email_verification"

    db = TestingSessionLocal()
    try:
        user = db.scalar(select(User).where(User.username == username))
        assert user is not None
        otp_entry = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "email_verification",
            )
        )
        assert otp_entry is not None
    finally:
        db.close()


def test_correct_otp_verifies_user():
    from unittest.mock import patch
    username = "verify_test_user"
    email = "verify@example.com"

    with patch("app.routers.auth.send_otp_email") as mock_send:
        client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": "password123",
                "full_name": "Verify User",
                "role": "athlete"
            }
        )
        otp = mock_send.call_args[0][1]

        response = client.post(
            "/auth/verify-otp",
            json={
                "email": email,
                "otp": otp
            }
        )
        assert response.status_code == 200
        assert response.json()["message"] == "Email verified successfully."

        db = TestingSessionLocal()
        try:
            user = db.scalar(select(User).where(User.username == username))
            assert user.email_verified is True
            otp_entry = db.scalar(select(EmailOTP).where(EmailOTP.user_id == user.id))
            assert otp_entry is None
        finally:
            db.close()


def test_wrong_otp_increment_attempts_and_fails():
    from unittest.mock import patch
    username = "wrong_otp_user"
    email = "wrong_otp@example.com"

    with patch("app.routers.auth.send_otp_email") as mock_send:
        client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": "password123",
                "full_name": "Wrong OTP User",
                "role": "athlete"
            }
        )

        response = client.post(
            "/auth/verify-otp",
            json={
                "email": email,
                "otp": "000000"
            }
        )
        assert response.status_code == 400
        assert response.json()["detail"] == "Invalid verification code."

        db = TestingSessionLocal()
        try:
            user = db.scalar(select(User).where(User.username == username))
            otp_entry = db.scalar(select(EmailOTP).where(EmailOTP.user_id == user.id))
            assert otp_entry.attempts == 1
        finally:
            db.close()


def test_too_many_attempts_blocks_verification():
    from unittest.mock import patch
    username = "blocked_user"
    email = "blocked@example.com"

    with patch("app.routers.auth.send_otp_email") as mock_send:
        client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": "password123",
                "full_name": "Blocked User",
                "role": "athlete"
            }
        )

        for _ in range(5):
            response = client.post(
                "/auth/verify-otp",
                json={
                    "email": email,
                    "otp": "000000"
                }
            )
            assert response.status_code == 400

        response = client.post(
            "/auth/verify-otp",
            json={
                "email": email,
                "otp": "000000"
            }
        )
        assert response.status_code == 400
        assert "Too many failed attempts" in response.json()["detail"]


def test_expired_otp_fails():
    from unittest.mock import patch
    from datetime import datetime, timedelta
    username = "expired_user"
    email = "expired@example.com"

    with patch("app.routers.auth.send_otp_email") as mock_send:
        client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": "password123",
                "full_name": "Expired User",
                "role": "athlete"
            }
        )
        otp = mock_send.call_args[0][1]

        db = TestingSessionLocal()
        try:
            user = db.scalar(select(User).where(User.username == username))
            otp_entry = db.scalar(select(EmailOTP).where(EmailOTP.user_id == user.id))
            otp_entry.expires_at = datetime.utcnow() - timedelta(minutes=1)
            db.commit()
        finally:
            db.close()

        response = client.post(
            "/auth/verify-otp",
            json={
                "email": email,
                "otp": otp
            }
        )
        assert response.status_code == 400
        assert "expired" in response.json()["detail"].lower()


def test_resend_otp_respects_cooldown():
    from unittest.mock import patch
    username = "cooldown_user"
    email = "cooldown@example.com"

    with patch("app.routers.auth.send_otp_email") as mock_send:
        client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": "password123",
                "full_name": "Cooldown User",
                "role": "athlete"
            }
        )
        assert mock_send.call_count == 1

        response = client.post(
            "/auth/resend-otp",
            json={
                "email": email
            }
        )
        assert response.status_code == 400
        assert "wait 60 seconds" in response.json()["detail"].lower()
        assert mock_send.call_count == 1

        from datetime import datetime, timedelta
        db = TestingSessionLocal()
        try:
            user = db.scalar(select(User).where(User.username == username))
            otp_entry = db.scalar(select(EmailOTP).where(EmailOTP.user_id == user.id))
            otp_entry.last_sent_at = datetime.utcnow() - timedelta(seconds=65)
            db.commit()
        finally:
            db.close()

        response = client.post(
            "/auth/resend-otp",
            json={
                "email": email
            }
        )
        assert response.status_code == 200
        assert response.json()["message"] == "Verification code resent."
        assert mock_send.call_count == 2


def test_unverified_user_cannot_login_verified_user_can():
    from unittest.mock import patch
    username = "login_test_user"
    email = "login_test@example.com"
    password = "password123"

    with patch("app.routers.auth.send_otp_email") as mock_send:
        client.post(
            "/auth/signup",
            json={
                "username": username,
                "email": email,
                "password": password,
                "full_name": "Login Test User",
                "role": "athlete"
            }
        )
        otp = mock_send.call_args[0][1]

        response = client.post(
            "/auth/login",
            json={
                "identifier": email,
                "password": password
            }
        )
        assert response.status_code == 403
        assert response.json()["detail"] == "Please verify your email before logging in."

        client.post(
            "/auth/verify-otp",
            json={
                "email": email,
                "otp": otp
            }
        )

        response = client.post(
            "/auth/login",
            json={
                "identifier": email,
                "password": password
            }
        )
        assert response.status_code == 200
        assert response.json()["user"]["email_verified"] is True


def test_forgot_password_returns_safe_message_for_unknown_email(mock_send_email):
    response = client.post(
        "/auth/forgot-password",
        json={"email": "missing@example.com"},
    )

    assert response.status_code == 200
    assert response.json()["message"] == "If an account exists, a reset code has been sent."
    mock_send_email.assert_not_called()


def test_forgot_password_sends_hashed_reset_otp_for_existing_email(mock_send_email):
    user, _ = create_test_user("reset_existing")

    response = client.post(
        "/auth/forgot-password",
        json={"email": user.email},
    )

    assert response.status_code == 200
    assert response.json()["message"] == "If an account exists, a reset code has been sent."
    mock_send_email.assert_called_once()
    assert mock_send_email.call_args.kwargs["purpose"] == "password_reset"
    otp = mock_send_email.call_args[0][1]

    db = TestingSessionLocal()
    try:
        otp_entry = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "password_reset",
            )
        )
        assert otp_entry is not None
        assert otp_entry.otp_hash != otp
        from app.security import verify_password
        assert verify_password(otp, otp_entry.otp_hash)
    finally:
        db.close()


def test_forgot_password_still_creates_reset_otp_when_signup_verification_disabled(mock_send_email):
    settings.require_signup_email_verification = False
    user, _ = create_test_user("reset_with_signup_verification_off")

    response = client.post(
        "/auth/forgot-password",
        json={"email": user.email},
    )

    assert response.status_code == 200
    mock_send_email.assert_called_once()
    assert mock_send_email.call_args.kwargs["purpose"] == "password_reset"
    otp = mock_send_email.call_args[0][1]

    db = TestingSessionLocal()
    try:
        reset_otp = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "password_reset",
            )
        )
        signup_otp = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "email_verification",
            )
        )
        assert reset_otp is not None
        assert reset_otp.otp_hash != otp
        assert reset_otp.expires_at is not None
        assert reset_otp.attempts == 0
        assert signup_otp is None
        from app.security import verify_password
        assert verify_password(otp, reset_otp.otp_hash)
    finally:
        db.close()


def test_wrong_reset_otp_fails(mock_send_email):
    user, _ = create_test_user("wrong_reset")
    client.post("/auth/forgot-password", json={"email": user.email})

    response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": "000000",
            "new_password": "newpass123",
            "confirm_password": "newpass123",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid or expired reset code."


def test_password_reset_still_requires_reset_otp_when_signup_verification_disabled(mock_send_email):
    settings.require_signup_email_verification = False
    user, _ = create_test_user("reset_requires_otp")

    response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": "123456",
            "new_password": "newpass123",
            "confirm_password": "newpass123",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid or expired reset code."
    mock_send_email.assert_not_called()


def test_expired_reset_otp_fails(mock_send_email):
    from datetime import datetime, timedelta
    user, _ = create_test_user("expired_reset")
    client.post("/auth/forgot-password", json={"email": user.email})
    otp = mock_send_email.call_args[0][1]

    db = TestingSessionLocal()
    try:
        otp_entry = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "password_reset",
            )
        )
        otp_entry.expires_at = datetime.utcnow() - timedelta(minutes=1)
        db.commit()
    finally:
        db.close()

    response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": otp,
            "new_password": "newpass123",
            "confirm_password": "newpass123",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid or expired reset code."


def test_too_many_reset_attempts_blocks_reset(mock_send_email):
    user, _ = create_test_user("blocked_reset")
    client.post("/auth/forgot-password", json={"email": user.email})
    otp = mock_send_email.call_args[0][1]

    for _ in range(5):
        response = client.post(
            "/auth/reset-password",
            json={
                "email": user.email,
                "otp": "000000",
                "new_password": "newpass123",
                "confirm_password": "newpass123",
            },
        )
        assert response.status_code == 400

    response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": otp,
            "new_password": "newpass123",
            "confirm_password": "newpass123",
        },
    )

    assert response.status_code == 400
    assert "Too many failed attempts" in response.json()["detail"]


def test_resend_reset_otp_respects_cooldown(mock_send_email):
    from datetime import datetime, timedelta
    user, _ = create_test_user("reset_cooldown")
    client.post("/auth/forgot-password", json={"email": user.email})
    assert mock_send_email.call_count == 1

    response = client.post(
        "/auth/resend-password-reset-otp",
        json={"email": user.email},
    )
    assert response.status_code == 400
    assert "wait 60 seconds" in response.json()["detail"].lower()
    assert mock_send_email.call_count == 1

    db = TestingSessionLocal()
    try:
        otp_entry = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "password_reset",
            )
        )
        otp_entry.last_sent_at = datetime.utcnow() - timedelta(seconds=65)
        db.commit()
    finally:
        db.close()

    response = client.post(
        "/auth/resend-password-reset-otp",
        json={"email": user.email},
    )
    assert response.status_code == 200
    assert response.json()["message"] == "If an account exists, a reset code has been sent."
    assert mock_send_email.call_count == 2
    assert mock_send_email.call_args.kwargs["purpose"] == "password_reset"


def test_reset_password_rejects_weak_or_mismatched_password(mock_send_email):
    user, _ = create_test_user("reset_validation")
    client.post("/auth/forgot-password", json={"email": user.email})
    otp = mock_send_email.call_args[0][1]

    weak_response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": otp,
            "new_password": "weakpass",
            "confirm_password": "weakpass",
        },
    )
    assert weak_response.status_code == 422

    mismatch_response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": otp,
            "new_password": "newpass123",
            "confirm_password": "otherpass123",
        },
    )
    assert mismatch_response.status_code == 422


def test_correct_reset_otp_resets_password_and_invalidates_old_password(mock_send_email):
    user, _ = create_test_user("reset_success")
    client.post("/auth/forgot-password", json={"email": user.email})
    otp = mock_send_email.call_args[0][1]

    response = client.post(
        "/auth/reset-password",
        json={
            "email": user.email,
            "otp": otp,
            "new_password": "newpass123",
            "confirm_password": "newpass123",
        },
    )
    assert response.status_code == 200
    assert response.json()["message"] == "Password reset successfully."

    old_login = client.post(
        "/auth/login",
        json={"identifier": user.email, "password": "password123"},
    )
    assert old_login.status_code == 401

    new_login = client.post(
        "/auth/login",
        json={"identifier": user.email, "password": "newpass123"},
    )
    assert new_login.status_code == 200

    db = TestingSessionLocal()
    try:
        otp_entry = db.scalar(
            select(EmailOTP).where(
                EmailOTP.user_id == user.id,
                EmailOTP.purpose == "password_reset",
            )
        )
        assert otp_entry is None
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


def test_create_drop_without_sport_or_category():
    athlete, token = create_test_user("athlete_a")
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "provider_asset_id": "asset_social",
        "public_id": "forma/skill_clips/drop_social",
        "playback_url": "https://res.cloudinary.com/nyuzzi3x/video/upload/v1/drop_social.mp4",
        "thumbnail_url": "https://res.cloudinary.com/nyuzzi3x/video/upload/v1/drop_social.jpg",
        "duration_seconds": 12.0,
        "width": 1080,
        "height": 1920,
        "format": "mp4",
        "bytes": 1024 * 500,
        "caption": "Social first drop!",
        "audience": "followers",
        "location": "New York"
    }

    # Successful creation without sport or category
    response = client.post("/drops", json=payload, headers=headers)
    assert response.status_code == 201
    drop_data = response.json()
    assert drop_data["sport_id"] is None
    assert drop_data["category_id"] is None
    assert drop_data["audience"] == "followers"
    assert drop_data["location"] == "New York"

    # Default audience check (null/missing defaults to public)
    db = TestingSessionLocal()
    from app.models import Drop
    null_aud_drop = Drop(
        user_id=athlete.id,
        provider_asset_id="asset_null_aud",
        public_id="drop_null_aud",
        playback_url="url",
        duration_seconds=10,
        format="mp4",
        bytes=1000,
        visibility="public",
        audience=None
    )
    db.add(null_aud_drop)
    db.commit()
    db.refresh(null_aud_drop)
    null_aud_drop_id = str(null_aud_drop.id)
    db.close()

    response2 = client.get(f"/drops/{null_aud_drop_id}", headers=headers)
    assert response2.status_code == 200
    assert response2.json()["audience"] == "public"


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


def test_auth_hardening_and_rate_limiting():
    from datetime import timedelta
    from app.models import LoginAttempt
    # 1. Setup verified user
    db = TestingSessionLocal()
    user = User(
        username="hardened_user",
        email="hardened@example.com",
        password_hash=hash_password("password123"),
        full_name="Hardened User",
        role="athlete",
        email_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    db.close()

    # Login with email address works
    resp1 = client.post("/auth/login", json={"identifier": "hardened@example.com", "password": "password123"})
    assert resp1.status_code == 200
    assert resp1.json()["user"]["username"] == "hardened_user"

    # Login with username works
    resp2 = client.post("/auth/login", json={"identifier": "hardened_user", "password": "password123"})
    assert resp2.status_code == 200

    # Login with uppercase username input works
    resp3 = client.post("/auth/login", json={"identifier": "HARDENED_USER", "password": "password123"})
    assert resp3.status_code == 200

    # Wrong password with username fails with generic error
    resp4 = client.post("/auth/login", json={"identifier": "hardened_user", "password": "wrong_password"})
    assert resp4.status_code == 401
    assert "invalid email/username or password" in resp4.json()["detail"].lower()

    # Unknown username fails with generic error
    resp5 = client.post("/auth/login", json={"identifier": "unknown_user_name", "password": "password123"})
    assert resp5.status_code == 401
    assert "invalid email/username or password" in resp5.json()["detail"].lower()

    # Unverified user using username is blocked
    db = TestingSessionLocal()
    unverified_user = User(
        username="unverified_user",
        email="unverified@example.com",
        password_hash=hash_password("password123"),
        full_name="Unverified User",
        role="athlete",
        email_verified=False,
    )
    db.add(unverified_user)
    db.commit()
    db.refresh(unverified_user)
    db.close()

    resp6 = client.post("/auth/login", json={"identifier": "unverified_user", "password": "password123"})
    assert resp6.status_code == 403
    assert resp6.json()["detail"] == "Please verify your email before logging in."

    # Rate limiting: 5 failed attempts allowed, 6th is blocked
    # Attempt 1 (already done in resp4)
    # Attempt 2
    client.post("/auth/login", json={"identifier": "hardened_user", "password": "wrong_password"})
    # Attempt 3
    client.post("/auth/login", json={"identifier": "hardened_user", "password": "wrong_password"})
    # Attempt 4
    client.post("/auth/login", json={"identifier": "hardened_user", "password": "wrong_password"})
    # Attempt 5
    client.post("/auth/login", json={"identifier": "hardened_user", "password": "wrong_password"})

    # Check 6th is blocked
    resp_blocked = client.post("/auth/login", json={"identifier": "hardened_user", "password": "wrong_password"})
    assert resp_blocked.status_code == 429
    assert "too many login attempts" in resp_blocked.json()["detail"].lower()

    # Correct password after block is still blocked
    resp_correct_blocked = client.post("/auth/login", json={"identifier": "hardened_user", "password": "password123"})
    assert resp_correct_blocked.status_code == 429

    # Successful login clears attempts (simulate time pass by updating last_attempt_at)
    db = TestingSessionLocal()
    attempt = db.scalar(select(LoginAttempt).where(LoginAttempt.identifier == "hardened_user"))
    attempt.last_attempt_at = attempt.last_attempt_at - timedelta(minutes=16)
    db.commit()
    db.close()

    # Now login with correct password should succeed and clear the attempt entry
    resp_after_cooldown = client.post("/auth/login", json={"identifier": "hardened_user", "password": "password123"})
    assert resp_after_cooldown.status_code == 200

    # Verify database attempts entry is cleared
    db = TestingSessionLocal()
    attempt_cleared = db.scalar(select(LoginAttempt).where(LoginAttempt.identifier == "hardened_user"))
    assert attempt_cleared is None
    db.close()


def test_account_deletion_flow():
    # 1. Create a user
    user, token = create_test_user("delete_test_user")

    # 2. Unauthenticated delete returns 401
    resp_unauth = client.request("DELETE", "/auth/me", json={"password": "password123"})
    assert resp_unauth.status_code == 401

    headers = {"Authorization": f"Bearer {token}"}

    # 2.5. Authenticated delete with wrong password returns 400
    resp_wrong_pw = client.request("DELETE", "/auth/me", headers=headers, json={"password": "wrong_password"})
    assert resp_wrong_pw.status_code == 400
    assert "incorrect password" in resp_wrong_pw.json()["detail"].lower()

    # 3. Authenticated delete with correct password succeeds
    resp_delete = client.request("DELETE", "/auth/me", headers=headers, json={"password": "password123"})
    assert resp_delete.status_code == 200
    assert "deleted successfully" in resp_delete.json()["message"].lower()

    # 4. Check DB state: username and email must NOT be anonymized
    db = TestingSessionLocal()
    try:
        updated_user = db.get(User, user.id)
        assert updated_user.is_active is False
        assert updated_user.deleted_at is not None
        assert updated_user.email == user.email
        assert updated_user.username == user.username
    finally:
        db.close()

    # 5. Deleted user cannot login
    resp_login = client.post(
        "/auth/login",
        json={"identifier": "delete_test_user", "password": "password123"}
    )
    assert resp_login.status_code == 401
    assert "invalid email/username or password" in resp_login.json()["detail"].lower()

    # 6. Authenticated requests from deleted user fail with 401
    resp_profile = client.get("/users/me", headers=headers)
    assert resp_profile.status_code == 401


def test_cleanup_expired_unverified_users_during_signup(mock_send_email):
    from datetime import datetime, timedelta
    # 1. Create one expired unverified user (created 25 hours ago)
    # 2. Create one active unverified user (created 1 hour ago)
    # 3. Create one expired verified user (created 25 hours ago)
    db = TestingSessionLocal()
    try:
        now = datetime.utcnow()
        
        expired_unverified = User(
            username="expired_unverified",
            email="exp_unverified@example.com",
            password_hash=hash_password("password123"),
            full_name="Expired Unverified",
            role="athlete",
            email_verified=False,
            created_at=now - timedelta(hours=25),
        )
        
        active_unverified = User(
            username="active_unverified",
            email="act_unverified@example.com",
            password_hash=hash_password("password123"),
            full_name="Active Unverified",
            role="athlete",
            email_verified=False,
            created_at=now - timedelta(hours=1),
        )
        
        expired_verified = User(
            username="expired_verified",
            email="exp_verified@example.com",
            password_hash=hash_password("password123"),
            full_name="Expired Verified",
            role="athlete",
            email_verified=True,
            created_at=now - timedelta(hours=25),
        )
        
        db.add_all([expired_unverified, active_unverified, expired_verified])
        db.commit()
    finally:
        db.close()

    # 4. Trigger signup with the expired unverified username.
    # It should succeed because signup cleans up expired unverified users first,
    # freeing up the username "expired_unverified" and email "exp_unverified@example.com".
    response = client.post(
        "/auth/signup",
        json={
            "username": "expired_unverified",
            "email": "exp_unverified@example.com",
            "password": "newpassword123",
            "full_name": "New Signup",
            "role": "athlete"
        }
    )
    assert response.status_code == 201

    # 5. Verify the DB state
    db = TestingSessionLocal()
    try:
        # Expired unverified user should have been deleted (and replaced by the new one)
        new_user = db.scalar(select(User).where(User.username == "expired_unverified"))
        assert new_user is not None
        assert new_user.email == "exp_unverified@example.com"
        assert new_user.email_verified is False
        
        # Active unverified user should NOT have been deleted
        act_user = db.scalar(select(User).where(User.username == "active_unverified"))
        assert act_user is not None
        
        # Expired verified user should NOT have been deleted
        exp_ver_user = db.scalar(select(User).where(User.username == "expired_verified"))
        assert exp_ver_user is not None
    finally:
        db.close()



