"""Tests for Connection.blob_open and incremental BLOB I/O."""

from std.testing import assert_equal, assert_raises, TestSuite

from slight import Connection, Row


def test_blob_read_matches_inserted_data() raises:
    """Reading a BLOB via the incremental API should match the inserted bytes."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)")

    var original: List[Byte] = [1, 2, 3, 4, 5, 6, 7, 8]
    _ = db.execute("INSERT INTO t (id, data) VALUES (1, ?1)", [original.copy()])

    var blob = db.blob_open("t", "data", 1)
    try:
        assert_equal(len(blob), len(original))
        var read_back = blob.read(len(original))
        assert_equal(len(read_back), len(original))
        for i in range(len(original)):
            assert_equal(read_back[i], original[i])
    finally:
        blob^.close()


def test_blob_write_modifies_data() raises:
    """Writing into a BLOB via the incremental API should persist the change."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)")

    var original: List[Byte] = [0, 0, 0, 0, 0, 0, 0, 0]
    _ = db.execute("INSERT INTO t (id, data) VALUES (1, ?1)", [original.copy()])

    var blob = db.blob_open("t", "data", 1)
    var patch: List[Byte] = [9, 9, 9]
    try:
        blob.write(Span(patch), offset=2)
    finally:
        blob^.close()

    var check = db.blob_open("t", "data", 1)
    result: List[Byte]
    try:
        result = check.read(len(original))
    finally:
        check^.close()

    var expected: List[Byte] = [0, 0, 9, 9, 9, 0, 0, 0]
    assert_equal(len(result), len(expected))
    for i in range(len(expected)):
        assert_equal(result[i], expected[i])


def test_blob_write_to_read_only_fails() raises:
    """Writing to a read-only BLOB must fail.

    The public `Blob.write` is prevented at compile time by
    `where not Self.read_only`, so it cannot even be called on a
    `read_only=True` BLOB. This test verifies the complementary runtime
    guarantee: a BLOB opened with `read_only=True` is opened read-only at the
    SQLite level, so a write through the underlying handle fails with
    `SQLITE_READONLY` rather than silently succeeding.
    """
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (id INTEGER PRIMARY KEY, data BLOB)")

    var original: List[Byte] = [1, 2, 3, 4]
    _ = db.execute("INSERT INTO t (id, data) VALUES (1, ?1)", [original.copy()])

    var blob = db.blob_open[read_only=True]("t", "data", 1)
    var patch: List[Byte] = [9, 9]

    # `blob.write(...)` would not compile here; go through the underlying handle
    # to confirm SQLite itself rejects the write with SQLITE_READONLY.
    var write_failed = False
    try:
        blob.conn[].db.blob_write(blob.handle, Span(patch), 0)
    except:
        write_failed = True

    # SQLite defers the aborted-write error to close; tolerate it here since the
    # rejected write is exactly what this test asserts.
    try:
        blob^.close()
    except:
        pass

    assert_equal(write_failed, True)

    # The row must be unchanged after the rejected write.
    var check = db.blob_open("t", "data", 1)
    result: List[Byte]
    try:
        result = check.read(len(original))
    finally:
        check^.close()
    assert_equal(len(result), len(original))
    for i in range(len(original)):
        assert_equal(result[i], original[i])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
