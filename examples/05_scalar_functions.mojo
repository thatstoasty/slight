from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.functions import Context, FunctionFlags
from std.ffi import c_int
from std.math import sqrt

from slight import Connection, Row


fn halve(ctx: Context) raises -> Float64:
    return ctx.get_double(0) / 2.0


fn halve_user_data(ctx: Context) raises -> Float64:
    var addend = ctx.user_data().bitcast[Float64]()[]
    return (ctx.get_double(0) / 2.0) + addend


fn mojo_sqrt(ctx: Context) raises -> Float64:
    return sqrt(ctx.get_double(0))

fn main() raises:
    var conn = Connection.open_in_memory()
    conn.create_scalar_function[halve](
        "halve",
        n_arg=1,
    )

    fn get_result(row: Row) raises -> Float64:
        return row.get[Float64](0)

    print("Result:", conn.one_row[get_result]("SELECT halve(10.0)"))

    conn.create_scalar_function[halve_user_data](
        "halve_user_data",
        n_arg=1,
        user_data=5.5
    )

    print("Result:", conn.one_row[get_result]("SELECT halve_user_data(10.0)"))

    conn.create_scalar_function[mojo_sqrt](
        "mojo_sqrt",
        n_arg=1,
    )

    print("Result:", conn.one_row[get_result]("SELECT mojo_sqrt(15.0)"))
