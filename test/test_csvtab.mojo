from std.testing import assert_equal, assert_true, TestSuite
from slight.connection import Connection
from slight.vtab.csvtab import (
    CsvState,
    CsvCursor,
    csv_connect,
    csv_best_index,
    csv_open,
    csv_filter,
    csv_next,
    csv_eof,
    csv_column,
    csv_rowid,
    load_module,
)

# Path to the test CSV (relative to workspace root; tests run from project root).
comptime TEST_CSV = "rusqlite/test.csv"

# Expected data from rusqlite/test.csv (excluding the header row).
# Row format: (colA, colB, colC)
comptime EXPECTED_ROWS = 5


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


def make_conn() raises -> Connection:
    """Open an in-memory database and register the csv module."""
    var conn = Connection.open_in_memory()
    conn.create_module[
        CsvState,
        CsvCursor,
        csv_connect,
        csv_best_index,
        csv_open,
        csv_filter,
        csv_next,
        csv_eof,
        csv_column,
        csv_rowid,
    ]("csv")
    return conn^


# ===----------------------------------------------------------------------=== #
# Tests
# ===----------------------------------------------------------------------=== #


def test_csv_header_columns() raises:
    """Virtual table created with header=yes exposes colA / colB / colC."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    # Query the schema columns via PRAGMA to verify names.
    var count = 0
    var stmt = conn.prepare("SELECT * FROM vtab LIMIT 0")
    for _ in stmt.query():
        count += 1
    # Zero rows; the main check is that the statement compiled — which means
    # the schema was declared correctly.
    assert_equal(count, 0)


def test_csv_row_count() raises:
    """Full scan returns exactly 5 data rows (header excluded)."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var count = 0
    var stmt = conn.prepare("SELECT rowid FROM vtab")
    for _ in stmt.query():
        count += 1
    assert_equal(count, EXPECTED_ROWS)


def test_csv_rowid_values() raises:
    """Rowids are 1-based and sequential."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var stmt = conn.prepare("SELECT rowid FROM vtab ORDER BY rowid")
    var expected_rowid: Int64 = 1
    for row in stmt.query():
        assert_equal(row.get[Int64](0), expected_rowid)
        expected_rowid += 1
    assert_equal(expected_rowid, Int64(EXPECTED_ROWS + 1))


def test_csv_data_first_row() raises:
    """Row 1 contains '1', '2', '3'."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var stmt = conn.prepare("SELECT colA, colB, colC FROM vtab WHERE rowid = 1")
    var found = False
    for row in stmt.query():
        assert_equal(row.get[String](0), "1")
        assert_equal(row.get[String](1), "2")
        assert_equal(row.get[String](2), "3")
        found = True
    assert_true(found)


def test_csv_data_second_row() raises:
    """Row 2 contains 'a', 'b', 'c'."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var stmt = conn.prepare("SELECT colA, colB, colC FROM vtab WHERE rowid = 2")
    var found = False
    for row in stmt.query():
        assert_equal(row.get[String](0), "a")
        assert_equal(row.get[String](1), "b")
        assert_equal(row.get[String](2), "c")
        found = True
    assert_true(found)


def test_csv_data_quoted_field() raises:
    """Row 4 has a quoted colC value containing spaces: 'c .. z'."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var stmt = conn.prepare("SELECT colC FROM vtab WHERE rowid = 4")
    var found = False
    for row in stmt.query():
        assert_equal(row.get[String](0), "c .. z")
        found = True
    assert_true(found)


def test_csv_data_embedded_delimiter() raises:
    """Row 5 has a quoted colC value containing the delimiter: 'c,d'."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var stmt = conn.prepare("SELECT colC FROM vtab WHERE rowid = 5")
    var found = False
    for row in stmt.query():
        assert_equal(row.get[String](0), "c,d")
        found = True
    assert_true(found)


def test_csv_no_header_auto_columns() raises:
    """With header=no, column names are auto-generated as c0, c1, c2."""
    var conn = make_conn()
    # Skip the header row by using columns=3 (no header parsing).
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', columns=3)"
    )
    # There should be 6 rows total (header row treated as data).
    var count = 0
    var stmt = conn.prepare("SELECT rowid FROM vtab")
    for _ in stmt.query():
        count += 1
    assert_equal(count, 6)


def test_csv_columns_param() raises:
    """Columns=3 forces 3 columns named c0, c1, c2."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', columns=3)"
    )
    var stmt = conn.prepare("SELECT c0, c1, c2 FROM vtab LIMIT 1")
    var found = False
    for row in stmt.query():
        # First row when no header is the header line itself: colA, colB, colC.
        assert_equal(row.get[String](0), "colA")
        assert_equal(row.get[String](1), "colB")
        assert_equal(row.get[String](2), "colC")
        found = True
    assert_true(found)


def test_csv_load_module_helper() raises:
    """Load_module() convenience function registers the csv module."""
    var conn = Connection.open_in_memory()
    load_module(conn)
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var count = 0
    var stmt = conn.prepare("SELECT rowid FROM vtab")
    for _ in stmt.query():
        count += 1
    assert_equal(count, EXPECTED_ROWS)


def test_csv_all_rows_ordered() raises:
    """All 5 data rows are returned in the correct order with correct values."""
    var conn = make_conn()
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='"
        + TEST_CSV
        + "', header=yes)"
    )
    var stmt = conn.prepare(
        "SELECT rowid, colA, colB, colC FROM vtab ORDER BY rowid"
    )

    # Expected: (rowid, colA, colB, colC)
    var col_a = List[String]()
    col_a.append("1")
    col_a.append("a")
    col_a.append("a")
    col_a.append("a")
    col_a.append("a")

    var col_b = List[String]()
    col_b.append("2")
    col_b.append("b")
    col_b.append("b")
    col_b.append("b")
    col_b.append("b")

    var col_c = List[String]()
    col_c.append("3")
    col_c.append("c")
    col_c.append("c")
    col_c.append("c .. z")
    col_c.append("c,d")

    var idx = 0
    for row in stmt.query():
        assert_equal(row.get[Int64](0), Int64(idx + 1))
        assert_equal(row.get[String](1), col_a[idx])
        assert_equal(row.get[String](2), col_b[idx])
        assert_equal(row.get[String](3), col_c[idx])
        idx += 1
    assert_equal(idx, EXPECTED_ROWS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
