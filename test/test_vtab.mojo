from std.ffi import c_int, c_uchar
from slight.connection import Connection
from slight.c.types import (
    ImmutExternalOrigin,
    MutExternalPointer,
    _sqlite3_index_info_sqlite3_index_constraint_usage,
    sqlite3_connection,
    sqlite3_index_info,
    sqlite3_value,
)
from slight.api import sqlite_ffi
from slight.context import Context
from slight.vtab import (
    VTabConnectFn,
    VTabConnectResult,
    VTabBestIndexFn,
    VTabOpenFn,
    VTabFilterFn,
    VTabNextFn,
    VTabEofFn,
    VTabColumnFn,
    VTabRowidFn,
)
from std.testing import TestSuite, assert_equal


# ===----------------------------------------------------------------------=== #
# generate_series virtual table
#
# Registers an eponymous table-valued function:
#   SELECT value FROM generate_series(start, stop[, step])
#
# State  : GenerateSeriesVTab  — holds start / stop / step from xConnect
# Cursor : GenerateSeriesCursor — holds the current value
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct GenerateSeriesVTab(Movable):
    var start: Int64
    var stop: Int64
    var step: Int64


@fieldwise_init
struct GenerateSeriesCursor(Movable):
    var current: Int64
    var start: Int64
    var stop: Int64
    var step: Int64
    var done: Bool


# ---- xConnect / xCreate --------------------------------------------------

def gs_connect(
    db: MutExternalPointer[sqlite3_connection],
    argv: List[String],
) raises -> VTabConnectResult[GenerateSeriesVTab]:
    """Parse (start, stop, step) from module argv and declare the schema."""
    # argv[0] = module name, argv[1] = database name, argv[2+] = user args
    var start: Int64 = 1
    var stop: Int64 = 0
    var step: Int64 = 1
    if len(argv) > 2:
        try:
            start = Int64(atol(argv[2]))
        except:
            pass
    if len(argv) > 3:
        try:
            stop = Int64(atol(argv[3]))
        except:
            pass
    if len(argv) > 4:
        try:
            step = Int64(atol(argv[4]))
        except:
            pass
    var schema = String(
        "CREATE TABLE x(value INTEGER, start INTEGER HIDDEN, stop INTEGER HIDDEN, step INTEGER HIDDEN)"
    )
    return VTabConnectResult[GenerateSeriesVTab](
        schema=schema^,
        vtab=GenerateSeriesVTab(start=start, stop=stop, step=step),
    )


# ---- xBestIndex ----------------------------------------------------------

def gs_best_index(
    vtab: MutExternalPointer[GenerateSeriesVTab],
    index_info: MutExternalPointer[sqlite3_index_info],
) raises -> Bool:
    """Pass SQLITE_INDEX_CONSTRAINT_EQ on hidden cols 1,2,3 to xFilter.

    Assigns fixed argv indices: start→1, stop→2, step→3 so that xFilter
    always receives them in a consistent order.
    """
    var n = Int(index_info[].nConstraint)
    for i in range(n):
        if index_info[].aConstraint[i].usable == c_uchar(0):
            continue
        var col = Int(index_info[].aConstraint[i].iColumn)
        if col == 1:  # start
            index_info[].aConstraintUsage[i].argvIndex = c_int(1)
            index_info[].aConstraintUsage[i].omit = c_uchar(1)
        elif col == 2:  # stop
            index_info[].aConstraintUsage[i].argvIndex = c_int(2)
            index_info[].aConstraintUsage[i].omit = c_uchar(1)
        elif col == 3:  # step
            index_info[].aConstraintUsage[i].argvIndex = c_int(3)
            index_info[].aConstraintUsage[i].omit = c_uchar(1)
    return False


# ---- xOpen ---------------------------------------------------------------

def gs_open(vtab: MutExternalPointer[GenerateSeriesVTab]) raises -> GenerateSeriesCursor:
    """Create an initial cursor; xFilter sets the actual start position."""
    return GenerateSeriesCursor(
        current=0, start=0, stop=0, step=1, done=True
    )


# ---- xFilter -------------------------------------------------------------

def gs_filter(
    cursor: MutExternalPointer[GenerateSeriesCursor],
    idx_num: c_int,
    idx_str: Optional[StringSlice[ImmutExternalOrigin]],
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    argc: c_int,
) raises:
    """Set current = start; mark done if start > stop."""
    # For table-valued function usage the hidden column constraints pass
    # start, stop, step as argv[0], argv[1], argv[2].
    var start: Int64 = cursor[].start
    var stop: Int64 = cursor[].stop
    var step: Int64 = cursor[].step
    if argc > 0:
        start = sqlite_ffi()[].value_int64(argv[0])
    if argc > 1:
        stop = sqlite_ffi()[].value_int64(argv[1])
    if argc > 2:
        step = sqlite_ffi()[].value_int64(argv[2])
    if step <= 0:
        step = 1
    cursor[].start = start
    cursor[].stop = stop
    cursor[].step = step
    cursor[].current = start
    cursor[].done = start > stop


# ---- xNext ---------------------------------------------------------------

def gs_next(cursor: MutExternalPointer[GenerateSeriesCursor]) raises:
    cursor[].current += cursor[].step
    cursor[].done = cursor[].current > cursor[].stop


# ---- xEof ----------------------------------------------------------------

def gs_eof(cursor: MutExternalPointer[GenerateSeriesCursor]) -> Bool:
    return cursor[].done


# ---- xColumn -------------------------------------------------------------

def gs_column(
    cursor: MutExternalPointer[GenerateSeriesCursor],
    ctx: Context,
    col: c_int,
) raises:
    """Return the current value (column 0)."""
    if col == 0:
        ctx.result_int64(cursor[].current)


# ---- xRowid --------------------------------------------------------------

def gs_rowid(cursor: MutExternalPointer[GenerateSeriesCursor]) raises -> Int64:
    return cursor[].current


# ===----------------------------------------------------------------------=== #
# Tests
# ===----------------------------------------------------------------------=== #


def test_generate_series_basic() raises:
    """Query generate_series(1, 5, 1) and expect values 1–5."""
    var conn = Connection.open_in_memory()
    conn.create_module[
        GenerateSeriesVTab,
        GenerateSeriesCursor,
        gs_connect,
        gs_best_index,
        gs_open,
        gs_filter,
        gs_next,
        gs_eof,
        gs_column,
        gs_rowid,
    ]("generate_series")

    var expected = List[Int64]()
    expected.append(1)
    expected.append(2)
    expected.append(3)
    expected.append(4)
    expected.append(5)
    var idx = 0
    var stmt = conn.prepare(
        "SELECT value FROM generate_series(1, 5, 1) ORDER BY value"
    )
    for row in stmt.query():
        var val = row.get[Int64](0)
        assert_equal(val, expected[idx])
        idx += 1
    assert_equal(idx, 5)


def test_generate_series_step() raises:
    """Query generate_series(0, 10, 2) and expect even numbers 0–10."""
    var conn = Connection.open_in_memory()
    conn.create_module[
        GenerateSeriesVTab,
        GenerateSeriesCursor,
        gs_connect,
        gs_best_index,
        gs_open,
        gs_filter,
        gs_next,
        gs_eof,
        gs_column,
        gs_rowid,
    ]("generate_series")

    var expected = List[Int64]()
    expected.append(0)
    expected.append(2)
    expected.append(4)
    expected.append(6)
    expected.append(8)
    expected.append(10)
    var idx = 0
    var stmt = conn.prepare(
        "SELECT value FROM generate_series(0, 10, 2) ORDER BY value"
    )
    for row in stmt.query():
        assert_equal(row.get[Int64](0), expected[idx])
        idx += 1
    assert_equal(idx, 6)


def test_generate_series_empty() raises:
    """Query generate_series(5, 1, 1) — start > stop — expect no rows."""
    var conn = Connection.open_in_memory()
    conn.create_module[
        GenerateSeriesVTab,
        GenerateSeriesCursor,
        gs_connect,
        gs_best_index,
        gs_open,
        gs_filter,
        gs_next,
        gs_eof,
        gs_column,
        gs_rowid,
    ]("generate_series")

    var count = 0
    var stmt = conn.prepare("SELECT value FROM generate_series(5, 1, 1)")
    for _ in stmt.query():
        count += 1
    assert_equal(count, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
