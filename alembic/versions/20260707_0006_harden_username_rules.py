"""harden_username_rules

Revision ID: 20260707_0006
Revises: dfa9f9720e16
Create Date: 2026-07-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260707_0006"
down_revision: Union[str, None] = "dfa9f9720e16"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

NORMALIZED_USERNAME_SQL = "regexp_replace(lower(btrim(username::text)), '\\s+', '_', 'g')"
USERNAME_CHECK_SQL = (
    "username::text ~ '^[a-z0-9._]{3,30}$' "
    "AND username::text !~ '^[._]' "
    "AND username::text !~ '[._]$' "
    "AND username::text !~ '\\.\\.'"
)


def upgrade() -> None:
    bind = op.get_bind()

    conflicts = bind.execute(
        sa.text(
            f"""
            SELECT normalized_username, array_agg(username::text ORDER BY username::text) AS usernames
            FROM (
                SELECT username, {NORMALIZED_USERNAME_SQL} AS normalized_username
                FROM users
            ) normalized
            GROUP BY normalized_username
            HAVING count(*) > 1
            """
        )
    ).fetchall()
    if conflicts:
        details = "; ".join(
            f"{row.normalized_username}: {', '.join(row.usernames)}"
            for row in conflicts
        )
        raise RuntimeError(
            "Username normalization would create duplicate usernames. "
            f"Resolve these conflicts before migrating: {details}"
        )

    invalid_after_cleanup = bind.execute(
        sa.text(
            f"""
            SELECT username::text AS username, {NORMALIZED_USERNAME_SQL} AS normalized_username
            FROM users
            WHERE NOT (
                {NORMALIZED_USERNAME_SQL} ~ '^[a-z0-9._]{{3,30}}$'
                AND {NORMALIZED_USERNAME_SQL} !~ '^[._]'
                AND {NORMALIZED_USERNAME_SQL} !~ '[._]$'
                AND {NORMALIZED_USERNAME_SQL} !~ '\\.\\.'
            )
            ORDER BY username::text
            """
        )
    ).fetchall()
    if invalid_after_cleanup:
        details = "; ".join(
            f"{row.username} -> {row.normalized_username}"
            for row in invalid_after_cleanup
        )
        raise RuntimeError(
            "Existing usernames cannot be safely normalized to the new username rule. "
            f"Resolve these usernames before migrating: {details}"
        )

    op.execute(
        sa.text(
            f"""
            UPDATE users
            SET username = {NORMALIZED_USERNAME_SQL}
            WHERE username::text <> {NORMALIZED_USERNAME_SQL}
            """
        )
    )
    op.create_check_constraint(
        "ck_users_username_instagram_style",
        "users",
        USERNAME_CHECK_SQL,
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_users_username_instagram_style",
        "users",
        type_="check",
    )
