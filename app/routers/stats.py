from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import MatchStat, Sport, User
from app.schemas import MatchStatCreateIn, MatchStatOut

router = APIRouter(tags=["match stats"])

SPORT_STAT_FIELDS: dict[Sport, set[str]] = {
    Sport.football: {"goals", "assists"},
    Sport.cricket: {"runs", "wickets", "catches"},
    Sport.basketball: {"points", "rebounds", "assists"},
}


def validate_stat_keys(sport: Sport | None, stats: dict[str, int] | None) -> None:
    if sport is None or stats is None:
        return
    unknown_keys = set(stats) - SPORT_STAT_FIELDS[sport]
    if unknown_keys:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown stat keys for {sport.value}: {', '.join(sorted(unknown_keys))}",
        )


@router.post("/match-stats", response_model=MatchStatOut, status_code=status.HTTP_201_CREATED)
def create_match_stat(
    payload: MatchStatCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MatchStat:
    validate_stat_keys(payload.sport, payload.stats)
    stat = MatchStat(
        user_id=current_user.id,
        sport=payload.sport,
        date=payload.date,
        opponent=payload.opponent,
        stats=payload.stats,
    )
    db.add(stat)
    db.commit()
    db.refresh(stat)
    return stat


@router.get("/users/{user_id}/match-stats", response_model=list[MatchStatOut])
def list_match_stats(user_id: UUID, db: Session = Depends(get_db)) -> list[MatchStat]:
    return list(
        db.scalars(
            select(MatchStat).where(MatchStat.user_id == user_id).order_by(desc(MatchStat.date))
        )
    )


@router.delete("/match-stats/{stat_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_match_stat(
    stat_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    stat = db.get(MatchStat, stat_id)
    if stat is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Match stat not found")
    if stat.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only delete your own stats")

    db.delete(stat)
    db.commit()


@router.get("/users/{user_id}/match-stats/aggregate")
def aggregate_match_stats(
    user_id: UUID,
    sport: Sport = Query(...),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    stats = db.scalars(
        select(MatchStat).where(MatchStat.user_id == user_id, MatchStat.sport == sport)
    )
    totals = {"matches_played": 0, **dict.fromkeys(SPORT_STAT_FIELDS[sport], 0)}
    for stat in stats:
        totals["matches_played"] += 1
        for key, value in stat.stats.items():
            totals[key] = totals.get(key, 0) + value
    return totals
