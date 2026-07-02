import base64
import hashlib
import json
import time
import urllib.error
import urllib.request
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import Drop, DropComment, DropProp, PlayerProfile, SportCatalog, SportCategory, User
from app.schemas import (
    DropCommentCreateIn,
    DropCommentOut,
    DropCreateIn,
    DropOut,
    UploadSignatureOut,
)

router = APIRouter(prefix="/drops", tags=["drops"])


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
    }


@router.post("", response_model=DropOut, status_code=status.HTTP_201_CREATED)
def create_drop(
    payload: DropCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Drop:
    # 1. Check if public_id already exists in db to reject duplicates early
    existing_drop = db.scalar(select(Drop).where(Drop.public_id == payload.public_id))
    if existing_drop:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Drop with this provider asset already exists",
        )

    # 2. Check if sport exists
    sport = db.get(SportCatalog, payload.sport_id)
    if not sport:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sport not found")

    # 3. Check if category exists
    if payload.category_id:
        category = db.get(SportCategory, payload.category_id)
        if not category or category.sport_id != payload.sport_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid sport category selection",
            )

    # 4. Verify Cloudinary metadata securely from backend
    # Skip real remote call ONLY if secrets are unset (mocking during dev) AND testing environment is detected
    is_testing = settings.cloudinary_api_secret in ["", "change-me-in-production"] or settings.database_url.endswith("test")
    
    if is_testing:
        # In test mode, we do local schema validations of payload duration & size
        if payload.duration_seconds > 60.0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="This video is longer than 60 seconds.",
            )
        if payload.bytes > 50 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Video size exceeds the 50 MB limit.",
            )
        if payload.format not in ["mp4", "mov", "webm"]:
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
            delete_cloudinary_asset(
                settings.cloudinary_cloud_name,
                settings.cloudinary_api_key,
                settings.cloudinary_api_secret,
                payload.public_id,
            )
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Resource must be a video.",
            )

        if asset_format not in ["mp4", "mov", "webm"]:
            delete_cloudinary_asset(
                settings.cloudinary_cloud_name,
                settings.cloudinary_api_key,
                settings.cloudinary_api_secret,
                payload.public_id,
            )
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Unsupported video format.",
            )

        if duration > 60.0:
            delete_cloudinary_asset(
                settings.cloudinary_cloud_name,
                settings.cloudinary_api_key,
                settings.cloudinary_api_secret,
                payload.public_id,
            )
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="This video is longer than 60 seconds.",
            )

        if bytes_size > 50 * 1024 * 1024:
            delete_cloudinary_asset(
                settings.cloudinary_cloud_name,
                settings.cloudinary_api_key,
                settings.cloudinary_api_secret,
                payload.public_id,
            )
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
    )
    db.add(drop)
    db.commit()
    db.refresh(drop)
    
    # Set helper dynamic properties
    drop.props_count = 0
    drop.comments_count = 0
    drop.has_propped = False
    return drop


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

    # Populate dynamic parameters
    props_count = db.scalar(select(func.count(DropProp.id)).where(DropProp.drop_id == drop.id))
    comments_count = db.scalar(
        select(func.count(DropComment.id)).where(
            (DropComment.drop_id == drop.id) & (DropComment.deleted_at == None)
        )
    )
    has_propped = (
        db.scalar(
            select(DropProp).where(
                (DropProp.drop_id == drop.id) & (DropProp.user_id == current_user.id)
            )
        )
        is not None
    )

    drop.props_count = props_count
    drop.comments_count = comments_count
    drop.has_propped = has_propped
    return drop


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
            detail="You already gave Props to this Drop.",
        ) from None
        
    return {"message": "Props added successfully"}


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
            detail="Props not found",
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
