from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import PlayerProfile, User
from app.schemas import PlayerProfileCreateIn, PlayerProfileOut, PlayerProfileUpdateIn

router = APIRouter(prefix="/player-profiles", tags=["player profiles"])


@router.post("", response_model=PlayerProfileOut, status_code=status.HTTP_201_CREATED)
def create_player_profile(
    payload: PlayerProfileCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlayerProfile:
    profile = PlayerProfile(
        user_id=current_user.id,
        sport=payload.sport,
        position=payload.position,
        skill_level=payload.skill_level,
    )
    db.add(profile)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Player profile already exists for this sport",
        ) from None
    db.refresh(profile)
    return profile


@router.patch("/{profile_id}", response_model=PlayerProfileOut)
def update_player_profile(
    profile_id: UUID,
    payload: PlayerProfileUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlayerProfile:
    profile = db.scalar(select(PlayerProfile).where(PlayerProfile.id == profile_id))
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    if profile.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only edit your own profile",
        )

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)
    db.commit()
    db.refresh(profile)
    return profile
