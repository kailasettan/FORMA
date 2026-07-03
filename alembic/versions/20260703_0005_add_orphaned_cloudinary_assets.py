"""add orphaned cloudinary assets

Revision ID: 20260703_0005
Revises: 20260703_0004
Create Date: 2026-07-03 12:30:00.000000
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "20260703_0005"
down_revision: Union[str, None] = "20260703_0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "orphaned_cloudinary_assets",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("provider_asset_id", sa.String(), nullable=False),
        sa.Column("public_id", sa.String(), nullable=False),
        sa.Column("reason", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="pending_cleanup"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "provider_asset_id",
            name="uq_orphaned_cloudinary_assets_provider_asset_id",
        ),
    )
    op.create_index(
        "ix_orphaned_cloudinary_assets_user_id",
        "orphaned_cloudinary_assets",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_orphaned_cloudinary_assets_user_id",
        table_name="orphaned_cloudinary_assets",
    )
    op.drop_table("orphaned_cloudinary_assets")
