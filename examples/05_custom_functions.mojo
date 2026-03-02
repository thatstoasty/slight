from std.ffi import c_int
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.functions import Context, FunctionFlags
from slight import Connection, Row


fn halve_impl_new(ctx: Context) raises:
    var value = ctx.get_double(0)
    ctx.result_double(value / 2.0)


fn main() raises:
    var app_data = "My app data"
    var conn = Connection.open_in_memory()
    conn.create_scalar_function[halve_impl_new](
        "halve",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
        pApp=app_data.unsafe_ptr_mut().bitcast[NoneType](),
    )

    fn get_result(row: Row) raises -> Float64:
        return row.get[Float64](0)

    print("Result:", conn.one_row[get_result]("SELECT halve(10.0)"))
