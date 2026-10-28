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
def test_limit_values() raises:
    assert_equal(Int(Limit.length.code()), 0)
    assert_equal(Int(Limit.sql_length.code()), 1)
    assert_equal(Int(Limit.column.code()), 2)
    assert_equal(Int(Limit.expr_depth.code()), 3)
    assert_equal(Int(Limit.compound_select.code()), 4)
    assert_equal(Int(Limit.vdbe_op.code()), 5)
    assert_equal(Int(Limit.function_arg.code()), 6)
    assert_equal(Int(Limit.attached.code()), 7)
    assert_equal(Int(Limit.like_pattern_length.code()), 8)
    assert_equal(Int(Limit.variable_number.code()), 9)
    assert_equal(Int(Limit.trigger_depth.code()), 10)
    assert_equal(Int(Limit.worker_threads.code()), 11)


# ===----------------------------------------------------------------------=== #
# Rust: test_limit
#
# Tests set_limit and limit round-trip for each limit category, plus
# error cases for negative values and invalid limit categories.
# ===----------------------------------------------------------------------=== #
def test_limit() raises:
    var db = Connection.open_in_memory()

    _ = db.set_limit(Limit.length, 1024)
    assert_equal(db.limit(Limit.length), 1024)

    _ = db.set_limit(Limit.sql_length, 1024)
    assert_equal(db.limit(Limit.sql_length), 1024)

    _ = db.set_limit(Limit.column, 64)
    assert_equal(db.limit(Limit.column), 64)

    _ = db.set_limit(Limit.expr_depth, 256)
    assert_equal(db.limit(Limit.expr_depth), 256)

    _ = db.set_limit(Limit.compound_select, 32)
    assert_equal(db.limit(Limit.compound_select), 32)

    _ = db.set_limit(Limit.function_arg, 32)
    assert_equal(db.limit(Limit.function_arg), 32)

    _ = db.set_limit(Limit.attached, 2)
    assert_equal(db.limit(Limit.attached), 2)

    _ = db.set_limit(Limit.like_pattern_length, 128)
    assert_equal(db.limit(Limit.like_pattern_length), 128)

    _ = db.set_limit(Limit.variable_number, 99)
    assert_equal(db.limit(Limit.variable_number), 99)

    _ = db.set_limit(Limit.trigger_depth, 32)
    assert_equal(db.limit(Limit.trigger_depth), 32)

    _ = db.set_limit(Limit.worker_threads, 2)
    assert_equal(db.limit(Limit.worker_threads), 2)

    # Error: negative new_val
    with assert_raises():
        _ = db.set_limit(Limit.worker_threads, -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
