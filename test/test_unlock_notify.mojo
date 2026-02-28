"""Tests for unlock notification (shared-cache lock contention)."""

from slight.connection import Connection
from slight.flags import OpenFlag
from slight.result import SQLite3Result
from slight.transaction import TransactionBehavior
from slight.unlock_notify import is_locked, wait_for_unlock_notify
from std.testing import TestSuite, assert_equal, assert_false, assert_true


# ===----------------------------------------------------------------------=== #
# test_is_locked_with_locked_sharedcache
#
# Verifies that `is_locked` returns True when given the
# SQLITE_LOCKED_SHAREDCACHE (262) extended result code directly.
# ===----------------------------------------------------------------------=== #
fn test_is_locked_with_locked_sharedcache() raises:
    var db = Connection.open_in_memory()
    assert_true(is_locked(db.db.db, SQLite3Result.LOCKED_SHAREDCACHE))


# ===----------------------------------------------------------------------=== #
# test_is_locked_with_non_locked_codes
#
# Verifies that `is_locked` returns False for common non-locked result
# codes (OK, BUSY, ERROR, DONE, ROW).
# ===----------------------------------------------------------------------=== #
fn test_is_locked_with_non_locked_codes() raises:
    var db = Connection.open_in_memory()
    assert_false(is_locked(db.db.db, SQLite3Result.OK))
    assert_false(is_locked(db.db.db, SQLite3Result.BUSY))
    assert_false(is_locked(db.db.db, SQLite3Result.ERROR))
    assert_false(is_locked(db.db.db, SQLite3Result.DONE))
    assert_false(is_locked(db.db.db, SQLite3Result.ROW))


# ===----------------------------------------------------------------------=== #
# test_locked_sharedcache_result_code
#
# Verifies that the LOCKED_SHAREDCACHE result code has the expected
# value (262 = SQLITE_LOCKED | (1 << 8)) and that its primary code
# masked to 0xFF equals SQLITE_LOCKED (6).
# ===----------------------------------------------------------------------=== #
fn test_locked_sharedcache_result_code() raises:
    assert_equal(Int(SQLite3Result.LOCKED_SHAREDCACHE.value), 262)
    assert_equal(Int(SQLite3Result.LOCKED_SHAREDCACHE.value & 0xFF), Int(SQLite3Result.LOCKED.value))


# ===----------------------------------------------------------------------=== #
# test_shared_cache_open
#
# Verifies that two connections can be opened to the same shared-cache
# in-memory database, and that one connection can see tables and data
# created by the other.
# ===----------------------------------------------------------------------=== #
fn test_shared_cache_open() raises:
    var url = "file:sc_open_test?mode=memory&cache=shared"
    var flags = OpenFlag.READ_WRITE | OpenFlag.URI | OpenFlag.CREATE

    var db1 = Connection.open(url, flags)
    db1.execute_batch("CREATE TABLE bar (x INTEGER)")
    _ = db1.execute("INSERT INTO bar VALUES (?)", [1])

    # Open second connection to the SAME shared-cache database.
    var db2 = Connection.open(url, flags)

    fn get_int(r: slight.row.Row) raises -> Int:
        return r.get[Int](0)

    # db2 should see the table and data created by db1.
    var result = db2.one_row[get_int]("SELECT x FROM bar")
    assert_equal(result, 1)

    # Keep db1 alive until after the query — ASAP destruction would
    # otherwise close it (and the shared-cache in-memory DB) too early.
    _ = db1^


# ===----------------------------------------------------------------------=== #
# test_shared_cache_locked
#
# Opens two connections to a shared-cache in-memory database. The first
# connection begins an IMMEDIATE transaction (acquiring a write lock),
# then the second connection attempts a write and should get a LOCKED
# error.
# ===----------------------------------------------------------------------=== #
fn test_shared_cache_locked() raises:
    var url = "file:shared_lock_test?mode=memory&cache=shared"
    var flags = OpenFlag.READ_WRITE | OpenFlag.URI | OpenFlag.CREATE

    var db1 = Connection.open(url, flags)
    db1.execute_batch("CREATE TABLE foo (x INTEGER)")

    var db2 = Connection.open(url, flags)

    # Begin an IMMEDIATE transaction on db1, acquiring the write lock.
    var tx = db1.transaction(TransactionBehavior.IMMEDIATE)
    tx.conn[].execute_batch("INSERT INTO foo VALUES (42)")

    # db2 should fail to write because db1 holds the lock.
    var locked = False
    try:
        db2.execute_batch("INSERT INTO foo VALUES (99)")
    except:
        locked = True

    assert_true(locked, "Expected db2 write to fail due to shared-cache lock")

    # Rolling back db1's transaction releases the lock.
    tx^.finish()

    # Now db2 can write successfully.
    db2.execute_batch("INSERT INTO foo VALUES (99)")

    fn get_int(r: slight.row.Row) raises -> Int:
        return r.get[Int](0)

    var result = db2.one_row[get_int]("SELECT SUM(x) FROM foo")
    assert_equal(result, 99)


# ===----------------------------------------------------------------------=== #
# test_wait_for_unlock_notify_no_contention
#
# Calls wait_for_unlock_notify on a connection that is NOT actually
# locked. According to the SQLite docs, if the connection has no pending
# lock contention, sqlite3_unlock_notify returns SQLITE_LOCKED. This
# test verifies that the call returns without hanging.
# ===----------------------------------------------------------------------=== #
fn test_wait_for_unlock_notify_no_contention() raises:
    var db = Connection.open_in_memory()
    # With no actual contention, sqlite3_unlock_notify should return
    # a non-OK code (typically SQLITE_LOCKED) rather than blocking.
    var rc = db.wait_for_unlock_notify()
    # We just verify it doesn't hang and returns a result code.
    assert_true(
        rc == SQLite3Result.OK or rc == SQLite3Result.LOCKED or rc == SQLite3Result.LOCKED_SHAREDCACHE,
        String("Unexpected result from wait_for_unlock_notify: ", rc),
    )


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
