"""Test generate_series with CREATE VIRTUAL TABLE (not table-valued function)."""
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
from slight.vtab.vtab import (
    VTabConnectFn,
    VTabConnectResult,
    VTabBestIndexFn,
    VTabOpenFn,
    VTabFilterFn,
    VTabNextFn,
    VTabEofFn,
    VTabColumnFn,
    VTabRowidFn,
    VTabConnection,
)


@fieldwise_init
struct SimpleVTab(Movable):
    var n: Int
    var name: String
    var items: List[String]
    var matrix: List[List[String]]
    var b: Bool
    var u1: UInt8
    var u2: UInt8


@fieldwise_init
struct SimpleCursor(Movable):
    var current: Int
    var n: Int
    var done: Bool


def simple_connect(
    db: VTabConnection,
    aux: MutExternalPointer[NoneType],
    module_name: String,
    database_name: String,
    table_name: String,
    argv: Span[String, ...],
) raises -> VTabConnectResult[SimpleVTab]:
    print("simple_connect called")
    var items = List[String]()
    items.append("hello")
    var matrix = List[List[String]]()
    var row = List[String]()
    row.append("a")
    row.append("b")
    matrix.append(row^)
    return VTabConnectResult[SimpleVTab](
        schema="CREATE TABLE x(value INTEGER)",
        vtab=SimpleVTab(n=5, name="test", items=items^, matrix=matrix^, b=True, u1=UInt8(44), u2=UInt8(34)),
    )


def simple_best_index(
    vtab: MutExternalPointer[SimpleVTab],
    index_info: MutExternalPointer[sqlite3_index_info],
) raises -> Bool:
    print("simple_best_index called!")
    return False


def simple_open(vtab: MutExternalPointer[SimpleVTab]) raises -> SimpleCursor:
    return SimpleCursor(current=1, n=vtab[].n, done=False)


def simple_filter(
    cursor: MutExternalPointer[SimpleCursor],
    idx_num: c_int,
    idx_str: Optional[StringSlice[ImmutExternalOrigin]],
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    argc: c_int,
) raises:
    cursor[].current = 1
    cursor[].done = cursor[].n == 0


def simple_next(cursor: MutExternalPointer[SimpleCursor]) raises:
    cursor[].current += 1
    cursor[].done = cursor[].current > cursor[].n


def simple_eof(cursor: MutExternalPointer[SimpleCursor]) -> Bool:
    return cursor[].done


def simple_column(
    cursor: MutExternalPointer[SimpleCursor],
    ctx: Context,
    col: c_int,
) raises:
    ctx.result_int64(Int64(cursor[].current))


def simple_rowid(cursor: MutExternalPointer[SimpleCursor]) raises -> Int64:
    return Int64(cursor[].current)


def main() raises:
    var conn = Connection.open_in_memory()
    conn.create_module[
        SimpleVTab,
        SimpleCursor,
        simple_connect,
        simple_best_index,
        simple_open,
        simple_filter,
        simple_next,
        simple_eof,
        simple_column,
        simple_rowid,
    ]("simple")
    print("Module registered OK")
    conn.execute_batch("CREATE VIRTUAL TABLE vtab USING simple(filename='x.csv', header=yes)")
    print("CREATE VIRTUAL TABLE OK")
    var stmt = conn.prepare("SELECT * FROM vtab LIMIT 3")
    print("prepare OK")
    for row in stmt.query():
        print("row:", row.get[Int](0))
