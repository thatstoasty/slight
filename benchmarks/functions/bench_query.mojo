"""Benchmarks for row iteration and row-to-struct mapping.

Measures the cost of:
- Raw row scan        — `stmt.query()` iterating rows and reading columns by index.
- Closure mapping      — `stmt.query[transform]()` mapping each row via an explicit closure.
- Struct reflection     — `stmt.query[T]()` mapping each row via struct reflection.
- one_row              — single-row convenience path on `Connection`.

Each `do()` closure builds its own 200-row table from scratch -- capturing a
`Connection`/`Statement` from the outer function scope into the closure passed
to `Bencher.iter` triggers a `SQLITE_MISUSE` crash specific to the benchmark
harness, so table setup is included in every measurement here (mirroring how
`bench_csvtab.mojo` rebuilds its virtual table on every iteration). Subtract
`bench_query_raw_rows` from the others to estimate the relative cost of each
mapping strategy over the same fixed table-setup cost.

Run from the workspace root::

    pixi run mojo -D ASSERT=all -I . benchmarks/functions/bench_query.mojo
"""

from std.benchmark import Bencher
from slight.connection import Connection
from slight.flags import PrepFlag
from slight.row import Row

comptime ROW_COUNT = 200


@fieldwise_init
struct QueryRow(Copyable, Defaultable, Writable):
    var id: Int
    var name: String
    var value: Float64

    def __init__(out self):
        self.id = 0
        self.name = ""
        self.value = 0.0

    def write_to(self, mut writer: Some[Writer]):
        writer.write("QueryRow(id=", self.id, ", name=", self.name, ", value=", self.value, ")")


def _make_populated_connection() raises -> Connection:
    var conn = Connection.open_in_memory()
    conn.execute_batch("CREATE TABLE t (id INTEGER, name TEXT, value REAL)")
    var sql = String("")
    for i in range(ROW_COUNT):
        sql += "INSERT INTO t (id, name, value) VALUES (" + String(i) + ", 'row', " + String(Float64(i)) + ");"
    conn.execute_batch(sql)
    return conn^


def _to_query_row(row: Row) raises -> QueryRow:
    return QueryRow(
        id=row.get[Int](0),
        name=row.get[String](1),
        value=row.get[Float64](2),
    )

# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_query_raw_rows(mut b: Bencher) raises:
    """Build a 200-row table, then iterate all rows via `stmt.query()`,
    reading columns by index."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        var stmt = conn.prepare("SELECT id, name, value FROM t", PrepFlag(0))
        for row in stmt.query():
            _ = row.get[Int](0)
            _ = row.get[String](1)
            _ = row.get[Float64](2)

    b.iter[do]()


@parameter
def bench_query_mapped(mut b: Bencher) raises:
    """Build a 200-row table, then map all rows into `QueryRow` via an
    explicit closure."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        var stmt = conn.prepare("SELECT id, name, value FROM t", PrepFlag(0))
        for _ in stmt.query[_to_query_row]():
            pass

    b.iter[do]()


@parameter
def bench_query_typed_reflection(mut b: Bencher) raises:
    """Build a 200-row table, then map all rows into `QueryRow` via struct
    reflection (`query[T]`)."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        var stmt = conn.prepare("SELECT id, name, value FROM t", PrepFlag(0))
        for _ in stmt.query[QueryRow]():
            pass

    b.iter[do]()


@parameter
def bench_one_row(mut b: Bencher) raises:
    """Build a 200-row table, then fetch one row via `Connection.one_row`."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        _ = conn.one_row[_to_query_row]("SELECT id, name, value FROM t WHERE id = 100")

    b.iter[do]()
