from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import SkillLevel, Sport


class UserOut(BaseModel):
    id: UUID
    username: str
    full_name: str
    age: int | None = None
    city: str | None = None
    profile_photo_url: str | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PrivateUserOut(UserOut):
    email: EmailStr


class SignUpIn(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=8)
    full_name: str = Field(min_length=1)


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


class PlayerProfileCreateIn(BaseModel):
    sport: Sport
    position: str | None = None
    skill_level: SkillLevel


class PlayerProfileUpdateIn(BaseModel):
    position: str | None = None
    skill_level: SkillLevel | None = None


class PlayerProfileOut(BaseModel):
    id: UUID
    user_id: UUID
    sport: Sport
    position: str | None = None
    skill_level: SkillLevel

    model_config = ConfigDict(from_attributes=True)


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
