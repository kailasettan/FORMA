import enum
from datetime import date, datetime
from uuid import UUID

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, String, UniqueConstraint, func, text
from sqlalchemy.dialects.postgresql import CITEXT, JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Sport(str, enum.Enum):
    football = "football"
    cricket = "cricket"
    basketball = "basketball"


class SkillLevel(str, enum.Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    username: Mapped[str] = mapped_column(CITEXT(), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(CITEXT(), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    city: Mapped[str | None] = mapped_column(String, nullable=True)
    profile_photo_url: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )

    player_profiles: Mapped[list["PlayerProfile"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    match_stats: Mapped[list["MatchStat"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class PlayerProfile(Base):
    __tablename__ = "player_profiles"
    __table_args__ = (UniqueConstraint("user_id", "sport", name="uq_player_profiles_user_sport"),)

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sport: Mapped[Sport] = mapped_column(Enum(Sport, name="sport_enum"), nullable=False)
    position: Mapped[str | None] = mapped_column(String, nullable=True)
    skill_level: Mapped[SkillLevel] = mapped_column(
        Enum(SkillLevel, name="skill_level_enum"), nullable=False
    )

    user: Mapped[User] = relationship(back_populates="player_profiles")


class MatchStat(Base):
    __tablename__ = "match_stats"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sport: Mapped[Sport] = mapped_column(Enum(Sport, name="sport_enum"), nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    opponent: Mapped[str] = mapped_column(String, nullable=False)
    stats: Mapped[dict[str, int]] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="match_stats")
