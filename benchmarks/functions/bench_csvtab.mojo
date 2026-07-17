"""Benchmarks for the csvtab virtual table module.

Measures the cost of:
- Full table scan   — stream every row from a 1 000-row CSV file.
- COUNT(*) query    — same scan aggregated through SQLite.
- connect overhead  — connection setup + virtual-table creation per iteration.

Run from the workspace root::

    pixi run mojo -D ASSERT=all -I . benchmarks/bench_csvtab.mojo
"""

from std import pathlib
from std.benchmark import Bench, BenchConfig, Bencher, BenchId, BenchMetric, ThroughputMeasure
from slight.connection import Connection
from slight.flags import PrepFlag
from slight.vtab.csvtab import load_module


@fieldwise_init
struct CSVTabBenchContext[origin: ImmutOrigin]:
    var csv_path: String
    var file_bytes: Int
    var connection: Pointer[Connection, Self.origin]


# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_csvtab_full_scan[origin: ImmutOrigin](mut b: Bencher, context: CSVTabBenchContext[origin]) raises:
    """Full table scan: iterate every row from the CSV virtual table.

    Each iteration opens a fresh in-memory connection, loads the csvtab module,
    creates the virtual table, prepares the query, and scans all rows.
    The measured time therefore includes connection + vtab + scan overhead.
    Subtract bench_csvtab_connect to isolate the scan cost.
    """
    @parameter
    def do() raises:
        var stmt = context.connection[].prepare("SELECT id, name, value, category FROM t", PrepFlag.NONE)
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_csvtab_count[origin: ImmutOrigin](mut b: Bencher, context: CSVTabBenchContext[origin]) raises:
    """COUNT(*) query: full scan aggregated through SQLite.

    Each iteration opens a fresh connection and measures connect + vtab +
    COUNT(*) scan.  Subtract bench_csvtab_connect to isolate the query cost.
    """

    @parameter
    def do() raises:
        var stmt = context.connection[].prepare("SELECT COUNT(*) FROM t", PrepFlag.NONE)
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_csvtab_filter[origin: ImmutOrigin](mut b: Bencher, context: CSVTabBenchContext[origin]) raises:
    """Filtered scan: WHERE clause that passes roughly half the rows.

    Each iteration opens a fresh connection and measures connect + vtab +
    filtered scan.  Subtract bench_csvtab_connect to isolate the filter cost.
    """

    @parameter
    def do() raises:
        var stmt = context.connection[].prepare(
            "SELECT id, name FROM t WHERE CAST(value AS INTEGER) > 498", PrepFlag.NONE
        )
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_csvtab_create_and_drop[origin: ImmutOrigin](mut b: Bencher, context: CSVTabBenchContext[origin]) raises:
    """CREATE VIRTUAL TABLE and drop it."""

    @always_inline
    @parameter
    def do() raises:
        context.connection[].execute_batch(
            t"""CREATE VIRTUAL TABLE t2 USING csv(filename='{context.csv_path}', header=yes);
            DROP TABLE IF EXISTS t2;"""
        )

    b.iter[do]()
