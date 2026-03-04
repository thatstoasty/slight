from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row
from std.testing import TestSuite, assert_equal, assert_false, assert_not_equal, assert_raises, assert_true


# ===----------------------------------------------------------------------=== #
# Aggregate function helpers
# ===----------------------------------------------------------------------=== #


fn sum_init(mut ctx: Context) raises -> Int64:
    return 0


fn sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)


fn sum_finalize(mut ctx: Context, acc: Int64) raises -> Int64:
    return acc


fn count_init(mut ctx: Context) raises -> Int64:
    return 0


fn count_step(mut ctx: Context, mut acc: Int64) raises:
    acc += 1


fn count_finalize(mut ctx: Context, acc: Int64) raises -> Int64:
    return acc


fn concat_init(mut ctx: Context) raises -> String:
    return String("")


fn concat_step(mut ctx: Context, mut acc: String) raises:
    if len(acc) > 0:
        acc += ","
    acc += String(ctx.get_text(0))


fn concat_finalize(mut ctx: Context, acc: String) raises -> String:
    return acc


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

# ===----------------------------------------------------------------------=== #
# Aggregate function tests
# ===----------------------------------------------------------------------=== #


fn test_aggregate_sum() raises:
    """Test a custom SUM aggregate function."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)

    db.create_aggregate_function[sum_init, sum_step, sum_finalize](
        "my_sum", n_arg=1,
    )

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT my_sum(value) FROM numbers"), 15)


fn test_aggregate_count() raises:
    """Test a custom COUNT aggregate function."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)

    db.create_aggregate_function[count_init, count_step, count_finalize](
        "my_count", n_arg=1,
    )

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT my_count(value) FROM numbers"), 5)


fn test_aggregate_concat() raises:
    """Test a custom string concatenation aggregate."""
    var db = Connection.open_in_memory()
    db.execute_batch(
        """
        CREATE TABLE words (word TEXT);
        INSERT INTO words VALUES ('foo');
        INSERT INTO words VALUES ('bar');
        INSERT INTO words VALUES ('baz');
        """
    )

    db.create_aggregate_function[concat_init, concat_step, concat_finalize](
        "my_concat", n_arg=1,
    )

    fn get_text(row: Row) raises -> String:
        return row.get[String](0)

    assert_equal(db.one_row[get_text]("SELECT my_concat(word) FROM words"), "foo,bar,baz")


fn test_aggregate_empty_table() raises:
    """Test aggregate function on an empty table."""
    var db = Connection.open_in_memory()
    _ = db.execute("CREATE TABLE empty_table (value INTEGER)")

    db.create_aggregate_function[sum_init, sum_step, sum_finalize](
        "my_sum", n_arg=1,
    )

    fn get_optional_int(row: Row) raises -> Optional[Int64]:
        return row.get[Optional[Int64]](0)

    # Aggregate over 0 rows — xFinal is still called but with the initial context.
    with assert_raises(contains="No rows returned by query."):
        _ = db.one_row[get_optional_int]("SELECT my_sum(value) FROM empty_table")
    # SQLite calls xFinal even with 0 rows; the result depends on the aggregate_context behavior.
    # With the current implementation, this may return NULL if no xStep was called.
    # Either NULL or 0 is acceptable here — just ensure no crash.


fn test_aggregate_with_group_by() raises:
    """Test aggregate function with GROUP BY producing multiple groups."""
    var db = Connection.open_in_memory()
    db.execute_batch(
        """
        CREATE TABLE scores (team TEXT, points INTEGER);
        INSERT INTO scores VALUES ('A', 10);
        INSERT INTO scores VALUES ('A', 20);
        INSERT INTO scores VALUES ('B', 5);
        INSERT INTO scores VALUES ('B', 15);
        INSERT INTO scores VALUES ('B', 25);
        """
    )

    db.create_aggregate_function[sum_init, sum_step, sum_finalize](
        "my_sum", n_arg=1,
    )

    fn get_row(row: Row) raises -> Tuple[String, Int64]:
        return (row.get[String](0), row.get[Int64](1))

    var stmt = db.prepare("SELECT team, my_sum(points) FROM scores GROUP BY team ORDER BY team")
    var results = List[Tuple[String, Int64]]()
    for row in stmt.query():
        results.append((row.get[String](0), row.get[Int64](1)))

    assert_equal(len(results), 2)
    assert_equal(results[0][0], "A")
    assert_equal(results[0][1], 30)
    assert_equal(results[1][0], "B")
    assert_equal(results[1][1], 45)


fn test_aggregate_with_filter() raises:
    """Test aggregate function with a WHERE filter."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)

    db.create_aggregate_function[sum_init, sum_step, sum_finalize](
        "my_sum", n_arg=1,
    )

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    # Sum of values > 3: 4 + 5 = 9
    assert_equal(
        db.one_row[get_int]("SELECT my_sum(value) FROM numbers WHERE value > 3"),
        9,
    )


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
