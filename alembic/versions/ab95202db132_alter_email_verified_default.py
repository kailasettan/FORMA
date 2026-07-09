"""alter_email_verified_default

Revision ID: ab95202db132
Revises: e0b1a894f5e2
Create Date: 2026-07-09 22:01:33.171837

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ab95202db132'
down_revision: Union[str, None] = 'e0b1a894f5e2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Backfill existing users as verified
    op.execute("UPDATE users SET email_verified = true")
    # Change server_default for new users to false
    op.alter_column('users', 'email_verified', server_default=sa.text('false'))


def downgrade() -> None:
    # Change server_default back to true
    op.alter_column('users', 'email_verified', server_default=sa.text('true'))

