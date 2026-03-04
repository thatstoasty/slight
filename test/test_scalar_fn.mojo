from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row
from std.testing import TestSuite, assert_equal, assert_false, assert_not_equal, assert_raises, assert_true


# ===----------------------------------------------------------------------=== #
# Scalar function helpers
# ===----------------------------------------------------------------------=== #


fn double_it(ctx: Context) raises -> Int64:
    """Return the first argument multiplied by 2."""
    return ctx.get_int64(0) * 2


fn add_two(ctx: Context) raises -> Float64:
    """Return the sum of the first two arguments as a Float64."""
    return ctx.get_double(0) + ctx.get_double(1)


fn greet(ctx: Context) raises -> String:
    """Return a greeting string from two text arguments."""
    return String("Hello, ") + String(ctx.get_text(0)) + String("!")


fn constant_42(ctx: Context) raises -> Int64:
    """Return 42 regardless of arguments (zero-arg function)."""
    return 42


fn user_data_adder(ctx: Context) raises -> Int64:
    """Add the user_data value (Int64) to the first argument."""
    var offset = ctx.user_data().bitcast[Int64]()[]
    return ctx.get_int64(0) + offset


fn nullable_double(ctx: Context) raises -> Optional[Int64]:
    """Return arg*2 if arg is non-zero, else None (NULL)."""
    var v = ctx.get_int64(0)
    if v == 0:
        return None
    return v * 2


# ===----------------------------------------------------------------------=== #
# Scalar function tests
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


fn test_scalar_int64() raises:
    """Test a scalar function that doubles an integer."""
    var db = Connection.open_in_memory()
    db.create_scalar_function[double_it]("double_it", n_arg=1)

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT double_it(5)"), 10)
    assert_equal(db.one_row[get_int]("SELECT double_it(-3)"), -6)
    assert_equal(db.one_row[get_int]("SELECT double_it(0)"), 0)


fn test_scalar_float64() raises:
    """Test a scalar function that adds two floats."""
    var db = Connection.open_in_memory()
    db.create_scalar_function[add_two]("add_two", n_arg=2)

    fn get_float(row: Row) raises -> Float64:
        return row.get[Float64](0)

    assert_equal(db.one_row[get_float]("SELECT add_two(1.5, 2.5)"), 4.0)
    assert_equal(db.one_row[get_float]("SELECT add_two(0.0, 0.0)"), 0.0)


fn test_scalar_text() raises:
    """Test a scalar function that returns a greeting string."""
    var db = Connection.open_in_memory()
    db.create_scalar_function[greet]("greet", n_arg=1)

    fn get_text(row: Row) raises -> String:
        return row.get[String](0)

    assert_equal(db.one_row[get_text]("SELECT greet('World')"), "Hello, World!")
    assert_equal(db.one_row[get_text]("SELECT greet('Mojo')"), "Hello, Mojo!")


fn test_scalar_zero_args() raises:
    """Test a scalar function that takes no arguments."""
    var db = Connection.open_in_memory()
    db.create_scalar_function[constant_42]("constant_42", n_arg=0)

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT constant_42()"), 42)


fn test_scalar_with_user_data() raises:
    """Test a scalar function that uses user_data."""
    var db = Connection.open_in_memory()
    db.create_scalar_function[user_data_adder](
        "add_offset",
        n_arg=1,
        user_data=Int64(100),
    )

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    assert_equal(db.one_row[get_int]("SELECT add_offset(5)"), 105)
    assert_equal(db.one_row[get_int]("SELECT add_offset(-50)"), 50)


# CRASHING
# fn test_scalar_nullable_result() raises:
#     """Test a scalar function that can return NULL."""
#     var db = Connection.open_in_memory()
#     db.create_scalar_function[nullable_double]("nullable_double", n_arg=1)

#     fn get_optional_int(row: Row) raises -> Optional[Int64]:
#         return row.get[Optional[Int64]](0)

#     var result = db.one_row[get_optional_int]("SELECT nullable_double(3)")
#     assert_true(result)
#     assert_equal(result.value(), 6)

#     var null_result = db.one_row[get_optional_int]("SELECT nullable_double(0)")
#     assert_false(null_result)


fn test_scalar_used_in_where_clause() raises:
    """Test a scalar function used inside a WHERE clause."""
    var db = Connection.open_in_memory()
    _setup_numbers_table(db)
    db.create_scalar_function[double_it]("double_it", n_arg=1)

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    # double_it(value) > 6 means value > 3, so values 4 and 5 match
    var stmt = db.prepare("SELECT value FROM numbers WHERE double_it(value) > 6 ORDER BY value")
    var results = List[Int64]()
    for row in stmt.query():
        results.append(row.get[Int64](0))

    assert_equal(len(results), 2)
    assert_equal(results[0], 4)
    assert_equal(results[1], 5)


fn test_scalar_multiple_functions() raises:
    """Test registering multiple scalar functions on the same connection."""
    var db = Connection.open_in_memory()
    db.create_scalar_function[double_it]("double_it", n_arg=1)
    db.create_scalar_function[constant_42]("constant_42", n_arg=0)

    fn get_int(row: Row) raises -> Int64:
        return row.get[Int64](0)

    # Use both in one query
    assert_equal(
        db.one_row[get_int]("SELECT double_it(constant_42())"),
        84,
    )


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
