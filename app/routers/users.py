from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import PlayerProfile, User
from app.schemas import PlayerProfileOut, PrivateUserOut, UserOut, UserUpdateIn

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
    for field, value in payload.model_dump(exclude_unset=True).items():
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


@router.get("/{user_id}", response_model=UserOut)
def get_public_user(user_id: UUID, db: Session = Depends(get_db)) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.get("/{user_id}/player-profiles", response_model=list[PlayerProfileOut])
def list_player_profiles(user_id: UUID, db: Session = Depends(get_db)) -> list[PlayerProfile]:
    return list(db.scalars(select(PlayerProfile).where(PlayerProfile.user_id == user_id)))
