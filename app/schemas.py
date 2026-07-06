from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import SkillLevel, Sport


# Sport Catalog Schemas
class SportCatalogOut(BaseModel):
    id: UUID
    name: str
    slug: str
    icon_url: str | None = None
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SportCategoryOut(BaseModel):
    id: UUID
    sport_id: UUID
    name: str
    slug: str
    is_active: bool
    display_order: int

    model_config = ConfigDict(from_attributes=True)


# User Schemas
class UserOut(BaseModel):
    id: UUID
    username: str
    full_name: str
    age: int | None = None
    city: str | None = None
    profile_photo_url: str | None = None
    created_at: datetime
    
    # Phase 5 additions
    headline: str | None = None
    bio: str | None = None
    location: str | None = None
    availability: str | None = None
    preferred_opportunity_types: list[str] | None = None
    role: str
    focused_sport_id: UUID | None = None

    model_config = ConfigDict(from_attributes=True)


class PrivateUserOut(UserOut):
    email: EmailStr


class SignUpIn(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=8)
    full_name: str = Field(min_length=1)
    role: str = "athlete"  # athlete or scout


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: PrivateUserOut


class UserUpdateIn(BaseModel):
    username: str | None = Field(default=None, min_length=3, max_length=50)
    full_name: str | None = Field(default=None, min_length=1)
    age: int | None = Field(default=None, ge=0)
    city: str | None = None
    profile_photo_url: str | None = None
    
    # Phase 5 updates
    headline: str | None = None
    bio: str | None = None
    location: str | None = None
    availability: str | None = None
    preferred_opportunity_types: list[str] | None = None
    focused_sport_id: UUID | None = None


# Player Profile Schemas
class PlayerProfileCreateIn(BaseModel):
    sport_id: UUID
    role_or_discipline: str | None = None
    skill_level: SkillLevel


class PlayerProfileUpdateIn(BaseModel):
    role_or_discipline: str | None = None
    skill_level: SkillLevel | None = None


class PlayerProfileOut(BaseModel):
    id: UUID
    user_id: UUID
    sport_id: UUID
    role_or_discipline: str | None = None
    position: str | None = None  # Legacy position field compat
    skill_level: SkillLevel
    sport: SportCatalogOut | None = None

    model_config = ConfigDict(from_attributes=True)


# Cloudinary Signatures
class UploadSignatureOut(BaseModel):
    signature: str
    timestamp: int
    api_key: str
    folder: str
    overwrite: str
    unique_filename: str
    cloud_name: str
    upload_preset: str | None = None
    resource_type: str | None = None
    public_id: str | None = None
    allowed_formats: str | None = None


# Drops Schemas
class DropCreateIn(BaseModel):
    provider_asset_id: str = Field(min_length=1)
    public_id: str = Field(min_length=1)
    playback_url: str = Field(min_length=1)
    thumbnail_url: str | None = None
    duration_seconds: float = Field(gt=0)
    width: int | None = None
    height: int | None = None
    format: str = Field(min_length=1)
    bytes: int = Field(gt=0)
    sport_id: UUID
    category_id: UUID | None = None
    caption: str | None = None
    visibility: str = "public"

    @field_validator("format")
    @classmethod
    def format_must_be_supported(cls, value: str) -> str:
        normalized = value.lower().strip()
        if normalized not in {"mp4", "mov", "webm"}:
            raise ValueError("format must be one of: mp4, mov, webm")
        return normalized

    @field_validator("visibility")
    @classmethod
    def visibility_must_be_supported(cls, value: str) -> str:
        normalized = value.lower().strip()
        if normalized not in {"public", "private"}:
            raise ValueError("visibility must be one of: public, private")
        return normalized


class DropOut(BaseModel):
    id: UUID
    user_id: UUID
    player_profile_id: UUID | None
    sport_id: UUID
    category_id: UUID | None
    provider: str
    provider_asset_id: str
    public_id: str
    playback_url: str
    thumbnail_url: str | None
    caption: str | None
    duration_seconds: float
    width: int | None
    height: int | None
    format: str
    bytes: int
    moderation_status: str
    visibility: str
    created_at: datetime
    updated_at: datetime
    
    # Interactions and metadata
    props_count: int = 0
    comments_count: int = 0
    has_propped: bool = False
    user: UserOut | None = None
    sport: SportCatalogOut | None = None
    category: SportCategoryOut | None = None

    model_config = ConfigDict(from_attributes=True)


class DropFeedOut(BaseModel):
    items: list[DropOut]
    next_cursor: datetime | None = None


# Props & Comments
class DropCommentCreateIn(BaseModel):
    body: str = Field(min_length=1, max_length=500)


class DropCommentOut(BaseModel):
    id: UUID
    drop_id: UUID
    user_id: UUID
    body: str
    created_at: datetime
    user: UserOut | None = None

    model_config = ConfigDict(from_attributes=True)


# Scout Shortlists
class ScoutShortlistCreateIn(BaseModel):
    athlete_user_id: UUID | None = None
    drop_id: UUID | None = None
    private_note: str | None = None


class ScoutShortlistOut(BaseModel):
    id: UUID
    scout_user_id: UUID
    athlete_user_id: UUID
    drop_id: UUID | None = None
    private_note: str | None = None
    created_at: datetime
    athlete: UserOut | None = None

    model_config = ConfigDict(from_attributes=True)


# Public Profile
class PublicAthleteProfileOut(BaseModel):
    user: UserOut
    player_profiles: list[PlayerProfileOut]
    drops: list[DropOut]
    is_shortlisted: bool = False
    profile_completion_percentage: int = 0


# Legacy Match Stats Schemas (kept for compile-time safety and migration)
class MatchStatCreateIn(BaseModel):
    sport: Sport
    date: date
    opponent: str = Field(min_length=1)
    stats: dict[str, int]

    @field_validator("stats")
    @classmethod
    def stats_values_must_be_non_negative(cls, stats: dict[str, int]) -> dict[str, int]:
        for key, value in stats.items():
            if value < 0:
                raise ValueError(f"{key} must be non-negative")
        return stats


class MatchStatOut(BaseModel):
    id: UUID
    user_id: UUID
    sport: Sport
    date: date
    opponent: str
    stats: dict[str, int]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
