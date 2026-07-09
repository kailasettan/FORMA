from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Drop, DropComment, DropProp, PlayerProfile, ScoutShortlist, SportCatalog, SportCategory, User
from app.routers.drops import hydrate_drop
from app.schemas import (
    DropOut,
    PlayerProfileOut,
    PrivateUserOut,
    PublicAthleteProfileOut,
    UserOut,
    UserUpdateIn,
)

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=PrivateUserOut)
def get_me(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.patch("/me", response_model=PrivateUserOut)
def update_me(
    payload: UserUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    # If focused_sport_id is set, verify that it's active
    update_data = payload.model_dump(exclude_unset=True)
    if "focused_sport_id" in update_data and update_data["focused_sport_id"] is not None:
        sport = db.get(SportCatalog, update_data["focused_sport_id"])
        if not sport or not sport.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected sport is not available",
            )

    for field, value in update_data.items():
        setattr(current_user, field, value)
        
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username is already taken",
        ) from None
        
    db.refresh(current_user)
    return current_user


@router.get("/search", response_model=list[UserOut])
def search_users(
    q: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[User]:
    query_str = q.strip()
    if len(query_str) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query must be at least 2 characters",
        )
    if len(query_str) > 50:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query is too long",
        )

    # Prefix search, rank exact matches first (case-insensitive)
    stmt = (
        select(User)
        .where(
            User.username.ilike(f"{query_str}%"),
            User.is_active == True
        )
        .order_by(
            # desc() puts True first. Boolean comparison will be True for exact match.
            desc(func.lower(User.username) == query_str.lower()),
            User.username
        )
        .limit(20)
    )
    return list(db.scalars(stmt))
 
 
@router.get("/{user_id}", response_model=UserOut)
def get_public_user(user_id: UUID, db: Session = Depends(get_db)) -> User:
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
 
 
@router.get("/{user_id}/player-profiles", response_model=list[PlayerProfileOut])
def list_player_profiles(user_id: UUID, db: Session = Depends(get_db)) -> list[PlayerProfile]:
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    profiles = list(db.scalars(select(PlayerProfile).where(PlayerProfile.user_id == user_id)))
    for p in profiles:
        p.sport = db.get(SportCatalog, p.sport_id)
    return profiles
 
 
@router.get("/{user_id}/drops", response_model=list[DropOut])
def list_user_drops(
    user_id: UUID,
    limit: int = 30,
    cursor: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Drop]:
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")


    page_size = max(1, min(limit, 50))
    query = select(Drop).where(
        Drop.user_id == user_id,
        Drop.moderation_status == "approved",
    )
    if current_user.id != user_id:
        query = query.where(Drop.visibility == "public")
    else:
        query = query.where(Drop.visibility.in_(["public", "private"]))
    if cursor:
        try:
            from datetime import datetime

            cursor_dt = datetime.fromisoformat(cursor.replace("Z", "+00:00"))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid cursor",
            ) from None
        query = query.where(Drop.created_at < cursor_dt)

    drops = list(db.scalars(query.order_by(Drop.created_at.desc()).limit(page_size)))
    for drop in drops:
        hydrate_drop(drop, db, current_user)
    return drops


@router.get("/{user_id}/public-profile", response_model=PublicAthleteProfileOut)
def get_public_profile(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # 1. Fetch player profiles
    profiles = list(db.scalars(
        select(PlayerProfile).where(PlayerProfile.user_id == user.id)
    ))
    for p in profiles:
        p.sport = db.get(SportCatalog, p.sport_id)

    # 2. Fetch drops. Public profile readers only see approved public Drops.
    query = select(Drop).where(
        Drop.user_id == user.id,
        Drop.moderation_status == "approved",
    )
    if current_user.id != user.id:
        query = query.where(Drop.visibility == "public")
    else:
        query = query.where(Drop.visibility.in_(["public", "private"]))
    query = query.order_by(Drop.created_at.desc())
    drops = list(db.scalars(query))

    # Populate drops metrics and relations
    for drop in drops:
        hydrate_drop(drop, db, current_user)

    # 3. Check if shortlisted (only visible if requester is a scout)
    is_shortlisted = False
    if current_user.role == "scout":
        is_shortlisted = (
            db.scalar(
                select(ScoutShortlist).where(
                    (ScoutShortlist.scout_user_id == current_user.id)
                    & (ScoutShortlist.athlete_user_id == user.id)
                )
            )
            is not None
        )

    # 4. Calculate profile completion
    completion = 0
    if user.profile_photo_url:
        completion += 15
    if user.headline:
        completion += 15
    if user.bio:
        completion += 15
    if user.location:
        completion += 15
    if user.availability:
        completion += 15
    if len(profiles) > 0:
        completion += 15
    if len(drops) > 0:
        completion += 10

    return {
        "user": user,
        "player_profiles": profiles,
        "drops": drops,
        "is_shortlisted": is_shortlisted,
        "profile_completion_percentage": completion,
    }


@router.get("/by-username/{username}/public-profile", response_model=PublicAthleteProfileOut)
def get_public_profile_by_username(
    username: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    user = db.scalar(select(User).where(func.lower(User.username) == username.lower()))
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        
    return get_public_profile(user.id, current_user, db)
