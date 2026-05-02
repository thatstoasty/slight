from slight.functions import Context, FunctionFlags

from slight import Connection, Row


# TODO: Show what happens if an error is raised in one of the funcs.
def sum_init(mut ctx: Context) raises -> Int64:
    """Initialize the accumulator to 0."""
    return 0


def sum_step(mut ctx: Context, mut acc: Int64) raises:
    """Add the current row's first argument to the running sum."""
    acc += ctx.get_int64(0)


def sum_finalize(mut ctx: Context, acc: Int64) raises -> Optional[Int64]:
    """Return the final accumulated sum."""
    return acc


def sum_inverse(mut ctx: Context, mut acc: Int64) raises:
    """Subtract the current row's first argument from the running sum (for window functions)."""
    acc -= ctx.get_int64(0)


def sum_value(acc: Optional[Int64]) raises -> Optional[Int64]:
    """Return the current value of the accumulator (for window functions)."""
    return acc.copy()


def main() raises:
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
    conn.create_window_function[sum_init, sum_step, sum_finalize, sum_value, sum_inverse](
        "my_sum",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    )

    def get_row(row: Row) raises -> String:
        return String(t"{row.get[Int64](0)} | {row.get[Int64](1)}")

    # Use the window function with a sliding frame: running sum over the current
    # row and the one before it (ROWS BETWEEN 1 PRECEDING AND CURRENT ROW).
    var stmt = conn.prepare(
        """
        SELECT value,
               my_sum(value) OVER (ORDER BY value ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS running_sum
        FROM numbers
        """
    )
    print("value | running_sum")
    print("------+-----------")
    for row in stmt.query[get_row]():
        print(row)
    # Expected output:
    # value | running_sum
    # ------+-----------
    # 1 | 1
    # 2 | 3
    # 3 | 5
    # 4 | 7
    # 5 | 9
