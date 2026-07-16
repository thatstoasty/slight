"""Tests for the authorizer callback."""

from slight.authorizer import AuthAction, AuthResult
from slight.connection import Connection
from slight.c.types import ImmutExternalStringSlice
from std.testing import TestSuite, assert_equal, assert_raises


# ===----------------------------------------------------------------------=== #
# Deny DROP TABLE, allow everything else.
# ===----------------------------------------------------------------------=== #
def _deny_drop_table(
    action: AuthAction,
    arg1: Optional[ImmutExternalStringSlice],
    arg2: Optional[ImmutExternalStringSlice],
    db_name: Optional[ImmutExternalStringSlice],
    trigger_or_view: Optional[ImmutExternalStringSlice],
) -> AuthResult:
    if action == AuthAction.DROP_TABLE:
        return AuthResult.DENY
    return AuthResult.OK


def test_authorizer_denies_drop_table() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (x INTEGER)")

    db.register_authorizer(_deny_drop_table)

    with assert_raises():
        db.execute_batch("DROP TABLE t")

    db.clear_authorizer()

    # After clearing, the drop should succeed.
    db.execute_batch("DROP TABLE t")


# ===----------------------------------------------------------------------=== #
# Ignore reads of a specific column (treated as NULL rather than denied).
# ===----------------------------------------------------------------------=== #
def _ignore_secret_column(
    action: AuthAction,
    arg1: Optional[ImmutExternalStringSlice],
    arg2: Optional[ImmutExternalStringSlice],
    db_name: Optional[ImmutExternalStringSlice],
    trigger_or_view: Optional[ImmutExternalStringSlice],
) -> AuthResult:
    if action == AuthAction.READ:
        if arg2 and arg2.value() == "secret":
            return AuthResult.IGNORE
    return AuthResult.OK


def test_authorizer_ignores_column_read() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER, secret TEXT)")
    _ = db.execute("INSERT INTO t (id, secret) VALUES (?1, ?2)", (1, "hunter2"))

    db.register_authorizer(_ignore_secret_column)

    var stmt = db.prepare("SELECT secret FROM t WHERE id = 1")
    var saw_null = False
    for row in stmt.query():
        saw_null = not row.get[Optional[ImmutExternalStringSlice]](0)
    assert_equal(saw_null, True)

    db.clear_authorizer()


# ===----------------------------------------------------------------------=== #
# OK path: an authorizer that always allows should not change behavior.
# ===----------------------------------------------------------------------=== #
def _always_ok(
    action: AuthAction,
    arg1: Optional[ImmutExternalStringSlice],
    arg2: Optional[ImmutExternalStringSlice],
    db_name: Optional[ImmutExternalStringSlice],
    trigger_or_view: Optional[ImmutExternalStringSlice],
) -> AuthResult:
    return AuthResult.OK


def test_authorizer_allows_normally() raises:
    var db = Connection.open_in_memory()
    db.register_authorizer(_always_ok)

    db.execute_batch("CREATE TABLE t (x INTEGER)")
    _ = db.execute("INSERT INTO t (x) VALUES (?1)", (42,))

    var stmt = db.prepare("SELECT x FROM t")
    var seen = List[Int64]()
    for row in stmt.query():
        seen.append(row.get[Int64](0))
    assert_equal(len(seen), 1)
    assert_equal(seen[0], Int64(42))

    db.clear_authorizer()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
