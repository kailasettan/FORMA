"""add drops and sports catalog

Revision ID: 20260702_0002
Revises: 20260702_0001
Create Date: 2026-07-02 12:00:00.000000
"""

from typing import Sequence, Union
import uuid
from datetime import datetime

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260702_0002"
down_revision: Union[str, None] = "20260702_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create sports table
    op.create_table(
        "sports",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.String(), nullable=False, unique=True),
        sa.Column("slug", sa.String(), nullable=False, unique=True),
        sa.Column("icon_url", sa.String(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )

    # 2. Create sport_categories table
    op.create_table(
        "sport_categories",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("sport_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("slug", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.ForeignKeyConstraint(["sport_id"], ["sports.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_sport_categories_sport_id", "sport_categories", ["sport_id"])

    # 3. Seed initial sports and categories
    # Define sports
    sports_data = [
        {"name": "Football", "slug": "football"},
        {"name": "Cricket", "slug": "cricket"},
        {"name": "Basketball", "slug": "basketball"},
        {"name": "Athletics", "slug": "athletics"},
        {"name": "Swimming", "slug": "swimming"},
    ]
    
    categories_data = {
        "football": ["dribbling", "finishing", "passing", "defending", "goalkeeping"],
        "cricket": ["batting", "pace bowling", "spin bowling", "fielding"],
        "basketball": ["shooting", "ball handling", "passing", "defending"],
        "athletics": ["sprinting", "jumping", "throwing"],
        "swimming": ["freestyle", "backstroke", "breaststroke", "butterfly"]
    }

    # Bulk insert sports and categories
    connection = op.get_bind()
    
    for sport in sports_data:
        sport_id = str(uuid.uuid4())
        connection.execute(sa.text(
            f"INSERT INTO sports (id, name, slug, is_active) VALUES ('{sport_id}', '{sport['name']}', '{sport['slug']}', true)"
        ))
        
        # Insert categories for this sport
        slug = sport["slug"]
        if slug in categories_data:
            for idx, cat_name in enumerate(categories_data[slug]):
                cat_id = str(uuid.uuid4())
                cat_slug = cat_name.lower().replace(" ", "_")
                connection.execute(sa.text(
                    f"INSERT INTO sport_categories (id, sport_id, name, slug, is_active, display_order) "
                    f"VALUES ('{cat_id}', '{sport_id}', '{cat_name.title()}', '{cat_slug}', true, {idx})"
                ))

    # 4. Alter users table
    op.add_column("users", sa.Column("headline", sa.String(), nullable=True))
    op.add_column("users", sa.Column("bio", sa.String(), nullable=True))
    op.add_column("users", sa.Column("location", sa.String(), nullable=True))
    op.add_column("users", sa.Column("availability", sa.String(), nullable=True))
    op.add_column("users", sa.Column("preferred_opportunity_types", postgresql.JSONB(), nullable=True))
    op.add_column("users", sa.Column("role", sa.String(), nullable=False, server_default="athlete"))
    op.add_column("users", sa.Column("focused_sport_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key("fk_users_focused_sport", "users", "sports", ["focused_sport_id"], ["id"], ondelete="SET NULL")

    # 5. Alter player_profiles table
    op.add_column("player_profiles", sa.Column("sport_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("player_profiles", sa.Column("role_or_discipline", sa.String(), nullable=True))
    op.create_foreign_key("fk_player_profiles_sport_id", "player_profiles", "sports", ["sport_id"], ["id"], ondelete="CASCADE")

    # 6. Migrate existing profiles
    # Select all sports to get their ids and slugs
    sports_rows = connection.execute(sa.text("SELECT id, slug FROM sports")).fetchall()
    sport_slug_to_id = {row[1]: row[0] for row in sports_rows}
    
    # Copy position to role_or_discipline and map sport enum to sport_id
    profiles_rows = connection.execute(sa.text("SELECT id, sport, position FROM player_profiles")).fetchall()
    for profile in profiles_rows:
        p_id = profile[0]
        p_sport = profile[1] # Enum value like 'football'
        p_pos = profile[2]
        
        sport_uuid = sport_slug_to_id.get(p_sport)
        if sport_uuid:
            connection.execute(sa.text(
                f"UPDATE player_profiles SET sport_id = '{sport_uuid}', role_or_discipline = :pos WHERE id = '{p_id}'"
            ).bindparams(pos=p_pos))

    # Now make sport_id non-nullable
    op.alter_column("player_profiles", "sport_id", nullable=False)

    # Recreate Unique constraint on user_id + sport_id
    op.drop_constraint("uq_player_profiles_user_sport", "player_profiles", type_="unique")
    op.create_unique_constraint("uq_player_profiles_user_sport_id", "player_profiles", ["user_id", "sport_id"])

    # Drop old sport column from player_profiles
    op.drop_column("player_profiles", "sport")

    # 7. Create drops table
    op.create_table(
        "drops",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("player_profile_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("sport_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("category_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("provider", sa.String(), nullable=False, server_default="cloudinary"),
        sa.Column("provider_asset_id", sa.String(), nullable=False),
        sa.Column("public_id", sa.String(), nullable=False, unique=True),
        sa.Column("playback_url", sa.String(), nullable=False),
        sa.Column("thumbnail_url", sa.String(), nullable=True),
        sa.Column("caption", sa.String(), nullable=True),
        sa.Column("duration_seconds", sa.Numeric(precision=6, scale=2), nullable=False),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.Column("format", sa.String(), nullable=False),
        sa.Column("bytes", sa.Integer(), nullable=False),
        sa.Column("moderation_status", sa.String(), nullable=False, server_default="approved"),
        sa.Column("visibility", sa.String(), nullable=False, server_default="public"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["player_profile_id"], ["player_profiles.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["sport_id"], ["sports.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["category_id"], ["sport_categories.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_drops_user_id", "drops", ["user_id"])
    op.create_index("ix_drops_sport_id", "drops", ["sport_id"])

    # 8. Create drop_props table
    op.create_table(
        "drop_props",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("drop_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["drop_id"], ["drops.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("drop_id", "user_id", name="uq_drop_props_drop_user"),
    )
    op.create_index("ix_drop_props_drop_id", "drop_props", ["drop_id"])
    op.create_index("ix_drop_props_user_id", "drop_props", ["user_id"])

    # 9. Create drop_comments table
    op.create_table(
        "drop_comments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("drop_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("body", sa.String(length=500), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("deleted_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["drop_id"], ["drops.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_drop_comments_drop_id", "drop_comments", ["drop_id"])
    op.create_index("ix_drop_comments_user_id", "drop_comments", ["user_id"])

    # 10. Create scout_shortlists table
    op.create_table(
        "scout_shortlists",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("scout_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("athlete_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("drop_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("private_note", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["scout_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["athlete_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["drop_id"], ["drops.id"], ondelete="SET NULL"),
        sa.UniqueConstraint("scout_user_id", "athlete_user_id", name="uq_scout_shortlists_scout_athlete"),
    )
    op.create_index("ix_scout_shortlists_scout_user_id", "scout_shortlists", ["scout_user_id"])
    op.create_index("ix_scout_shortlists_athlete_user_id", "scout_shortlists", ["athlete_user_id"])


def downgrade() -> None:
    op.drop_index("ix_scout_shortlists_athlete_user_id", table_name="scout_shortlists")
    op.drop_index("ix_scout_shortlists_scout_user_id", table_name="scout_shortlists")
    op.drop_table("scout_shortlists")
    
    op.drop_index("ix_drop_comments_user_id", table_name="drop_comments")
    op.drop_index("ix_drop_comments_drop_id", table_name="drop_comments")
    op.drop_table("drop_comments")
    
    op.drop_index("ix_drop_props_user_id", table_name="drop_props")
    op.drop_index("ix_drop_props_drop_id", table_name="drop_props")
    op.drop_table("drop_props")
    
    op.drop_index("ix_drops_sport_id", table_name="drops")
    op.drop_index("ix_drops_user_id", table_name="drops")
    op.drop_table("drops")
    
    # Restore player_profiles sport column
    op.add_column("player_profiles", sa.Column("sport", postgresql.ENUM("football", "cricket", "basketball", name="sport_enum"), nullable=True))
    
    # Copy data back
    connection = op.get_bind()
    sports_rows = connection.execute(sa.text("SELECT id, slug FROM sports")).fetchall()
    id_to_sport_slug = {row[0]: row[1] for row in sports_rows}
    
    profiles_rows = connection.execute(sa.text("SELECT id, sport_id FROM player_profiles")).fetchall()
    for profile in profiles_rows:
        p_id = profile[0]
        p_sport_id = profile[1]
        sport_slug = id_to_sport_slug.get(p_sport_id)
        if sport_slug in ["football", "cricket", "basketball"]:
            connection.execute(sa.text(
                f"UPDATE player_profiles SET sport = '{sport_slug}' WHERE id = '{p_id}'"
            ))
            
    op.alter_column("player_profiles", "sport", nullable=False)
    
    op.drop_constraint("uq_player_profiles_user_sport_id", "player_profiles", type_="unique")
    op.create_unique_constraint("uq_player_profiles_user_sport", "player_profiles", ["user_id", "sport"])
    
    op.drop_constraint("fk_player_profiles_sport_id", "player_profiles", type_="foreignkey")
    op.drop_column("player_profiles", "sport_id")
    op.drop_column("player_profiles", "role_or_discipline")
    
    op.drop_constraint("fk_users_focused_sport", "users", type_="foreignkey")
    op.drop_column("users", "focused_sport_id")
    op.drop_column("users", "role")
    op.drop_column("users", "preferred_opportunity_types")
    op.drop_column("users", "availability")
    op.drop_column("users", "location")
    op.drop_column("users", "bio")
    op.drop_column("users", "headline")
    
    op.drop_index("ix_sport_categories_sport_id", table_name="sport_categories")
    op.drop_table("sport_categories")
    op.drop_table("sports")
