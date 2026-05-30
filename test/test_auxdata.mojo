from slight.connection import Connection
from slight.context import Context
from slight.row import Row
from slight.c.types import MutExternalPointer, ResultDestructorFn
from slight.util import ptr_copy
from std.testing import TestSuite, assert_equal


# ===----------------------------------------------------------------------=== #
# Auxdata destructor
# ===----------------------------------------------------------------------=== #


def free_auxdata(ptr: Optional[MutExternalPointer[NoneType]]) abi("C"):
    """Free heap-allocated auxdata. Passed as the destructor to set_auxdata."""
    if ptr:
        ptr.value().free()


# ===----------------------------------------------------------------------=== #
# Function helpers
# ===----------------------------------------------------------------------=== #


def detect_first_call(ctx: Context) raises -> Int64:
    """Returns 1 on the first call (no auxdata set), 0 on subsequent calls.

    Allocates and stores a sentinel Int64 as auxdata at index 0 on the first
    invocation.  If SQLite preserves auxdata across rows (for constant args),
    later rows in the same query see the cached value.
    """
    var existing = ctx.get_auxdata(0)
    if not existing:
        var ptr = ptr_copy(Int64(1))
        ctx.set_auxdata(0, ptr.bitcast[NoneType](), free_auxdata)
        return Int64(1)
    return Int64(0)


def round_trip_auxdata(ctx: Context) raises -> Int64:
    """Stores (arg * 2) as auxdata at index 0, then reads and returns it.

    Tests that a value stored with set_auxdata is immediately visible via
    get_auxdata within the same function invocation.
    """
    var ptr = ptr_copy(ctx.get_int64(0) * 2)
    ctx.set_auxdata(0, ptr.bitcast[NoneType](), free_auxdata)
    var stored = ctx.get_auxdata(0)
    if not stored:
        return Int64(-1)  # Unexpected: auxdata should be visible immediately
    return stored.value().bitcast[Int64]()[]


def overwrite_auxdata(ctx: Context) raises -> Int64:
    """Sets auxdata at index 0 twice and returns the value from the second set.

    Verifies that a second call to set_auxdata on the same index replaces the
    previous value, with the new value returned by the subsequent get_auxdata.
    """
    var p1 = ptr_copy(Int64(100))
    ctx.set_auxdata(0, p1.bitcast[NoneType](), free_auxdata)
    var p2 = ptr_copy(Int64(200))
    ctx.set_auxdata(0, p2.bitcast[NoneType](), free_auxdata)
    var stored = ctx.get_auxdata(0)
    if not stored:
        return Int64(-1)  # Unexpected
    return stored.value().bitcast[Int64]()[]


def sum_two_auxdata(ctx: Context) raises -> Int64:
    """Caches each integer argument at its own auxdata index and returns their sum.

    On the first call, stores ctx.get_int64(0) at auxdata index 0 and
    ctx.get_int64(1) at auxdata index 1.  On subsequent calls the cached values
    are reused, demonstrating that auxdata slots are independent per index.
    """
    if not ctx.get_auxdata(0):
        var p0 = ptr_copy(ctx.get_int64(0))
        ctx.set_auxdata(0, p0.bitcast[NoneType](), free_auxdata)
    if not ctx.get_auxdata(1):
        var p1 = ptr_copy(ctx.get_int64(1))
        ctx.set_auxdata(1, p1.bitcast[NoneType](), free_auxdata)
    var v0 = ctx.get_auxdata(0).value().bitcast[Int64]()[]
    var v1 = ctx.get_auxdata(1).value().bitcast[Int64]()[]
    return v0 + v1


# ===----------------------------------------------------------------------=== #
# Helpers
# ===----------------------------------------------------------------------=== #


def _setup_rows_table(db: Connection) raises:
    """Create table t with three rows (values 1, 2, 3)."""
    db.execute_batch(
        """
        CREATE TABLE t (x INTEGER);
        INSERT INTO t VALUES (1);
        INSERT INTO t VALUES (2);
        INSERT INTO t VALUES (3);
        """
    )


# ===----------------------------------------------------------------------=== #
# Auxdata tests
# ===----------------------------------------------------------------------=== #


def test_auxdata_initially_none() raises:
    """Returns None before any auxdata has been stored.

    detect_first_call returns 1 when auxdata is absent, so a single-row query
    must return 1.
    """
    var db = Connection.open_in_memory()
    db.create_scalar_function[detect_first_call]("detect_first_call", n_arg=1)

    def get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT detect_first_call(99)"), 1)


def test_auxdata_round_trip_within_same_call() raises:
    """Following set_auxdata immediately by get_auxdata returns the stored value.

    round_trip_auxdata stores (arg * 2) as auxdata then reads it back within
    the same invocation.  This tests the fundamental set/get contract without
    relying on cross-row persistence, which SQLite does not guarantee.
    """
    var db = Connection.open_in_memory()
    db.create_scalar_function[round_trip_auxdata]("round_trip_auxdata", n_arg=1)

    def get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT round_trip_auxdata(5)"), 10)
    assert_equal(db.one_row[get_int]("SELECT round_trip_auxdata(3)"), 6)
    assert_equal(db.one_row[get_int]("SELECT round_trip_auxdata(0)"), 0)


def test_auxdata_set_overwrites_previous_value() raises:
    """A second set_auxdata on the same index replaces the first stored value.

    overwrite_auxdata calls set_auxdata(0, 100) then set_auxdata(0, 200)
    within the same invocation.  get_auxdata(0) must return 200, confirming
    the second write wins.
    """
    var db = Connection.open_in_memory()
    db.create_scalar_function[overwrite_auxdata]("overwrite_auxdata", n_arg=0)

    def get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT overwrite_auxdata()"), 200)


def test_auxdata_cleared_between_statements() raises:
    """Auxdata does not persist across separate SQL statement executions.

    Each new statement starts with no auxdata, so detect_first_call must return
    1 for every independent query invocation.
    """
    var db = Connection.open_in_memory()
    db.create_scalar_function[detect_first_call]("detect_first_call", n_arg=1)

    def get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT detect_first_call(1)"), 1)
    assert_equal(db.one_row[get_int]("SELECT detect_first_call(1)"), 1)
    assert_equal(db.one_row[get_int]("SELECT detect_first_call(1)"), 1)


def test_auxdata_independent_per_argument_index() raises:
    """Auxdata stored at different argument indices does not interfere.

    sum_two_auxdata caches the first argument at index 0 and the second at
    index 1, then returns their sum.  With constant arguments (10, 20) the
    result must be 30 for every row, confirming both slots are cached and
    retrieved independently.
    """
    var db = Connection.open_in_memory()
    _setup_rows_table(db)
    db.create_scalar_function[sum_two_auxdata]("sum_two_auxdata", n_arg=2)

    var stmt = db.prepare("SELECT sum_two_auxdata(10, 20) FROM t ORDER BY x")
    var results = List[Int64]()
    for row in stmt.query():
        results.append(row.get[Int64](0))

    assert_equal(len(results), 3)
    assert_equal(results[0], 30)
    assert_equal(results[1], 30)
    assert_equal(results[2], 30)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
