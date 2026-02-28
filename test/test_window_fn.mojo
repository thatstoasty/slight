from slight.connection import Connection
from slight.context import Context
from slight.functions import FunctionFlags
from slight.row import Row
from std.testing import TestSuite, assert_equal, assert_false, assert_not_equal, assert_raises, assert_true

# ===----------------------------------------------------------------------=== #
# Window function helpers
# ===----------------------------------------------------------------------=== #


fn win_sum_init(mut ctx: Context) raises -> Int64:
    return 0


fn win_sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)


fn win_sum_finalize(mut ctx: Context, acc: Int64) raises -> Optional[Int64]:
    return acc


fn win_sum_inverse(mut ctx: Context, mut acc: Int64) raises:
    acc -= ctx.get_int64(0)


fn win_sum_value(acc: Optional[Int64]) raises -> Optional[Int64]:
    return acc.copy()

# ===----------------------------------------------------------------------=== #
# Window function tests
# ===----------------------------------------------------------------------=== #

fn _setup_numbers_table(db: Connection) raises:
    """Helper: create a numbers table with values 1-5."""
    db.execute_batch(
        """
        CREATE TABLE numbers (value INTEGER);
        INSERT INTO numbers VALUES (1);
        INSERT INTO numbers VALUES (2);
        INSERT INTO numbers VALUES (3);
        INSERT INTO numbers VALUES (4);
        INSERT INTO numbers VALUES (5);
        """
    )


fn test_window_running_sum() raises:
    """Test window function computing a running sum over the entire partition."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)

    db.create_window_function[win_sum_init, win_sum_step, win_sum_finalize, win_sum_value, win_sum_inverse](
        "win_sum", n_arg=1,
    )

    fn get_row(row: Row) raises -> Tuple[Int64, Int64]:
        return (row.get[Int64](0), row.get[Int64](1))

    var stmt = db.prepare(
        """
        SELECT value,
               win_sum(value) OVER (ORDER BY value ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        FROM numbers
        """
    )
    var results = List[Tuple[Int64, Int64]]()
    for row in stmt.query():
        results.append((row.get[Int64](0), row.get[Int64](1)))

    assert_equal(len(results), 5)
    # Running sum: 1, 1+2=3, 3+3=6, 6+4=10, 10+5=15
    assert_equal(results[0][1], 1)
    assert_equal(results[1][1], 3)
    assert_equal(results[2][1], 6)
    assert_equal(results[3][1], 10)
    assert_equal(results[4][1], 15)


fn test_window_sliding_frame() raises:
    """Test window function with a sliding 2-row frame (1 PRECEDING to CURRENT ROW)."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)

    db.create_window_function[win_sum_init, win_sum_step, win_sum_finalize, win_sum_value, win_sum_inverse](
        "win_sum", n_arg=1,
    )

    fn get_row(row: Row) raises -> Tuple[Int64, Int64]:
        return (row.get[Int64](0), row.get[Int64](1))

    var stmt = db.prepare(
        """
        SELECT value,
               win_sum(value) OVER (ORDER BY value ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)
        FROM numbers
        """
    )
    var results = List[Tuple[Int64, Int64]]()
    for row in stmt.query():
        results.append((row.get[Int64](0), row.get[Int64](1)))

    assert_equal(len(results), 5)
    # Frame [1 PRECEDING, CURRENT]: (1)=1, (1,2)=3, (2,3)=5, (3,4)=7, (4,5)=9
    assert_equal(results[0][1], 1)
    assert_equal(results[1][1], 3)
    assert_equal(results[2][1], 5)
    assert_equal(results[3][1], 7)
    assert_equal(results[4][1], 9)


fn test_window_full_partition() raises:
    """Test window function over the entire partition (no frame restriction)."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)

    db.create_window_function[win_sum_init, win_sum_step, win_sum_finalize, win_sum_value, win_sum_inverse](
        "win_sum", n_arg=1,
    )

    fn get_row(row: Row) raises -> Tuple[Int64, Int64]:
        return (row.get[Int64](0), row.get[Int64](1))

    var stmt = db.prepare(
        """
        SELECT value,
               win_sum(value) OVER ()
        FROM numbers ORDER BY value
        """
    )
    var results = List[Tuple[Int64, Int64]]()
    for row in stmt.query():
        results.append((row.get[Int64](0), row.get[Int64](1)))

    # Every row should see the total sum of 15
    assert_equal(len(results), 5)
    for i in range(5):
        assert_equal(results[i][1], 15)


fn test_window_with_partition_by() raises:
    """Test window function with PARTITION BY, creating separate windows per group."""
    var db = Connection.open_in_memory()
    db.execute_batch(
        """
        CREATE TABLE scores (team TEXT, points INTEGER);
        INSERT INTO scores VALUES ('A', 10);
        INSERT INTO scores VALUES ('A', 20);
        INSERT INTO scores VALUES ('A', 30);
        INSERT INTO scores VALUES ('B', 5);
        INSERT INTO scores VALUES ('B', 15);
        """
    )

    db.create_window_function[win_sum_init, win_sum_step, win_sum_finalize, win_sum_value, win_sum_inverse](
        "win_sum", n_arg=1,
    )

    fn get_row(row: Row) raises -> Tuple[String, Int64, Int64]:
        return (row.get[String](0), row.get[Int64](1), row.get[Int64](2))

    var stmt = db.prepare(
        """
        SELECT team, points,
               win_sum(points) OVER (PARTITION BY team ORDER BY points ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        FROM scores ORDER BY team, points
        """
    )
    var results = List[Tuple[String, Int64, Int64]]()
    for row in stmt.query():
        results.append((row.get[String](0), row.get[Int64](1), row.get[Int64](2)))

    assert_equal(len(results), 5)
    # Team A: running sum 10, 30, 60
    assert_equal(results[0][0], "A")
    assert_equal(results[0][2], 10)
    assert_equal(results[1][2], 30)
    assert_equal(results[2][2], 60)
    # Team B: running sum 5, 20
    assert_equal(results[3][0], "B")
    assert_equal(results[3][2], 5)
    assert_equal(results[4][2], 20)


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()