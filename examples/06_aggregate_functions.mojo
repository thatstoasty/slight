from slight.functions import Context, FunctionFlags

from slight import Connection, Row


# TODO: Show what happens if an error is raised in one of the funcs.
fn sum_init(mut ctx: Context) raises -> Int64:
    """Initialize the accumulator to 0."""
    return 0


fn sum_step(mut ctx: Context, mut acc: Int64) raises:
    """Add the current row's first argument to the running sum."""
    acc += ctx.get_int64(0)


fn sum_finalize(mut ctx: Context, acc: Int64) raises -> Int64:
    """Return the final accumulated sum."""
    return acc


fn main() raises:
    var conn = Connection.open_in_memory()

    # Set up a test table with some integer values.
    conn.execute_batch(
        """
        CREATE TABLE numbers (value INTEGER);
        INSERT INTO numbers VALUES (1);
        INSERT INTO numbers VALUES (2);
        INSERT INTO numbers VALUES (3);
        INSERT INTO numbers VALUES (4);
        INSERT INTO numbers VALUES (5);
        """
    )

    # Register the custom aggregate function.
    conn.create_aggregate_function[sum_init, sum_step, sum_finalize](
        "my_sum",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    )

    fn get_result(row: Row) raises -> Int64:
        return row.get[Int64](0)

    var result = conn.one_row[get_result]("SELECT my_sum(value) FROM numbers")
    print("Sum:", result)  # Expected: Sum: 15
