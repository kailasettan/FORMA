from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import SportCatalog, SportCategory
from app.schemas import SportCatalogOut, SportCategoryOut

router = APIRouter(prefix="/sports", tags=["sports catalog"])


@router.get("", response_model=list[SportCatalogOut])
def list_sports(db: Session = Depends(get_db)) -> list[SportCatalog]:
    return list(db.scalars(
        select(SportCatalog).where(SportCatalog.is_active == True).order_by(SportCatalog.name)
    ))


@router.get("/{sport_id}/categories", response_model=list[SportCategoryOut])
def list_sport_categories(sport_id: UUID, db: Session = Depends(get_db)) -> list[SportCategory]:
    # Check if sport exists
    sport = db.get(SportCatalog, sport_id)
    if sport is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sport not found")
        
    return list(db.scalars(
        select(SportCategory)
        .where((SportCategory.sport_id == sport_id) & (SportCategory.is_active == True))
        .order_by(SportCategory.display_order)
    ))
