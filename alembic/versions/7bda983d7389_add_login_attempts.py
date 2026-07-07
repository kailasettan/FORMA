"""add_login_attempts

Revision ID: 7bda983d7389
Revises: 20260707_0006
Create Date: 2026-07-07 13:54:27.108923

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '7bda983d7389'
down_revision: Union[str, None] = '20260707_0006'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _table_exists(table_name: str) -> bool:
    return inspect(op.get_bind()).has_table(table_name)


def _column_exists(table_name: str, column_name: str) -> bool:
    if not _table_exists(table_name):
        return False
    inspector = inspect(op.get_bind())
    return column_name in {column["name"] for column in inspector.get_columns(table_name)}


def _index_exists(table_name: str, index_name: str) -> bool:
    if not _table_exists(table_name):
        return False
    inspector = inspect(op.get_bind())
    return index_name in {index["name"] for index in inspector.get_indexes(table_name)}


def _unique_constraint_exists(table_name: str, constraint_name: str) -> bool:
    if not _table_exists(table_name):
        return False
    inspector = inspect(op.get_bind())
    return constraint_name in {
        constraint["name"] for constraint in inspector.get_unique_constraints(table_name)
    }


def upgrade() -> None:
    if not _table_exists("login_attempts"):
        op.create_table(
            "login_attempts",
            sa.Column("id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
            sa.Column("identifier", postgresql.CITEXT(), nullable=False),
            sa.Column("attempts", sa.Integer(), nullable=False),
            sa.Column("last_attempt_at", sa.DateTime(), nullable=False),
            sa.PrimaryKeyConstraint("id"),
        )
    if not _index_exists("login_attempts", "ix_login_attempts_identifier"):
        op.create_index(
            op.f("ix_login_attempts_identifier"),
            "login_attempts",
            ["identifier"],
            unique=True,
        )

    # The earlier OTP migration dfa9f9720e16 already owns email_otps.purpose
    # and uq_email_otps_user_purpose. Keep this revision safe for production
    # databases that already have those objects.
    if _table_exists("email_otps"):
        if not _column_exists("email_otps", "purpose"):
            op.add_column(
                "email_otps",
                sa.Column(
                    "purpose",
                    sa.String(),
                    nullable=False,
                    server_default="email_verification",
                ),
            )
            op.alter_column("email_otps", "purpose", server_default=None)

        if _unique_constraint_exists("email_otps", "email_otps_user_id_key"):
            op.drop_constraint("email_otps_user_id_key", "email_otps", type_="unique")
        if not _unique_constraint_exists("email_otps", "uq_email_otps_user_purpose"):
            op.create_unique_constraint(
                "uq_email_otps_user_purpose",
                "email_otps",
                ["user_id", "purpose"],
            )


def downgrade() -> None:
    if _table_exists("login_attempts"):
        if _index_exists("login_attempts", "ix_login_attempts_identifier"):
            op.drop_index(op.f("ix_login_attempts_identifier"), table_name="login_attempts")
        op.drop_table("login_attempts")
