"""Tests for Connection.serialize / Connection.deserialize."""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite

from slight import Connection, Int, Row, String


def test_serialize_returns_nonempty_buffer() raises:
    """A database with a table should serialize to a non-empty buffer."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE x AS SELECT 'data'")
    var data = db.serialize()
    assert_true(len(data) > 0)


def test_deserialize_round_trip() raises:
    """Deserializing a serialized database should reproduce its contents."""
    var src = Connection.open_in_memory()
    src.execute_batch("CREATE TABLE x AS SELECT 'data'")
    var data = src.serialize()

    var dst = Connection.open_in_memory()
    dst.deserialize(data^)

    def get_value(r: Row) raises -> String:
        return r.get[String](0)

    assert_equal(dst.one_row[get_value]("SELECT * FROM x"), "data")


def test_deserialize_allows_writes_by_default() raises:
    """A deserialized database should be writable unless read_only is set."""
    var src = Connection.open_in_memory()
    src.execute_batch("CREATE TABLE t (value INTEGER)")
    var data = src.serialize()

    var dst = Connection.open_in_memory()
    dst.deserialize(data^)
    _ = dst.execute("INSERT INTO t (value) VALUES (?1)", (1,))

    def get_count(r: Row) raises -> Int:
        return r.get[Int](0)

    assert_equal(dst.one_row[get_count]("SELECT COUNT(*) FROM t"), 1)


def test_deserialize_read_only_rejects_writes() raises:
    """A deserialized database opened with read_only=True should reject writes."""
    var src = Connection.open_in_memory()
    src.execute_batch("CREATE TABLE t (value INTEGER)")
    var data = src.serialize()

    var dst = Connection.open_in_memory()
    dst.deserialize(data^, read_only=True)

    with assert_raises():
        _ = dst.execute("INSERT INTO t (value) VALUES (?1)", (1,))


def test_deserialize_empty_database() raises:
    """Deserializing an empty (no-table) database should succeed."""
    var src = Connection.open_in_memory()
    var data = src.serialize()

    var dst = Connection.open_in_memory()
    dst.deserialize(data^)


def test_serialize_is_independent_copy() raises:
    """Mutating the source database after serializing should not affect the
    already-serialized buffer or a database deserialized from it."""
    var src = Connection.open_in_memory()
    src.execute_batch("CREATE TABLE t (value INTEGER); INSERT INTO t VALUES (1);")
    var data = src.serialize()

    _ = src.execute("INSERT INTO t (value) VALUES (?1)", (2,))

    var dst = Connection.open_in_memory()
    dst.deserialize(data^)

    def get_count(r: Row) raises -> Int:
        return r.get[Int](0)

    assert_equal(dst.one_row[get_count]("SELECT COUNT(*) FROM t"), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
