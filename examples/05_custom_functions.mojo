from std.ffi import c_int
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.functions import Context, FunctionFlags
from slight import Connection, Row


fn halve(ctx: Context) raises:
    var value = ctx.get_double(0)
    ctx.result_double(value / 2.0)


fn halve_user_data(ctx: Context) raises:
    var value = ctx.get_double(0)
    var addend = ctx.user_data().bitcast[Float64]()[]
    ctx.result_double((value / 2.0) + addend)

fn main() raises:
    var conn = Connection.open_in_memory()
    conn.create_scalar_function[halve](
        "halve",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    )

    fn get_result(row: Row) raises -> Float64:
        return row.get[Float64](0)

    print("Result:", conn.one_row[get_result]("SELECT halve(10.0)"))

    conn.create_scalar_function[halve_user_data](
        "halve_user_data",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
        pApp=5.5
    )

    print("Result:", conn.one_row[get_result]("SELECT halve_user_data(10.0)"))
