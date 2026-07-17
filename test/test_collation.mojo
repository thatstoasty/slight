"""Tests for custom collating sequences."""

from slight.connection import Connection
from slight.row import Row
from std.testing import TestSuite, assert_equal, assert_raises


def _get_text(row: Row) raises -> String:
    return row.get[String](0)


# ===----------------------------------------------------------------------=== #
# Reversed collation: orders strings by comparing them back-to-front,
# giving a different order than the default BINARY collation for this data.
# ===----------------------------------------------------------------------=== #
def _reverse_compare(left: Span[Byte, ImmutUntrackedOrigin], right: Span[Byte, ImmutUntrackedOrigin]) -> Int:
    var n_left = len(left)
    var n_right = len(right)
    var n = min(n_left, n_right)
    for i in range(n):
        var l = left[n_left - 1 - i]
        var r = right[n_right - 1 - i]
        if l < r:
            return -1
        if l > r:
            return 1
    if n_left < n_right:
        return -1
    if n_left > n_right:
        return 1
    return 0


def test_create_collation_changes_order() raises:
    var db = Connection.open_in_memory()
    db.create_collation("REVERSE", _reverse_compare)

    db.execute_batch("CREATE TABLE t (x TEXT)")
    _ = db.execute("INSERT INTO t (x) VALUES (?1)", ("aaz",))
    _ = db.execute("INSERT INTO t (x) VALUES (?1)", ("aby",))
    _ = db.execute("INSERT INTO t (x) VALUES (?1)", ("aax",))

    # Default (binary) order: aax, aaz, aby
    var default_order = List[String]()
    var stmt1 = db.prepare("SELECT x FROM t ORDER BY x")
    for row in stmt1.query():
        default_order.append(row.get[String](0))
    assert_equal(default_order[0], "aax")
    assert_equal(default_order[1], "aaz")
    assert_equal(default_order[2], "aby")

    # Reversed-comparison order: sorted by last character (x < y < z):
    # aax, aby, aaz
    var reverse_order = List[String]()
    var stmt2 = db.prepare("SELECT x FROM t ORDER BY x COLLATE REVERSE")
    for row in stmt2.query():
        reverse_order.append(row.get[String](0))
    assert_equal(reverse_order[0], "aax")
    assert_equal(reverse_order[1], "aby")
    assert_equal(reverse_order[2], "aaz")

    # Sanity: the two orderings actually differ.
    assert_equal(default_order[1] == reverse_order[1], False)


def test_remove_collation() raises:
    var db = Connection.open_in_memory()
    db.create_collation("REVERSE", _reverse_compare)
    db.execute_batch("CREATE TABLE t (x TEXT)")
    _ = db.execute("INSERT INTO t (x) VALUES (?1)", ("a",))

    # Sanity: works while registered.
    _ = db.one_row[_get_text]("SELECT x FROM t ORDER BY x COLLATE REVERSE")

    db.remove_collation("REVERSE")

    # After removal, referencing the collation should fail.
    with assert_raises():
        _ = db.prepare("SELECT x FROM t ORDER BY x COLLATE REVERSE")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
