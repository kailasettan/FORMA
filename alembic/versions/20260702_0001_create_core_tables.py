"""create core tables

Revision ID: 20260702_0001
Revises:
Create Date: 2026-07-02 00:00:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260702_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

sport_enum = postgresql.ENUM(
    "football", "cricket", "basketball", name="sport_enum", create_type=False
)
skill_level_enum = postgresql.ENUM(
    "beginner", "intermediate", "advanced", name="skill_level_enum", create_type=False
)


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    op.execute("CREATE EXTENSION IF NOT EXISTS citext")
    sport_enum.create(op.get_bind(), checkfirst=True)
    skill_level_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "users",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("username", postgresql.CITEXT(), nullable=False),
        sa.Column("email", postgresql.CITEXT(), nullable=False),
        sa.Column("password_hash", sa.String(), nullable=False),
        sa.Column("full_name", sa.String(), nullable=False),
        sa.Column("age", sa.Integer(), nullable=True),
        sa.Column("city", sa.String(), nullable=True),
        sa.Column("profile_photo_url", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_users_username", "users", ["username"], unique=True)
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "player_profiles",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("sport", sport_enum, nullable=False),
        sa.Column("position", sa.String(), nullable=True),
        sa.Column("skill_level", skill_level_enum, nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "sport", name="uq_player_profiles_user_sport"),
    )
    op.create_index("ix_player_profiles_user_id", "player_profiles", ["user_id"])

    op.create_table(
        "match_stats",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("sport", sport_enum, nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("opponent", sa.String(), nullable=False),
        sa.Column("stats", postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_match_stats_user_id", "match_stats", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_match_stats_user_id", table_name="match_stats")
    op.drop_table("match_stats")
    op.drop_index("ix_player_profiles_user_id", table_name="player_profiles")
    op.drop_table("player_profiles")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_index("ix_users_username", table_name="users")
    op.drop_table("users")
    skill_level_enum.drop(op.get_bind(), checkfirst=True)
    sport_enum.drop(op.get_bind(), checkfirst=True)
