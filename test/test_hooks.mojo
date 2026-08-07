"""Tests for commit, rollback, and update hooks."""

from std.ffi import _get_global
from slight.c.types import MutExternalPointer
from slight.connection import Connection
from slight.hooks import UpdateOperation
from slight.row import Row
from std.testing import TestSuite, assert_equal, assert_raises


def _get_count(row: Row) raises -> Int64:
    return row.get[Int64](0)


# ===----------------------------------------------------------------------=== #
# Global observation state
#
# Comptime `def` callbacks carry no captured state, so we use a process-
# global struct (same mechanism as `sqlite_ffi()`) to observe side effects
# from within the callbacks.
# ===----------------------------------------------------------------------=== #
struct _HookState:
    var update_calls: Int
    var last_op: Int32
    var last_db: String
    var last_table: String
    var last_rowid: Int64
    var commit_calls: Int
    var rollback_calls: Int

    def __init__(out self):
        self.update_calls = 0
        self.last_op = 0
        self.last_db = ""
        self.last_table = ""
        self.last_rowid = 0
        self.commit_calls = 0
        self.rollback_calls = 0


def _init_hook_state() -> Optional[MutExternalPointer[NoneType]]:
    var ptr = alloc[_HookState](1)
    ptr[] = _HookState()
    return ptr.unsafe_bitcast[NoneType]()


def _destroy_hook_state(state: Optional[MutExternalPointer[NoneType]]):
    if state:
        state.value().unsafe_bitcast[_HookState]().unsafe_free()


def _hook_state() -> MutExternalPointer[_HookState]:
    return _get_global["test_hooks_state", _init_hook_state, _destroy_hook_state]().value().unsafe_bitcast[_HookState]()


# ===----------------------------------------------------------------------=== #
# Update hook
# ===----------------------------------------------------------------------=== #
def _update_hook(op: UpdateOperation, db_name: String, table_name: String, rowid: Int64) -> NoneType:
    var state = _hook_state()
    state[].update_calls += 1
    state[].last_op = op.value
    state[].last_db = db_name
    state[].last_table = table_name
    state[].last_rowid = rowid
    return NoneType()


def test_update_hook_insert_update_delete() raises:
    var state = _hook_state()
    state[] = _HookState()

    var db = Connection.open_in_memory()
    db.register_update_hook(_update_hook)

    db.execute_batch("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)")
    _ = db.execute("INSERT INTO t (id, name) VALUES (?1, ?2)", (1, "hello"))
    assert_equal(_hook_state()[].update_calls, 1)
    assert_equal(Int(_hook_state()[].last_op), Int(UpdateOperation.INSERT.value))
    assert_equal(_hook_state()[].last_db, "main")
    assert_equal(_hook_state()[].last_table, "t")
    assert_equal(_hook_state()[].last_rowid, Int64(1))

    _ = db.execute("UPDATE t SET name = ?1 WHERE id = ?2", ("world", 1))
    assert_equal(_hook_state()[].update_calls, 2)
    assert_equal(Int(_hook_state()[].last_op), Int(UpdateOperation.UPDATE.value))

    _ = db.execute("DELETE FROM t WHERE id = ?1", (1,))
    assert_equal(_hook_state()[].update_calls, 3)
    assert_equal(Int(_hook_state()[].last_op), Int(UpdateOperation.DELETE.value))

    db.clear_update_hook()
    _ = db.execute("INSERT INTO t (id, name) VALUES (?1, ?2)", (2, "again"))
    # Should not have fired after clearing.
    assert_equal(_hook_state()[].update_calls, 3)


# ===----------------------------------------------------------------------=== #
# Commit hook
# ===----------------------------------------------------------------------=== #
def _commit_hook_allow() -> Bool:
    var state = _hook_state()
    state[].commit_calls += 1
    return False


def _commit_hook_veto() -> Bool:
    var state = _hook_state()
    state[].commit_calls += 1
    return True


def test_commit_hook_allows_commit() raises:
    var state = _hook_state()
    state[] = _HookState()

    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER)")

    # Register only after the (autocommit) CREATE TABLE, so we count only
    # the explicit COMMIT below.
    db.register_commit_hook(_commit_hook_allow)

    db.execute_batch("BEGIN")
    _ = db.execute("INSERT INTO t (id) VALUES (?1)", (1,))
    db.execute_batch("COMMIT")

    assert_equal(_hook_state()[].commit_calls, 1)

    var count = db.one_row[_get_count]("SELECT COUNT(*) FROM t")
    assert_equal(count, 1)

    db.clear_commit_hook()


def test_commit_hook_veto_rolls_back() raises:
    var state = _hook_state()
    state[] = _HookState()

    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER)")

    # Register only after the (autocommit) CREATE TABLE, so we count only
    # the explicit COMMIT below.
    db.register_commit_hook(_commit_hook_veto)

    db.execute_batch("BEGIN")
    _ = db.execute("INSERT INTO t (id) VALUES (?1)", (1,))

    # Committing should be converted into a rollback because the hook vetoes.
    with assert_raises():
        db.execute_batch("COMMIT")

    assert_equal(_hook_state()[].commit_calls, 1)

    # Data should not be visible since the commit was converted to rollback.
    var count = db.one_row[_get_count]("SELECT COUNT(*) FROM t")
    assert_equal(count, 0)

    db.clear_commit_hook()


# ===----------------------------------------------------------------------=== #
# Rollback hook
# ===----------------------------------------------------------------------=== #
def _rollback_hook() -> NoneType:
    var state = _hook_state()
    state[].rollback_calls += 1
    return NoneType()


def test_rollback_hook_fires_on_rollback() raises:
    var state = _hook_state()
    state[] = _HookState()

    var db = Connection.open_in_memory()
    db.register_rollback_hook(_rollback_hook)

    db.execute_batch("CREATE TABLE t (id INTEGER)")
    db.execute_batch("BEGIN")
    _ = db.execute("INSERT INTO t (id) VALUES (?1)", (1,))
    db.execute_batch("ROLLBACK")

    assert_equal(_hook_state()[].rollback_calls, 1)

    var count = db.one_row[_get_count]("SELECT COUNT(*) FROM t")
    assert_equal(count, 0)

    db.clear_rollback_hook()


# ===----------------------------------------------------------------------=== #
# Clearing hooks fully unregisters them
#
# `clear_*` passes a NULL `xCallback` so SQLite unregisters the hook entirely,
# rather than leaving an inert trampoline registered. After clearing, none of
# the hooks should fire for any subsequent commit, rollback, or row change.
# ===----------------------------------------------------------------------=== #
def test_hooks_stop_firing_after_clear() raises:
    var state = _hook_state()
    state[] = _HookState()

    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER)")

    db.register_commit_hook(_commit_hook_allow)
    db.register_rollback_hook(_rollback_hook)
    db.register_update_hook(_update_hook)

    db.clear_commit_hook()
    db.clear_rollback_hook()
    db.clear_update_hook()

    # A full commit cycle plus a rollback, none of which should invoke a hook.
    db.execute_batch("BEGIN")
    _ = db.execute("INSERT INTO t (id) VALUES (?1)", (1,))
    db.execute_batch("COMMIT")

    db.execute_batch("BEGIN")
    _ = db.execute("INSERT INTO t (id) VALUES (?1)", (2,))
    db.execute_batch("ROLLBACK")

    assert_equal(_hook_state()[].commit_calls, 0)
    assert_equal(_hook_state()[].rollback_calls, 0)
    assert_equal(_hook_state()[].update_calls, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
