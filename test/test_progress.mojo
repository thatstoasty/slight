"""Tests for the query progress handler."""

from std.ffi import _get_global
from std.memory.alloc import unsafe_alloc
from slight.c.types import MutExternalPointer
from slight.connection import Connection
from std.testing import TestSuite, assert_raises, assert_true


struct _ProgressState:
    var calls: Int

    def __init__(out self):
        self.calls = 0


def _init_progress_state() -> Optional[MutExternalPointer[NoneType]]:
    var ptr = unsafe_alloc[_ProgressState](1)
    ptr[] = _ProgressState()
    return ptr.unsafe_bitcast[NoneType]()


def _destroy_progress_state(state: Optional[MutExternalPointer[NoneType]]):
    if state:
        state.value().unsafe_bitcast[_ProgressState]().unsafe_free()


def _progress_state() -> MutExternalPointer[_ProgressState]:
    return _get_global[
        "test_progress_state", _init_progress_state, _destroy_progress_state
    ]().value().unsafe_bitcast[_ProgressState]()


# ===----------------------------------------------------------------------=== #
# Counting handler: never interrupts, just records invocation count.
# ===----------------------------------------------------------------------=== #
def _counting_handler() -> Bool:
    _progress_state()[].calls += 1
    return False


def test_progress_handler_counts_invocations() raises:
    var state = _progress_state()
    state[] = _ProgressState()

    var db = Connection.open_in_memory()
    # Small n_ops so the handler fires frequently during the query below.
    db.register_progress_handler(1, _counting_handler)

    db.execute_batch("CREATE TABLE t (x INTEGER)")
    for i in range(200):
        _ = db.execute("INSERT INTO t (x) VALUES (?1)", (i,))

    var stmt = db.prepare("SELECT COUNT(*) FROM t WHERE x > 0")
    for row in stmt.query():
        _ = row.get[Int64](0)

    assert_true(_progress_state()[].calls > 0)

    db.clear_progress_handler()


# ===----------------------------------------------------------------------=== #
# Interrupting handler: returns True immediately, which should abort the
# running query with an error.
# ===----------------------------------------------------------------------=== #
def _interrupting_handler() -> Bool:
    _progress_state()[].calls += 1
    return True


def test_progress_handler_interrupts_query() raises:
    var state = _progress_state()
    state[] = _ProgressState()

    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (x INTEGER)")
    for i in range(200):
        _ = db.execute("INSERT INTO t (x) VALUES (?1)", (i,))

    db.register_progress_handler(1, _interrupting_handler)

    with assert_raises():
        var stmt = db.prepare("SELECT COUNT(*) FROM t WHERE x > 0")
        for row in stmt.query():
            _ = row.get[Int64](0)

    assert_true(_progress_state()[].calls > 0)

    db.clear_progress_handler()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
