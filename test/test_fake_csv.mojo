"""Debug test to isolate crash."""
from std.ffi import c_char, c_int
from slight.c.types import (
    ImmutExternalOrigin,
    MutExternalPointer,
    sqlite3_connection,
    sqlite3_index_info,
    sqlite3_value,
)
from slight.connection import Connection
from slight.context import Context
from slight.vtab import (
    VTabConnectResult,
    VTabBestIndexFn,
    VTabOpenFn,
    VTabFilterFn,
    VTabNextFn,
    VTabEofFn,
    VTabColumnFn,
    VTabRowidFn,
    VTabConnectFn,
)


@fieldwise_init
struct FakeState(Movable):
    var filename: String
    var has_headers: Bool
    var delimiter: UInt8
    var quote: UInt8
    var n_cols: Int
    var rows: List[List[String]]


@fieldwise_init
struct FakeCursor(Movable):
    var rows: List[List[String]]
    var row_idx: Int
    var eof: Bool


def fake_connect(
    db: MutExternalPointer[sqlite3_connection],
    argv: List[String],
) raises -> VTabConnectResult[FakeState]:
    print("fake_connect called, argc =", len(argv))
    var rows = List[List[String]]()
    var r = List[String]()
    r.append("hello")
    rows.append(r^)
    var st = FakeState(
        filename=String("test.csv"),
        has_headers=True,
        delimiter=UInt8(44),
        quote=UInt8(34),
        n_cols=1,
        rows=rows^,
    )
    return VTabConnectResult[FakeState](
        schema=String('CREATE TABLE x("col" TEXT);'),
        vtab=st^,
    )


def fake_best_index(
    vtab: MutExternalPointer[FakeState],
    index_info: MutExternalPointer[sqlite3_index_info],
) raises -> Bool:
    print("fake_best_index called!")
    return False


def fake_open(vtab: MutExternalPointer[FakeState]) raises -> FakeCursor:
    return FakeCursor(rows=vtab[].rows.copy(), row_idx=0, eof=True)


def fake_filter(
    cursor: MutExternalPointer[FakeCursor],
    idx_num: c_int,
    idx_str: Optional[StringSlice[ImmutExternalOrigin]],
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    argc: c_int,
) raises:
    cursor[].row_idx = 0
    cursor[].eof = len(cursor[].rows) == 0


def fake_next(cursor: MutExternalPointer[FakeCursor]) raises:
    cursor[].row_idx += 1
    cursor[].eof = cursor[].row_idx >= len(cursor[].rows)


def fake_eof(cursor: MutExternalPointer[FakeCursor]) -> Bool:
    return cursor[].eof


def fake_column(
    cursor: MutExternalPointer[FakeCursor],
    ctx: Context,
    col: c_int,
) raises:
    ctx.result_text(cursor[].rows[cursor[].row_idx][Int(col)])


def fake_rowid(cursor: MutExternalPointer[FakeCursor]) raises -> Int64:
    return Int64(cursor[].row_idx + 1)


def main() raises:
    var conn = Connection.open_in_memory()
    conn.create_module[
        FakeState,
        FakeCursor,
        fake_connect,
        fake_best_index,
        fake_open,
        fake_filter,
        fake_next,
        fake_eof,
        fake_column,
        fake_rowid,
    ]("fakecsv")
    print("Module registered OK")
    conn.execute_batch("CREATE VIRTUAL TABLE vtab USING fakecsv(filename='x.csv', header=yes)")
    print("CREATE VIRTUAL TABLE OK")
    var stmt = conn.prepare("SELECT * FROM vtab")
    print("prepare OK")
    for row in stmt.query():
        print("row:", row.get[String](0))
