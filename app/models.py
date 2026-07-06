import enum
from datetime import date, datetime
from uuid import UUID

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, UniqueConstraint, func, text
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

    # Phase 5 additions
    headline: Mapped[str | None] = mapped_column(String, nullable=True)
    bio: Mapped[str | None] = mapped_column(String, nullable=True)
    location: Mapped[str | None] = mapped_column(String, nullable=True)
    availability: Mapped[str | None] = mapped_column(String, nullable=True)
    preferred_opportunity_types: Mapped[list[str] | None] = mapped_column(JSONB, nullable=True)
    role: Mapped[str] = mapped_column(String, default="athlete", nullable=False)
    focused_sport_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("sports.id", ondelete="SET NULL"), nullable=True
    )

    player_profiles: Mapped[list["PlayerProfile"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    match_stats: Mapped[list["MatchStat"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    drops: Mapped[list["Drop"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    props: Mapped[list["DropProp"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    comments: Mapped[list["DropComment"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class SportCatalog(Base):
    __tablename__ = "sports"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    slug: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    icon_url: Mapped[str | None] = mapped_column(String, nullable=True)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class SportCategory(Base):
    __tablename__ = "sport_categories"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    sport_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("sports.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    slug: Mapped[str] = mapped_column(String, nullable=False)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)
    display_order: Mapped[int] = mapped_column(default=0, nullable=False)


class PlayerProfile(Base):
    __tablename__ = "player_profiles"
    __table_args__ = (UniqueConstraint("user_id", "sport_id", name="uq_player_profiles_user_sport_id"),)

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sport_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("sports.id", ondelete="CASCADE"), nullable=False, index=True
    )
    role_or_discipline: Mapped[str | None] = mapped_column(String, nullable=True)
    position: Mapped[str | None] = mapped_column(String, nullable=True)
    skill_level: Mapped[SkillLevel] = mapped_column(
        Enum(SkillLevel, name="skill_level_enum"), nullable=False
    )

    user: Mapped[User] = relationship(back_populates="player_profiles")
    sport: Mapped[SportCatalog] = relationship()


class Drop(Base):
    __tablename__ = "drops"
    __table_args__ = (
        UniqueConstraint("provider_asset_id", name="uq_drops_provider_asset_id"),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    player_profile_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("player_profiles.id", ondelete="SET NULL"), nullable=True
    )
    sport_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("sports.id", ondelete="SET NULL"), nullable=True, index=True
    )
    category_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("sport_categories.id", ondelete="SET NULL"), nullable=True
    )
    provider: Mapped[str] = mapped_column(String, default="cloudinary", nullable=False)
    provider_asset_id: Mapped[str] = mapped_column(String, nullable=False)
    public_id: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    playback_url: Mapped[str] = mapped_column(String, nullable=False)
    thumbnail_url: Mapped[str | None] = mapped_column(String, nullable=True)
    caption: Mapped[str | None] = mapped_column(String, nullable=True)
    duration_seconds: Mapped[float] = mapped_column(Numeric(precision=6, scale=2), nullable=False)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    format: Mapped[str] = mapped_column(String, nullable=False)
    bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    moderation_status: Mapped[str] = mapped_column(String, default="approved", nullable=False)
    visibility: Mapped[str] = mapped_column(String, default="public", nullable=False)
    audience: Mapped[str | None] = mapped_column(String, default="public", nullable=True)
    location: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now(), onupdate=func.now()
    )

    user: Mapped[User] = relationship(back_populates="drops")
    sport: Mapped[SportCatalog] = relationship()
    category: Mapped[SportCategory] = relationship()
    props: Mapped[list["DropProp"]] = relationship(
        cascade="all, delete-orphan"
    )
    comments: Mapped[list["DropComment"]] = relationship(
        cascade="all, delete-orphan"
    )


class OrphanedCloudinaryAsset(Base):
    __tablename__ = "orphaned_cloudinary_assets"
    __table_args__ = (
        UniqueConstraint("provider_asset_id", name="uq_orphaned_cloudinary_assets_provider_asset_id"),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    provider_asset_id: Mapped[str] = mapped_column(String, nullable=False)
    public_id: Mapped[str] = mapped_column(String, nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, default="pending_cleanup", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class DropProp(Base):
    __tablename__ = "drop_props"
    __table_args__ = (UniqueConstraint("drop_id", "user_id", name="uq_drop_props_drop_user"),)

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    drop_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("drops.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="props")


class DropComment(Base):
    __tablename__ = "drop_comments"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    drop_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("drops.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    body: Mapped[str] = mapped_column(String(500), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    user: Mapped[User] = relationship(back_populates="comments")


class ScoutShortlist(Base):
    __tablename__ = "scout_shortlists"
    __table_args__ = (UniqueConstraint("scout_user_id", "athlete_user_id", name="uq_scout_shortlists_scout_athlete"),)

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    scout_user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    athlete_user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    drop_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("drops.id", ondelete="SET NULL"), nullable=True
    )
    private_note: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class MatchStat(Base):
    __tablename__ = "match_stats"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sport: Mapped[Sport | None] = mapped_column(Enum(Sport, name="sport_enum"), nullable=True)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    opponent: Mapped[str] = mapped_column(String, nullable=False)
    stats: Mapped[dict[str, int] | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="match_stats")
