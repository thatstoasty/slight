"""Benchmarks for the prepare/bind/step cycle on `Statement`.

Measures the cost of:
- Prepare           — connect + create table + compiling a SQL statement, no execution.
- Positional bind    — connect + create table + prepare + binding a `Tuple` (?1, ?2, ?3) + step.
- Named bind         — connect + create table + prepare + binding a `Dict` (:name) + step.
- Reset + rebind     — prepare once, then reset+rebind+step 20 times in a row, to
  show the amortized per-call cost once the one-time prepare cost is spread out.

Every `do()` closure builds its own connection (and statement) from scratch --
capturing a `Connection`/`Statement` from the outer function scope into the
closure passed to `Bencher.iter` triggers a `SQLITE_MISUSE` crash specific to
the benchmark harness, so all state lives entirely inside the timed closure.

Run from the workspace root::

    pixi run mojo -D ASSERT=all -I . benchmarks/functions/bench_statement.mojo
"""

from std.benchmark import Bencher
from slight.connection import Connection
from slight.flags import PrepFlag

# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_prepare(mut b: Bencher, conn: Connection) raises:
    """Cost of `Connection.prepare`, with no binding or stepping."""

    @parameter
    def do() raises:
        var stmt = conn.prepare("SELECT id, name, value FROM t WHERE id = ?1", PrepFlag(0))
        _ = stmt

    b.iter[do]()


@parameter
def bench_bind_positional(mut b: Bencher, conn: Connection) raises:
    """Bind a heterogeneous `Tuple` to `?1`/`?2`/`?3` and step once."""

    @parameter
    def do() raises:
        var stmt = conn.prepare(
            "INSERT INTO t (id, name, value) VALUES (?1, ?2, ?3)", PrepFlag(0)
        )
        for _ in stmt.query((1, "row", 1.5)):
            pass

    b.iter[do]()


@parameter
def bench_bind_named(mut b: Bencher, conn: Connection) raises:
    """Bind a `Dict` of `:name` parameters and step once."""

    @parameter
    def do() raises:
        var stmt = conn.prepare(
            "INSERT INTO t (id, name, value) VALUES (:id, :name, :value)", PrepFlag(0)
        )
        for _ in stmt.query({":id": "1", ":name": "row", ":value": "1.5"}):
            pass

    b.iter[do]()


@parameter
def bench_reset_and_rebind(mut b: Bencher, conn: Connection) raises:
    """Prepare once, then reset+rebind+step 20 times -- the amortized
    re-execution cost, separate from the one-time prepare cost measured by
    `bench_prepare`."""

    @parameter
    def do() raises:
        var stmt = conn.prepare(
            "INSERT INTO t (id, name, value) VALUES (?1, ?2, ?3)", PrepFlag(0)
        )
        for i in range(20):
            stmt.reset()
            for _ in stmt.query((i, "row", Float64(i))):
                pass

    b.iter[do]()
