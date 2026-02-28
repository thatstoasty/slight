"""Tests for run-time limits."""

from slight.connection import Connection
from slight.limits import Limit
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


# ===----------------------------------------------------------------------=== #
# Rust: test_limit_values
#
# Verifies each Limit variant has the expected integer value matching the
# SQLITE_LIMIT_* constants.
# ===----------------------------------------------------------------------=== #
fn test_limit_values() raises:
    assert_equal(Int(Limit.LENGTH.value), 0)
    assert_equal(Int(Limit.SQL_LENGTH.value), 1)
    assert_equal(Int(Limit.COLUMN.value), 2)
    assert_equal(Int(Limit.EXPR_DEPTH.value), 3)
    assert_equal(Int(Limit.COMPOUND_SELECT.value), 4)
    assert_equal(Int(Limit.VDBE_OP.value), 5)
    assert_equal(Int(Limit.FUNCTION_ARG.value), 6)
    assert_equal(Int(Limit.ATTACHED.value), 7)
    assert_equal(Int(Limit.LIKE_PATTERN_LENGTH.value), 8)
    assert_equal(Int(Limit.VARIABLE_NUMBER.value), 9)
    assert_equal(Int(Limit.TRIGGER_DEPTH.value), 10)
    assert_equal(Int(Limit.WORKER_THREADS.value), 11)


# ===----------------------------------------------------------------------=== #
# Rust: test_limit
#
# Tests set_limit and limit round-trip for each limit category, plus
# error cases for negative values and invalid limit categories.
# ===----------------------------------------------------------------------=== #
fn test_limit() raises:
    var db = Connection.open_in_memory()

    _ = db.set_limit(Limit.LENGTH, 1024)
    assert_equal(db.limit(Limit.LENGTH), 1024)

    _ = db.set_limit(Limit.SQL_LENGTH, 1024)
    assert_equal(db.limit(Limit.SQL_LENGTH), 1024)

    _ = db.set_limit(Limit.COLUMN, 64)
    assert_equal(db.limit(Limit.COLUMN), 64)

    _ = db.set_limit(Limit.EXPR_DEPTH, 256)
    assert_equal(db.limit(Limit.EXPR_DEPTH), 256)

    _ = db.set_limit(Limit.COMPOUND_SELECT, 32)
    assert_equal(db.limit(Limit.COMPOUND_SELECT), 32)

    _ = db.set_limit(Limit.FUNCTION_ARG, 32)
    assert_equal(db.limit(Limit.FUNCTION_ARG), 32)

    _ = db.set_limit(Limit.ATTACHED, 2)
    assert_equal(db.limit(Limit.ATTACHED), 2)

    _ = db.set_limit(Limit.LIKE_PATTERN_LENGTH, 128)
    assert_equal(db.limit(Limit.LIKE_PATTERN_LENGTH), 128)

    _ = db.set_limit(Limit.VARIABLE_NUMBER, 99)
    assert_equal(db.limit(Limit.VARIABLE_NUMBER), 99)

    _ = db.set_limit(Limit.TRIGGER_DEPTH, 32)
    assert_equal(db.limit(Limit.TRIGGER_DEPTH), 32)

    _ = db.set_limit(Limit.WORKER_THREADS, 2)
    assert_equal(db.limit(Limit.WORKER_THREADS), 2)

    # Error: negative new_val
    with assert_raises():
        _ = db.set_limit(Limit.WORKER_THREADS, -1)

    # Error: invalid limit category
    with assert_raises():
        _ = db.set_limit(Limit(-1), 0)

    with assert_raises():
        _ = db.limit(Limit(-1))


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
