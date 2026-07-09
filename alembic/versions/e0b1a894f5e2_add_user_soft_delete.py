"""add_user_soft_delete

Revision ID: e0b1a894f5e2
Revises: 7bda983d7389
Create Date: 2026-07-08 19:37:10.210049

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e0b1a894f5e2'
down_revision: Union[str, None] = '7bda983d7389'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False))
    op.add_column('users', sa.Column('deleted_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'deleted_at')
    op.drop_column('users', 'is_active')

