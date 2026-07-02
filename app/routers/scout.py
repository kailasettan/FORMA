from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import ScoutShortlist, User
from app.schemas import ScoutShortlistCreateIn, ScoutShortlistOut

router = APIRouter(prefix="/scout/shortlist", tags=["scout shortlists"])


def verify_scout_role(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "scout":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to shortlist athletes.",
        )
    return current_user


@router.post("/{athlete_user_id}", response_model=ScoutShortlistOut, status_code=status.HTTP_201_CREATED)
def shortlist_athlete(
    athlete_user_id: UUID,
    payload: ScoutShortlistCreateIn | None = None,
    current_user: User = Depends(verify_scout_role),
    db: Session = Depends(get_db),
) -> ScoutShortlist:
    # Check if athlete exists
    athlete = db.get(User, athlete_user_id)
    if not athlete:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Athlete not found")
        
    # Cannot shortlist oneself
    if athlete_user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot shortlist yourself.",
        )

    private_note = payload.private_note if payload else None
    drop_id = payload.drop_id if payload else None

    shortlist = ScoutShortlist(
        scout_user_id=current_user.id,
        athlete_user_id=athlete_user_id,
        drop_id=drop_id,
        private_note=private_note,
    )
    db.add(shortlist)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Athlete is already shortlisted.",
        ) from None
        
    db.refresh(shortlist)
    # Populate athlete details for response
    shortlist.athlete = athlete
    return shortlist


@router.delete("/{athlete_user_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_from_shortlist(
    athlete_user_id: UUID,
    current_user: User = Depends(verify_scout_role),
    db: Session = Depends(get_db),
) -> None:
    shortlist = db.scalar(
        select(ScoutShortlist).where(
            (ScoutShortlist.scout_user_id == current_user.id)
            & (ScoutShortlist.athlete_user_id == athlete_user_id)
        )
    )
    if not shortlist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Athlete not found on your shortlist.",
        )

    db.delete(shortlist)
    db.commit()


@router.get("", response_model=list[ScoutShortlistOut])
def get_shortlist(
    current_user: User = Depends(verify_scout_role),
    db: Session = Depends(get_db),
) -> list[ScoutShortlist]:
    entries = list(db.scalars(
        select(ScoutShortlist)
        .where(ScoutShortlist.scout_user_id == current_user.id)
        .order_by(ScoutShortlist.created_at.desc())
    ))
    # Fetch athlete information for each entry
    for entry in entries:
        entry.athlete = db.get(User, entry.athlete_user_id)
    return entries
