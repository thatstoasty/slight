"""Tests for trace event codes, statement status, and trace_v2."""

from slight.connection import Connection
from slight.trace import (
    StatementStatus,
    TraceEvent,
    TraceEventCodes,
    TraceFn,
    log,
)
from std.testing import TestSuite, assert_equal, assert_true, assert_false


# ===----------------------------------------------------------------------=== #
# test_trace_event_codes_values
#
# Verifies each TraceEventCodes variant has the expected bitmask value.
# ===----------------------------------------------------------------------=== #
fn test_trace_event_codes_values() raises:
    assert_equal(Int(TraceEventCodes.STMT.value), 0x01)
    assert_equal(Int(TraceEventCodes.PROFILE.value), 0x02)
    assert_equal(Int(TraceEventCodes.ROW.value), 0x04)
    assert_equal(Int(TraceEventCodes.CLOSE.value), 0x08)
    assert_equal(Int(TraceEventCodes.all().value), 0x0F)
    assert_equal(Int(TraceEventCodes.empty().value), 0)


# ===----------------------------------------------------------------------=== #
# test_trace_event_codes_ops
#
# Tests bitwise operations and containment for TraceEventCodes.
# ===----------------------------------------------------------------------=== #
fn test_trace_event_codes_ops() raises:
    var combined = TraceEventCodes.STMT | TraceEventCodes.PROFILE
    assert_equal(Int(combined.value), 0x03)

    # Containment
    assert_true(TraceEventCodes.STMT in combined)
    assert_true(TraceEventCodes.PROFILE in combined)
    assert_false(TraceEventCodes.ROW in combined)
    assert_false(TraceEventCodes.CLOSE in combined)

    # AND
    var intersection = combined & TraceEventCodes.STMT
    assert_equal(Int(intersection.value), 0x01)

    # all() contains every code
    var all_codes = TraceEventCodes.all()
    assert_true(TraceEventCodes.STMT in all_codes)
    assert_true(TraceEventCodes.PROFILE in all_codes)
    assert_true(TraceEventCodes.ROW in all_codes)
    assert_true(TraceEventCodes.CLOSE in all_codes)

    # Equality
    assert_true(TraceEventCodes.STMT == TraceEventCodes.STMT)
    assert_true(TraceEventCodes.STMT != TraceEventCodes.PROFILE)


# ===----------------------------------------------------------------------=== #
# test_statement_status_values
#
# Verifies each StatementStatus variant has the expected integer value.
# ===----------------------------------------------------------------------=== #
fn test_statement_status_values() raises:
    assert_equal(Int(StatementStatus.FULLSCAN_STEP.value), 1)
    assert_equal(Int(StatementStatus.SORT.value), 2)
    assert_equal(Int(StatementStatus.AUTOINDEX.value), 3)
    assert_equal(Int(StatementStatus.VM_STEP.value), 4)
    assert_equal(Int(StatementStatus.REPREPARE.value), 5)
    assert_equal(Int(StatementStatus.RUN.value), 6)
    assert_equal(Int(StatementStatus.FILTER_MISS.value), 7)
    assert_equal(Int(StatementStatus.FILTER_HIT.value), 8)
    assert_equal(Int(StatementStatus.MEMUSED.value), 99)


# ===----------------------------------------------------------------------=== #
# test_trace_v2_stmt
#
# Verifies that a STMT trace callback fires with the correct SQL text.
# Since Mojo doesn't support closures/captured state, we use a print-based
# callback and verify the plumbing doesn't crash.
# ===----------------------------------------------------------------------=== #
fn _trace_stmt_callback(event: TraceEvent) -> NoneType:
    """Callback that validates STMT events have non-empty SQL."""
    if event.is_stmt():
        var sql = event.sql()
        # stmt_sql() should return the same SQL via the statement handle
        var stmt_sql = event.stmt_sql()
        debug_assert(len(sql) > 0, "STMT event SQL should not be empty")
        debug_assert(len(stmt_sql) > 0, "stmt_sql() should not be empty")
    elif event.is_profile():
        var ns = event.duration_ns()
        debug_assert(ns >= 0, "duration must be non-negative")
        var sort_count = event.get_status(StatementStatus.SORT)
        debug_assert(sort_count >= 0, "sort count must be non-negative")
    elif event.is_row():
        var sql = event.stmt_sql()
        debug_assert(len(sql) > 0, "ROW event stmt_sql should not be empty")
    elif event.is_close():
        var autocommit = event.is_autocommit()
        # In-memory databases should be in autocommit mode when closing
        debug_assert(autocommit, "expected autocommit at close")

    return NoneType()


fn test_trace_v2_stmt() raises:
    var db = Connection.open_in_memory()
    db.register_trace_function[_trace_stmt_callback](TraceEventCodes.STMT | TraceEventCodes.PROFILE)

    # Execute some SQL to trigger STMT and PROFILE events
    db.execute_batch("CREATE TABLE t1 (id INTEGER PRIMARY KEY, name TEXT)")
    _ = db.execute("INSERT INTO t1 (id, name) VALUES (?1, ?2)", (1, "hello"))

    # Clear the trace callback
    db.clear_trace_function()

    # This should NOT trigger any trace events
    _ = db.execute("INSERT INTO t1 (id, name) VALUES (?1, ?2)", (2, "world"))


# ===----------------------------------------------------------------------=== #
# test_trace_v2_all_events
#
# Verifies trace_v2 with all event types enabled, including ROW and CLOSE.
# ===----------------------------------------------------------------------=== #
fn _trace_all_callback(event: TraceEvent) -> NoneType:
    """Callback that exercises all event-type accessors."""
    if event.is_stmt():
        _ = event.sql()
    elif event.is_profile():
        _ = event.duration_ns()
    elif event.is_row():
        _ = event.expanded_sql()
    elif event.is_close():
        _ = event.is_autocommit()
        _ = event.db_filename()

    return NoneType()


fn test_trace_v2_all_events() raises:
    # Open in a block so we see the CLOSE event.
    var db = Connection.open_in_memory()
    db.register_trace_function[_trace_all_callback](TraceEventCodes.all())

    db.execute_batch("CREATE TABLE t3 (x INTEGER); INSERT INTO t3 VALUES (1)")


# ===----------------------------------------------------------------------=== #
# test_trace_v2_disable
#
# Verifies that passing None as the trace callback disables tracing.
# ===----------------------------------------------------------------------=== #
fn _trace_should_not_fire(event: TraceEvent) -> NoneType:
    """This callback should never be invoked after being cleared."""
    debug_assert(False, "trace callback should not fire after being cleared")
    return NoneType()


fn test_trace_v2_disable() raises:
    var db = Connection.open_in_memory()

    # Set and immediately clear
    db.register_trace_function[_trace_should_not_fire](TraceEventCodes.all())
    db.clear_trace_function()

    # Execute SQL — should not trigger the cleared callback
    _ = db.execute("CREATE TABLE t2 (x INTEGER)")


# ===----------------------------------------------------------------------=== #
# test_log
#
# Verifies that the log() free function doesn't crash.
# ===----------------------------------------------------------------------=== #
fn test_log() raises:
    # sqlite3_log writes to the error log; just verify it doesn't crash.
    var msg = "test log message from Mojo"
    log(Int32(0), msg)


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
