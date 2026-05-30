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


def _bytes_measure(n_bytes: Int) raises -> ThroughputMeasure:
    return ThroughputMeasure(BenchMetric.bytes, n_bytes)


def run[
    func: def (mut Bencher, String) raises capturing,
    name: String,
](mut m: Bench, csv_path: String, file_bytes: Int) raises:
    m.bench_with_input[String, func](BenchId(name), csv_path, [_bytes_measure(file_bytes)])


# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_csvtab_full_scan(mut b: Bencher, csv_path: String) raises:
    """Full table scan: iterate every row from the CSV virtual table.

    Each iteration opens a fresh in-memory connection, loads the csvtab module,
    creates the virtual table, prepares the query, and scans all rows.
    The measured time therefore includes connection + vtab + scan overhead.
    Subtract bench_csvtab_connect to isolate the scan cost.
    """

    @parameter
    def do() raises:
        var conn = Connection.open_in_memory()
        load_module(conn)
        conn.execute_batch(
            "CREATE VIRTUAL TABLE t USING csv(filename='" + csv_path + "', header=yes)"
        )
        var stmt = conn.prepare("SELECT id, name, value, category FROM t", PrepFlag(0))
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_csvtab_count(mut b: Bencher, csv_path: String) raises:
    """COUNT(*) query: full scan aggregated through SQLite.

    Each iteration opens a fresh connection and measures connect + vtab +
    COUNT(*) scan.  Subtract bench_csvtab_connect to isolate the query cost.
    """

    @parameter
    def do() raises:
        var conn = Connection.open_in_memory()
        load_module(conn)
        conn.execute_batch(
            "CREATE VIRTUAL TABLE t USING csv(filename='" + csv_path + "', header=yes)"
        )
        var stmt = conn.prepare("SELECT COUNT(*) FROM t", PrepFlag(0))
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_csvtab_filter(mut b: Bencher, csv_path: String) raises:
    """Filtered scan: WHERE clause that passes roughly half the rows.

    Each iteration opens a fresh connection and measures connect + vtab +
    filtered scan.  Subtract bench_csvtab_connect to isolate the filter cost.
    """

    @parameter
    def do() raises:
        var conn = Connection.open_in_memory()
        load_module(conn)
        conn.execute_batch(
            "CREATE VIRTUAL TABLE t USING csv(filename='" + csv_path + "', header=yes)"
        )
        var stmt = conn.prepare(
            "SELECT id, name FROM t WHERE CAST(value AS INTEGER) > 498", PrepFlag(0)
        )
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_csvtab_connect(mut b: Bencher, csv_path: String) raises:
    """Connect overhead: open connection + load module + CREATE VIRTUAL TABLE."""

    @always_inline
    @parameter
    def do() raises:
        var conn = Connection.open_in_memory()
        load_module(conn)
        conn.execute_batch(
            "CREATE VIRTUAL TABLE t USING csv(filename='" + csv_path + "', header=yes)"
        )

    b.iter[do]()


# ===----------------------------------------------------------------------=== #
# Entry point
# ===----------------------------------------------------------------------=== #


def main() raises:
    var config = BenchConfig()
    config.verbose_timing = True
    config.flush_denormals = True
    config.show_progress = True
    var bench = Bench(config^)

    var csv_path = String(pathlib._dir_of_current_file()) + "/data/bench.csv"
    var file_bytes: Int
    with open(csv_path, "r") as f:
        file_bytes = f.read().byte_length()

    run[bench_csvtab_full_scan, "csvtab_full_scan"](bench, csv_path, file_bytes)
    run[bench_csvtab_count, "csvtab_count"](bench, csv_path, file_bytes)
    run[bench_csvtab_filter, "csvtab_filter"](bench, csv_path, file_bytes)
    run[bench_csvtab_connect, "csvtab_connect"](bench, csv_path, file_bytes)

    bench.dump_report()
