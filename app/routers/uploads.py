import hashlib
import time

from fastapi import APIRouter, Depends

from app.config import settings
from app.dependencies import get_current_user
from app.models import User
from app.schemas import UploadSignatureOut

router = APIRouter(prefix="/uploads", tags=["uploads"])


def generate_cloudinary_signature(api_secret: str, params: dict) -> str:
    sorted_params = sorted(params.items())
    param_string = "&".join(f"{key}={value}" for key, value in sorted_params)
    return hashlib.sha1(f"{param_string}{api_secret}".encode("utf-8")).hexdigest()


@router.post("/profile-photo/signature", response_model=UploadSignatureOut)
def get_profile_photo_upload_signature(
    current_user: User = Depends(get_current_user),
) -> dict:
    timestamp = int(time.time())
    public_id = f"profile_{current_user.id}"
    params = {
        "allowed_formats": "jpg,jpeg,png,webp",
        "folder": "forma/profile_photos",
        "overwrite": "true",
        "public_id": public_id,
        "timestamp": timestamp,
        "unique_filename": "false",
    }
    signature = generate_cloudinary_signature(settings.cloudinary_api_secret, params)
    return {
        "signature": signature,
        "timestamp": timestamp,
        "api_key": settings.cloudinary_api_key,
        "folder": "forma/profile_photos",
        "overwrite": "true",
        "unique_filename": "false",
        "cloud_name": settings.cloudinary_cloud_name,
        "resource_type": "image",
        "public_id": public_id,
        "allowed_formats": "jpg,jpeg,png,webp",
    }
