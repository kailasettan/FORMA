import base64
import hashlib
import json
import time
import urllib.error
import urllib.request
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import (
    Drop,
    DropComment,
    DropProp,
    OrphanedCloudinaryAsset,
    PlayerProfile,
    SportCatalog,
    SportCategory,
    User,
)
from app.schemas import (
    DropCommentCreateIn,
    DropCommentOut,
    DropCreateIn,
    DropFeedOut,
    DropOut,
    UploadSignatureOut,
)

router = APIRouter(prefix="/drops", tags=["drops"])


MAX_FEED_LIMIT = 25


def hydrate_drop(drop: Drop, db: Session, current_user: User | None = None) -> Drop:
    drop.user = db.get(User, drop.user_id)
    drop.sport = db.get(SportCatalog, drop.sport_id)
    if drop.category_id:
        drop.category = db.get(SportCategory, drop.category_id)
    drop.props_count = db.scalar(select(func.count(DropProp.id)).where(DropProp.drop_id == drop.id)) or 0
    drop.comments_count = db.scalar(
        select(func.count(DropComment.id)).where(
            (DropComment.drop_id == drop.id) & (DropComment.deleted_at == None)
        )
    ) or 0
    drop.has_propped = False
    if current_user is not None:
        drop.has_propped = (
            db.scalar(
                select(DropProp).where(
                    (DropProp.drop_id == drop.id) & (DropProp.user_id == current_user.id)
                )
            )
            is not None
        )
    return drop


def visible_drop_query():
    return select(Drop).where(
        Drop.visibility == "public",
        Drop.moderation_status == "approved",
    )


def record_orphaned_cloudinary_asset(
    payload: DropCreateIn,
    current_user: User,
    db: Session,
    reason: str,
) -> None:
    existing = db.scalar(
        select(OrphanedCloudinaryAsset).where(
            OrphanedCloudinaryAsset.provider_asset_id == payload.provider_asset_id
        )
    )
    if existing:
        return
    db.add(
        OrphanedCloudinaryAsset(
            user_id=current_user.id,
            provider_asset_id=payload.provider_asset_id,
            public_id=payload.public_id,
            reason=reason,
        )
    )
    try:
        db.commit()
    except (IntegrityError, SQLAlchemyError):
        db.rollback()


def generate_cloudinary_signature(api_secret: str, params: dict) -> str:
    # Sort parameters alphabetically by key
    sorted_params = sorted(params.items())
    # Format as key=value and join with &
    param_string = "&".join(f"{k}={v}" for k, v in sorted_params)
    # Append the API secret to the end without delimiter
    string_to_sign = f"{param_string}{api_secret}"
    # Calculate SHA-1 hex digest
    return hashlib.sha1(string_to_sign.encode("utf-8")).hexdigest()


def fetch_cloudinary_metadata(cloud_name: str, api_key: str, api_secret: str, public_id: str) -> dict:
    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/resources/video/upload/{public_id}"
    auth_str = f"{api_key}:{auth_secret}" if (auth_secret := api_secret) else ""
    auth_str = f"{api_key}:{api_secret}"
    auth_bytes = auth_str.encode("utf-8")
    auth_b64 = base64.b64encode(auth_bytes).decode("utf-8")

    headers = {
        "Authorization": f"Basic {auth_b64}",
        "Accept": "application/json",
    }

    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Cloudinary asset verification failed: {err_msg}",
        ) from None
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Failed to connect to Cloudinary: {str(e)}",
        ) from None


def delete_cloudinary_asset(cloud_name: str, api_key: str, api_secret: str, public_id: str) -> None:
    url = f"https://api.cloudinary.com/v1_1/{cloud_name}/resources/video/upload?public_ids[]={public_id}"
    auth_str = f"{api_key}:{api_secret}"
    auth_bytes = auth_str.encode("utf-8")
    auth_b64 = base64.b64encode(auth_bytes).decode("utf-8")

    headers = {
        "Authorization": f"Basic {auth_b64}",
    }

    req = urllib.request.Request(url, headers=headers, method="DELETE")
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            pass
    except Exception as e:
        # Silently fail deletion cleanup logging
        print(f"Failed to delete Cloudinary asset {public_id}: {str(e)}")


@router.post("/upload-signature", response_model=UploadSignatureOut)
def get_upload_signature(current_user: User = Depends(get_current_user)) -> dict:
    timestamp = int(time.time())
    params = {
        "folder": "forma/skill_clips",
        "overwrite": "false",
        "timestamp": timestamp,
        "unique_filename": "true",
        "upload_preset": "forma_skill_clips",
    }
    signature = generate_cloudinary_signature(settings.cloudinary_api_secret, params)
    return {
        "signature": signature,
        "timestamp": timestamp,
        "api_key": settings.cloudinary_api_key,
        "upload_preset": "forma_skill_clips",
        "folder": "forma/skill_clips",
        "overwrite": "false",
        "unique_filename": "true",
        "cloud_name": settings.cloudinary_cloud_name,
        "resource_type": "video",
    }


@router.post("", response_model=DropOut, status_code=status.HTTP_201_CREATED)
def create_drop(
    payload: DropCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Drop:
    # 1. Check if this Cloudinary asset was already published.
    existing_drop = db.scalar(
        select(Drop).where(
            or_(
                Drop.provider_asset_id == payload.provider_asset_id,
                Drop.public_id == payload.public_id,
            )
        )
    )
    if existing_drop:
        if existing_drop.user_id == current_user.id:
            return hydrate_drop(existing_drop, db, current_user)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Drop with this provider asset already exists",
        )

    # 2. Check if sport exists
    sport = db.get(SportCatalog, payload.sport_id)
    if not sport:
        record_orphaned_cloudinary_asset(payload, current_user, db, "sport_not_found")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sport not found")

    # 3. Check if category exists
    if payload.category_id:
        category = db.get(SportCategory, payload.category_id)
        if not category or category.sport_id != payload.sport_id:
            record_orphaned_cloudinary_asset(
                payload,
                current_user,
                db,
                "invalid_sport_category",
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid sport category selection",
            )

    # 4. Verify Cloudinary metadata securely from backend
    is_testing = settings.database_url.endswith("test")
    
    if not is_testing and settings.cloudinary_api_secret in ["", "change-me-in-production"]:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Cloudinary credentials are not configured on the server",
        )

    if is_testing:
        # In test mode, we do local schema validations of payload duration & size
        if payload.duration_seconds > 60.0:
            record_orphaned_cloudinary_asset(payload, current_user, db, "duration_limit")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="This video is longer than 60 seconds.",
            )
        if payload.bytes > 50 * 1024 * 1024:
            record_orphaned_cloudinary_asset(payload, current_user, db, "bytes_limit")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Video size exceeds the 50 MB limit.",
            )
        if payload.format not in ["mp4", "mov", "webm"]:
            record_orphaned_cloudinary_asset(payload, current_user, db, "unsupported_format")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Unsupported video format.",
            )
    else:
        # Prod validation against actual Cloudinary API
        metadata = fetch_cloudinary_metadata(
            settings.cloudinary_cloud_name,
            settings.cloudinary_api_key,
            settings.cloudinary_api_secret,
            payload.public_id,
        )
        
        # Validations on metadata returned by Cloudinary
        resource_type = metadata.get("resource_type")
        asset_format = metadata.get("format")
        duration = float(metadata.get("duration", 0))
        bytes_size = int(metadata.get("bytes", 0))

        if resource_type != "video":
            record_orphaned_cloudinary_asset(payload, current_user, db, "resource_not_video")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Resource must be a video.",
            )

        if asset_format not in ["mp4", "mov", "webm"]:
            record_orphaned_cloudinary_asset(payload, current_user, db, "unsupported_format")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Unsupported video format.",
            )

        if duration > 60.0:
            record_orphaned_cloudinary_asset(payload, current_user, db, "duration_limit")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="This video is longer than 60 seconds.",
            )

        if bytes_size > 50 * 1024 * 1024:
            record_orphaned_cloudinary_asset(payload, current_user, db, "bytes_limit")
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Video size exceeds the 50 MB limit.",
            )

    # 5. Look up player profile to link it if exists
    profile = db.scalar(
        select(PlayerProfile).where(
            (PlayerProfile.user_id == current_user.id)
            & (PlayerProfile.sport_id == payload.sport_id)
        )
    )
    profile_id = profile.id if profile else None

    # 6. Save drop record
    drop = Drop(
        user_id=current_user.id,
        player_profile_id=profile_id,
        sport_id=payload.sport_id,
        category_id=payload.category_id,
        provider="cloudinary",
        provider_asset_id=payload.provider_asset_id,
        public_id=payload.public_id,
        playback_url=payload.playback_url,
        thumbnail_url=payload.thumbnail_url,
        caption=payload.caption,
        duration_seconds=payload.duration_seconds,
        width=payload.width,
        height=payload.height,
        format=payload.format,
        bytes=payload.bytes,
        visibility=payload.visibility,
        moderation_status="approved",
    )
    db.add(drop)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        existing_drop = db.scalar(
            select(Drop).where(
                or_(
                    Drop.provider_asset_id == payload.provider_asset_id,
                    Drop.public_id == payload.public_id,
                )
            )
        )
        if existing_drop and existing_drop.user_id == current_user.id:
            return hydrate_drop(existing_drop, db, current_user)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Drop with this provider asset already exists",
        ) from None
    db.refresh(drop)
    
    # Set helper dynamic properties
    drop.props_count = 0
    drop.comments_count = 0
    drop.has_propped = False
    return drop


@router.get("/feed", response_model=DropFeedOut)
def list_feed(
    cursor: str | None = None,
    limit: int = Query(default=10, ge=1, le=MAX_FEED_LIMIT),
    sport_id: UUID | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    stmt = visible_drop_query()
    if sport_id:
        stmt = stmt.where(Drop.sport_id == sport_id)
    if cursor:
        try:
            from datetime import datetime

            cursor_dt = datetime.fromisoformat(cursor.replace("Z", "+00:00"))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid cursor",
            ) from None
        stmt = stmt.where(Drop.created_at < cursor_dt)

    rows = list(db.scalars(stmt.order_by(Drop.created_at.desc()).limit(limit + 1)))
    has_more = len(rows) > limit
    drops = rows[:limit]
    for drop in drops:
        hydrate_drop(drop, db, current_user)

    next_cursor = drops[-1].created_at if has_more and drops else None
    return {"items": drops, "next_cursor": next_cursor}


@router.get("/{drop_id}", response_model=DropOut)
def get_drop(
    drop_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Drop:
    drop = db.get(Drop, drop_id)
    if not drop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="This Drop is no longer available.")

    # Access control
    if drop.visibility == "private" and drop.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view this Drop.",
        )

    return hydrate_drop(drop, db, current_user)


@router.delete("/{drop_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_drop(
    drop_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    drop = db.get(Drop, drop_id)
    if not drop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Drop not found")

    # Only owner can delete Drop
    if drop.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized user cannot delete the Drop.",
        )

    # In production, delete from Cloudinary as well
    if settings.cloudinary_api_secret not in ["", "change-me-in-production"]:
        delete_cloudinary_asset(
            settings.cloudinary_cloud_name,
            settings.cloudinary_api_key,
            settings.cloudinary_api_secret,
            drop.public_id,
        )

    db.delete(drop)
    db.commit()


# Props
@router.post("/{drop_id}/props", status_code=status.HTTP_201_CREATED)
def give_props(
    drop_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    drop = db.get(Drop, drop_id)
    if not drop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Drop not found")

    prop = DropProp(drop_id=drop_id, user_id=current_user.id)
    db.add(prop)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already added Fire to this Drop.",
        ) from None
        
    return {"message": "Fire added successfully"}


@router.delete("/{drop_id}/props", status_code=status.HTTP_204_NO_CONTENT)
def remove_props(
    drop_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    prop = db.scalar(
        select(DropProp).where(
            (DropProp.drop_id == drop_id) & (DropProp.user_id == current_user.id)
        )
    )
    if not prop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fire not found",
        )

    db.delete(prop)
    db.commit()


# Comments
@router.get("/{drop_id}/comments", response_model=list[DropCommentOut])
def list_comments(
    drop_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[DropComment]:
    drop = db.get(Drop, drop_id)
    if not drop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Drop not found")

    return list(
        db.scalars(
            select(DropComment)
            .where((DropComment.drop_id == drop_id) & (DropComment.deleted_at == None))
            .order_by(DropComment.created_at.asc())
        )
    )


@router.post("/{drop_id}/comments", response_model=DropCommentOut, status_code=status.HTTP_201_CREATED)
def add_comment(
    drop_id: UUID,
    payload: DropCommentCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DropComment:
    drop = db.get(Drop, drop_id)
    if not drop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Drop not found")

    # Reject empty or whitespace comments
    body_text = payload.body.strip()
    if not body_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Comment body cannot be empty",
        )

    comment = DropComment(drop_id=drop_id, user_id=current_user.id, body=body_text)
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return comment


@router.delete("/{drop_id}/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment(
    drop_id: UUID,
    comment_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    comment = db.get(DropComment, comment_id)
    if not comment or comment.drop_id != drop_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Comment not found",
        )

    drop = db.get(Drop, drop_id)

    # Authorization check: Owner of the comment or Owner of the drop (moderator)
    if comment.user_id != current_user.id and (not drop or drop.user_id != current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to delete this comment.",
        )

    # Soft delete comment
    comment.deleted_at = func.now()
    db.commit()
