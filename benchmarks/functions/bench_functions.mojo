"""Benchmarks for scalar, aggregate, and window SQL function registration and use.

Measures the cost of:
- Registration   — `create_scalar_function[...]` call alone, no invocation.
- Scalar UDF     — connect + table + register + call a scalar function over 200 rows.
- Aggregate UDF  — connect + table + register + `SELECT my_sum(value) FROM t` over 200 rows.
- Window UDF     — connect + table + register + a windowed `OVER (...)` query over 200 rows.

Each `do()` closure builds its own connection (and registers the UDF) from
scratch -- capturing a `Connection` from the outer function scope into the
closure passed to `Bencher.iter` triggers a `SQLITE_MISUSE` crash specific to
the benchmark harness, so connect + table-create + registration cost is
included in every measurement here.

Run from the workspace root::

    pixi run mojo -D ASSERT=all -I . benchmarks/functions/bench_functions.mojo
"""

from std.benchmark import Bencher
from slight.connection import Connection
from slight.flags import PrepFlag
from slight.functions import Context, FunctionFlags

comptime ROW_COUNT = 200


def _make_populated_connection() raises -> Connection:
    var conn = Connection.open_in_memory()
    conn.execute_batch("CREATE TABLE t (value INTEGER)")
    var sql = String("")
    for i in range(ROW_COUNT):
        sql += "INSERT INTO t (value) VALUES (" + String(i) + ");"
    conn.execute_batch(sql)
    return conn^


def halve(ctx: Context) raises -> Float64:
    return ctx.get_double(0) / 2.0


def sum_init(mut ctx: Context) raises -> Int64:
    return 0


def sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)


def sum_finalize(mut ctx: Context, acc: Int64) raises -> Optional[Int64]:
    return acc


def sum_inverse(mut ctx: Context, mut acc: Int64) raises:
    acc -= ctx.get_int64(0)


def sum_value(acc: Optional[Int64]) raises -> Optional[Int64]:
    return acc.copy()

# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_udf_registration(mut b: Bencher) raises:
    """Cost of `create_scalar_function[...]` itself, with no invocation."""

    @parameter
    def do() raises:
        var conn = Connection.open_in_memory()
        conn.create_scalar_function[halve]("halve", n_arg=1)

    b.iter[do]()


@parameter
def bench_scalar_udf(mut b: Bencher) raises:
    """Register and call a scalar function over 200 rows."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        conn.create_scalar_function[halve]("halve", n_arg=1)
        var stmt = conn.prepare("SELECT halve(value) FROM t", PrepFlag(0))
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_aggregate_udf(mut b: Bencher) raises:
    """Register `my_sum` and run `SELECT my_sum(value) FROM t` over 200 rows."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        conn.create_aggregate_function[sum_init, sum_step, sum_finalize](
            "my_sum",
            n_arg=1,
            flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
        )
        var stmt = conn.prepare("SELECT my_sum(value) FROM t", PrepFlag(0))
        for _ in stmt.query():
            pass

    b.iter[do]()


@parameter
def bench_window_udf(mut b: Bencher) raises:
    """Register `my_sum` as a window function and run a windowed `OVER (...)`
    query over 200 rows."""

    @parameter
    def do() raises:
        var conn = _make_populated_connection()
        conn.create_window_function[sum_init, sum_step, sum_finalize, sum_value, sum_inverse](
            "my_sum",
            n_arg=1,
            flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
        )
        var stmt = conn.prepare(
            "SELECT value, my_sum(value) OVER (ORDER BY value ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) FROM t",
            PrepFlag(0),
        )
        for _ in stmt.query():
            pass

    b.iter[do]()
