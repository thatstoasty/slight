"""Test generate_series with CREATE VIRTUAL TABLE."""
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
)


@fieldwise_init
struct CounterVTab(Movable):
    var n: Int
    var name: String
    var rows: List[List[String]]
    var b: Bool
    var u1: UInt8
    var u2: UInt8
    var m: Int


@fieldwise_init
struct CounterCursor(Movable):
    var current: Int
    var n: Int
    var done: Bool


def counter_connect(
    db: MutExternalPointer[sqlite3_connection],
    argv: List[String],
) raises -> VTabConnectResult[CounterVTab]:
    print("counter_connect called, argc =", len(argv))
    var n = 5
    if len(argv) > 3:
        try:
            n = atol(argv[3])
        except:
            pass
    var rows = List[List[String]]()
    var r = List[String]()
    r.append("hello")
    rows.append(r^)
    return VTabConnectResult[CounterVTab](
        schema=String("CREATE TABLE x(value INTEGER)"),
        vtab=CounterVTab(n=n, name=String("test"), rows=rows^, b=True, u1=UInt8(44), u2=UInt8(34), m=1),
    )


def counter_best_index(
    vtab: MutExternalPointer[CounterVTab],
    index_info: MutExternalPointer[sqlite3_index_info],
) raises -> Bool:
    print("counter_best_index called!")
    return False


def counter_open(vtab: MutExternalPointer[CounterVTab]) raises -> CounterCursor:
    return CounterCursor(current=1, n=vtab[].n, done=False)


def counter_filter(
    cursor: MutExternalPointer[CounterCursor],
    idx_num: c_int,
    idx_str: Optional[StringSlice[ImmutExternalOrigin]],
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    argc: c_int,
) raises:
    cursor[].current = 1
    cursor[].done = cursor[].n == 0


def counter_next(cursor: MutExternalPointer[CounterCursor]) raises:
    cursor[].current += 1
    cursor[].done = cursor[].current > cursor[].n


def counter_eof(cursor: MutExternalPointer[CounterCursor]) -> Bool:
    return cursor[].done


def counter_column(
    cursor: MutExternalPointer[CounterCursor],
    ctx: Context,
    col: c_int,
) raises:
    ctx.result_int64(Int64(cursor[].current))


def counter_rowid(cursor: MutExternalPointer[CounterCursor]) raises -> Int64:
    return Int64(cursor[].current)


def main() raises:
    var conn = Connection.open_in_memory()
    conn.create_module[
        CounterVTab,
        CounterCursor,
        counter_connect,
        counter_best_index,
        counter_open,
        counter_filter,
        counter_next,
        counter_eof,
        counter_column,
        counter_rowid,
    ]("counter")
    print("Module registered OK")
    conn.execute_batch("CREATE VIRTUAL TABLE vtab USING counter(filename='x.csv', header=yes)")
    print("CREATE VIRTUAL TABLE OK")
    var stmt = conn.prepare("SELECT * FROM vtab LIMIT 3")
    print("prepare OK")
    for row in stmt.query():
        print("row:", row.get[Int](0))
