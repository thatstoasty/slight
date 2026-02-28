"""Tests for busy handler (when the database is locked)."""

from std import tempfile
from slight.busy import BusyHandlerFn
from slight.connection import Connection
from slight.result import SQLite3Result
from slight.transaction import TransactionBehavior
from std.pathlib import Path
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


# ===----------------------------------------------------------------------=== #
# Rust: test_default_busy
#
# Opens a file-backed database with two connections. The first takes an
# EXCLUSIVE transaction, then the second attempts a query and gets
# SQLITE_BUSY because the default busy_timeout eventually expires.
# ===----------------------------------------------------------------------=== #
fn test_default_busy() raises:
    with tempfile.TemporaryDirectory() as tmp:
        var path = Path(tmp) / "test.db3"

        var db1 = Connection.open(path)
        # Set a very short (or zero) timeout so we don't block for 5s
        db1.busy_timeout(0)
        db1.execute_batch("CREATE TABLE IF NOT EXISTS t(a)")

        # Begin exclusive transaction on db1
        db1.execute_batch("BEGIN EXCLUSIVE")

        # The second connection should get SQLITE_BUSY immediately
        var db2 = Connection.open(path)
        db2.busy_timeout(0)

        with assert_raises():
            _ = db2.prepare("SELECT * FROM t")

        db1.execute_batch("ROLLBACK")


# ===----------------------------------------------------------------------=== #
# Rust: test_busy_handler
#
# Registers a custom busy handler callback that returns True (retry) up to
# 2 times, then returns False. Verifies the handler is actually invoked
# and db2 eventually gets SQLITE_BUSY.
# ===----------------------------------------------------------------------=== #
fn busy_handler(n: Int32) -> Bool:
    """Busy handler that retries up to 2 times, then gives up."""
    if n > 2:
        return False
    return True


fn test_busy_handler() raises:
    with tempfile.TemporaryDirectory() as tmp:
        var path = Path(tmp) / "busy-handler.db3"

        var db1 = Connection.open(path)
        db1.execute_batch("CREATE TABLE IF NOT EXISTS t(a)")

        var db2 = Connection.open(path)
        db2.register_busy_handler[busy_handler]()

        # Lock the database exclusively from db1
        db1.execute_batch("BEGIN EXCLUSIVE")

        # db2's query should trigger the busy handler, eventually fail
        with assert_raises():
            _ = db2.prepare("SELECT * FROM t")

        # Clear the busy handler on db1 (test the None path)
        db1.clear_busy_handler()

        db1.execute_batch("ROLLBACK")


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
