"""Benchmarks for transactions and savepoints.

Measures the cost of:
- Commit       — connect + create table + 50 inserts wrapped in a transaction, committed.
- Rollback     — connect + create table + 50 inserts wrapped in a transaction, rolled back.
- Savepoint    — connect + create table + a nested savepoint around a single insert.

Each `do()` closure builds its own connection from scratch -- capturing a
`Connection` from the outer function scope into the closure passed to
`Bencher.iter` triggers a `SQLITE_MISUSE` crash specific to the benchmark
harness, so connect + table-create cost is included in every measurement
here. Compare `bench_transaction_commit` against `bench_execute_batch` (50 vs
100 statements, same order of magnitude) to see the relative overhead of
explicit transaction control vs. a single `execute_batch` call.

Run from the workspace root::

    pixi run mojo -D ASSERT=all -I . benchmarks/functions/bench_transaction.mojo
"""

from std.benchmark import Bencher
from slight.connection import Connection

comptime INSERT_COUNT = 50

# ===----------------------------------------------------------------------=== #
# Benchmark functions
# ===----------------------------------------------------------------------=== #


@parameter
def bench_transaction_commit(mut b: Bencher, conn: Connection) raises:
    """50 inserts wrapped in a transaction, committed at the end."""

    @parameter
    def do() raises:
        with conn.transaction() as tx:
            for i in range(INSERT_COUNT):
                _ = tx.execute("INSERT INTO t (id) VALUES (?1)", (i,))
            tx.commit()

    b.iter[do]()


@parameter
def bench_transaction_rollback(mut b: Bencher, conn: Connection) raises:
    """50 inserts wrapped in a transaction, rolled back at the end (the
    default behavior on scope exit without an explicit commit)."""

    @parameter
    def do() raises:
        with conn.transaction() as tx:
            for i in range(INSERT_COUNT):
                _ = tx.execute("INSERT INTO t (id) VALUES (?1)", (i,))
            # No commit -- implicit rollback on scope exit.

    b.iter[do]()


@parameter
def bench_savepoint_nested(mut b: Bencher, conn: Connection) raises:
    """A single savepoint nested inside a transaction, with both committed."""

    @parameter
    def do() raises:
        with conn.transaction() as tx:
            with tx.savepoint() as sp:
                _ = sp.execute("INSERT INTO t (id) VALUES (?1)", (1,))
                sp.commit()
            tx.commit()

    b.iter[do]()
