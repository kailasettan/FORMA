"""add drop provider asset uniqueness

Revision ID: 20260703_0004
Revises: 20260703_0003
Create Date: 2026-07-03 12:00:00.000000
"""

from typing import Sequence, Union

from alembic import op

revision: str = "20260703_0004"
down_revision: Union[str, None] = "20260703_0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_drops_provider_asset_id",
        "drops",
        ["provider_asset_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_drops_provider_asset_id",
        "drops",
        type_="unique",
    )
