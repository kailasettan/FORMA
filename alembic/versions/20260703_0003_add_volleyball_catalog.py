"""add volleyball catalog

Revision ID: 20260703_0003
Revises: 20260702_0002
Create Date: 2026-07-03 01:30:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "20260703_0003"
down_revision: Union[str, None] = "20260702_0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


VOLLEYBALL_CATEGORIES = [
    ("Serving", "serving"),
    ("Setting", "setting"),
    ("Spiking", "spiking"),
    ("Blocking", "blocking"),
    ("Digging", "digging"),
    ("Receiving", "receiving"),
    ("Defense", "defense"),
    ("Match Highlight", "match_highlight"),
    ("Training Drill", "training_drill"),
]


def upgrade() -> None:
    connection = op.get_bind()
    volleyball_id = connection.execute(
        sa.text(
            """
            INSERT INTO sports (id, name, slug, is_active)
            VALUES (gen_random_uuid(), 'Volleyball', 'volleyball', true)
            ON CONFLICT (slug) DO UPDATE
            SET name = EXCLUDED.name,
                is_active = true
            RETURNING id
            """
        )
    ).scalar_one()

    for display_order, (name, slug) in enumerate(VOLLEYBALL_CATEGORIES):
        connection.execute(
            sa.text(
                """
                INSERT INTO sport_categories (
                    id,
                    sport_id,
                    name,
                    slug,
                    is_active,
                    display_order
                )
                SELECT
                    gen_random_uuid(),
                    :sport_id,
                    :name,
                    :slug,
                    true,
                    :display_order
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM sport_categories
                    WHERE sport_id = :sport_id
                      AND slug = :slug
                )
                """
            ).bindparams(
                sport_id=volleyball_id,
                name=name,
                slug=slug,
                display_order=display_order,
            )
        )
        connection.execute(
            sa.text(
                """
                UPDATE sport_categories
                SET name = :name,
                    is_active = true,
                    display_order = :display_order
                WHERE sport_id = :sport_id
                  AND slug = :slug
                """
            ).bindparams(
                sport_id=volleyball_id,
                name=name,
                slug=slug,
                display_order=display_order,
            )
        )


def downgrade() -> None:
    connection = op.get_bind()
    volleyball_id = connection.execute(
        sa.text("SELECT id FROM sports WHERE slug = 'volleyball'")
    ).scalar_one_or_none()
    if volleyball_id is None:
        return

    connection.execute(
        sa.text(
            """
            DELETE FROM sport_categories
            WHERE sport_id = :sport_id
              AND slug IN :slugs
            """
        ).bindparams(
            sa.bindparam("slugs", expanding=True),
            sport_id=volleyball_id,
            slugs=[slug for _, slug in VOLLEYBALL_CATEGORIES],
        )
    )
    connection.execute(
        sa.text(
            """
            DELETE FROM sports
            WHERE id = :sport_id
              AND NOT EXISTS (
                  SELECT 1 FROM drops WHERE sport_id = :sport_id
              )
              AND NOT EXISTS (
                  SELECT 1 FROM player_profiles WHERE sport_id = :sport_id
              )
              AND NOT EXISTS (
                  SELECT 1 FROM users WHERE focused_sport_id = :sport_id
              )
            """
        ).bindparams(sport_id=volleyball_id)
    )
