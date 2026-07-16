"""Tests for Connection.backup / Connection.backup_to."""

from std.testing import assert_equal, assert_true, TestSuite

from slight import Connection, Int, Row, String


def test_backup_to_copies_table_contents() raises:
    """`backup_to()` should copy all rows from the source into the destination."""
    var src = Connection.open_in_memory()
    src.execute_batch("CREATE TABLE t (value INTEGER)")
    _ = src.execute("INSERT INTO t (value) VALUES (?1)", (1,))
    _ = src.execute("INSERT INTO t (value) VALUES (?1)", (2,))
    _ = src.execute("INSERT INTO t (value) VALUES (?1)", (3,))

    var dst = Connection.open_in_memory()
    src.backup_to(dst)

    def get_count(r: Row) raises -> Int:
        return r.get[Int](0)

    assert_equal(dst.one_row[get_count]("SELECT COUNT(*) FROM t"), 3)


def test_backup_incremental_step() raises:
    """The incremental Backup handle should copy pages a few at a time until done."""
    var src = Connection.open_in_memory()
    src.execute_batch("CREATE TABLE t (value TEXT)")
    for i in range(200):
        _ = src.execute("INSERT INTO t (value) VALUES (?1)", (String("row-") + String(i),))

    var dst = Connection.open_in_memory()
    var backup = src.backup(dst)

    var steps = 0
    try:
        while backup.step(1):
            steps += 1
            # Guard against runaway loops if step() never finishes.
            assert_true(steps < 100000)
    finally:
        backup^.finish()

    def get_count(r: Row) raises -> Int:
        return r.get[Int](0)

    assert_equal(dst.one_row[get_count]("SELECT COUNT(*) FROM t"), 200)
    assert_true(steps > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
