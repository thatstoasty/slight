"""Benchmarks for `Connection.execute` / `execute_batch` and connection setup.

Measures the cost of:
- Connecting     — bare in-memory connection open, no table.
- Single insert  — connect + create table + one `INSERT`.
- Batch insert   — connect + create table + `execute_batch` with 100 statements.

Each benchmark builds its connection (and any other state) entirely inside the
timed `do()` closure rather than reusing state captured from the outer
function. Capturing a `Connection`, `Statement`, or even a plain `String` from
the outer scope into the closure passed to `Bencher.iter` triggers a
`SQLITE_MISUSE` crash specific to the benchmark harness -- this is the same
discipline `bench_csvtab.mojo` follows (it rebuilds the connection and virtual
table on every iteration too). Subtract `bench_connect_overhead` from the
others to estimate the cost of just the `INSERT`/`execute_batch` call.

Run from the workspace root::

    pixi run mojo -D ASSERT=all -I . benchmarks/functions/bench_execute.mojo
"""

from std.benchmark import Bencher
from slight.connection import Connection

# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_connect_overhead(mut b: Bencher) raises:
    """Bare connection open, used as a baseline to subtract from the other
    benchmarks in this module."""

    @parameter
    def do() raises:
        var conn = Connection.open_in_memory()
        conn^.close()

    b.iter[do]()


@parameter
def bench_execute_single_insert(mut b: Bencher, conn: Connection) raises:
    """Connect + create table + one `INSERT`."""

    @parameter
    def do() raises:
        _ = conn.execute(
            "INSERT INTO t (id, name, value) VALUES (?1, ?2, ?3)",
            (1, "row", 1.5),
        )

    b.iter[do]()

def _build_insert_sql[count: Int]() -> String:
    var sql = ""
    comptime for i in range(count):
        sql.write(t"INSERT INTO t (id, name, value) VALUES ({i}, 'row', {i});")
    return sql^

@parameter
def bench_execute_batch(mut b: Bencher, conn: Connection) raises:
    """Connect + create table + `execute_batch` with 100 INSERT statements."""
    comptime sql = _build_insert_sql[100]()

    @parameter
    def do() raises:
        conn.execute_batch(sql)

    b.iter[do]()
