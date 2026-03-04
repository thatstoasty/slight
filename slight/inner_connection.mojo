from slight.c.api import sqlite_ffi
from slight.c.raw_bindings import sqlite3_connection, sqlite3_stmt
from slight.c.types import (
    AggFinalCallback,
    AggStepCallback,
    MutExternalPointer,
    MutUnsafePointer,
    WindowInverseCallback,
    WindowValueCallback,
    sqlite3_context,
    sqlite3_value,
)
from slight.types.to_sql import ToSQL
from slight.types.value_ref import (
    SQLite3Null,
    SQLite3Integer,
    SQLite3Real,
    SQLite3Text,
    SQLite3Blob,
    ValueRef,
)
from std.ffi import c_int
from std.pathlib import Path
from std.reflection import get_type_name
from std.sys import size_of

from slight.error import decode_error, error_msg, raise_if_error
from slight.flags import OpenFlag, PrepFlag
from slight.functions import Context, FunctionFlags
from slight.result import SQLite3Result


fn ptr_copy[T: Copyable & ImplicitlyDestructible](data: T) -> MutExternalPointer[T]:
    """Creates a copy of the value as a mutable external pointer.

    This is used to create a copy of the application data to pass to SQLite when creating user-defined functions.
    This data can be freed on demand by the destructor callback, and we don't have to worry
    about Mojo's ASAP destruction.

    Returns:
        A mutable external pointer containing a copy of the value.
    """
    var ptr = alloc[T](count=1)
    ptr[0] = data.copy()
    return ptr

fn _default_destructor(pApp: MutExternalPointer[NoneType]):
    """Default destructor for user-defined function application data.

    This function is used as the destructor callback when creating user-defined functions
    with application data. It checks if the provided pointer is valid and frees it if so.

    Args:
        pApp: A mutable external pointer to the application data.
    """
    if pApp:
        pApp.free()


# For scalar functions, SQLite requires xFunc to be non-NULL and
# xStep/xFinal to be NULL. We call the raw C API directly to pass
# NULL for the unused callbacks.
fn _call_scalar_callback[
    V: Movable & ImplicitlyDestructible, //,
    func: fn(Context) raises -> V
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) -> NoneType:
    """The xFunc callback for the scalar function.

    This is a wrapper around the user provided `func` that converts the raw C callback parameters
    into a `Context` object, calls the user's function, and then converts the result back to the appropriate SQLite type.
    This function matches the function signature expected by the C API.

    Parameters:
        V: The return type of the scalar function, which must conform to `ToSQL`.
        func: The user-provided function to be called for the scalar function.

    Args:
        ctx: The SQLite context for the function call.
        argc: The number of arguments passed to the function.
        argv: The arguments passed to the function.
    """
    # Convert raw C callback to our Context wrapper and call the user-provided function
    var context = Context(ctx, argc, argv)
    
    var fn_result: V
    try:
        fn_result = func(context)
    except e:
        # If the user's function raises an error, we need to convert it to a SQLite error result.
        context.result_error(t"Error in scalar function: {e}")
        return
    
    var result: ValueRef[origin_of(fn_result)]
    try:
        result = trait_downcast[ToSQL](fn_result).to_sql()
    except e:
        context.result_error(t"Error converting result to SQL: {e}")
        return
    
    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    if result.isa[SQLite3Null]():
        context.result_null()
    elif result.isa[SQLite3Integer]():
        context.result_int64(result[SQLite3Integer].value)
    elif result.isa[SQLite3Real]():
        context.result_double(result[SQLite3Real].value)
    elif result.isa[SQLite3Text[origin_of(result)]]():
        context.result_text(String(result[SQLite3Text[origin_of(result)]].value))
    else:
        context.result_error("Unsupported return type from scalar function.")
        return
    return


fn _call_step_callback[
    A: Movable & ImplicitlyDestructible,
    //,
    init_fn: fn(mut ctx: Context) raises -> A,
    step_fn: fn(mut ctx: Context, mut acc: A) raises,
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) -> NoneType:
    """The xStep callback for the aggregate function.

    This is called once for each row in the group being aggregated. This is a wrapper
    around the user provided `init_fn` and `step_fn` that manages the aggregate context for the user.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is initialized by `init_fn` and updated by `step_fn`.
        init_fn: The user-provided function to initialize the aggregate context on the first call.
        step_fn: The user-provided function to update the aggregate context on each call.

    Args:
        ctx: The SQLite context for the aggregate function.
        argc: The number of arguments passed to the function.
        argv: The arguments passed to the function.
    """
    var context = Context(ctx, argc, argv)
    var agg_context = context.aggregate_context[A](size_of[A]())
    # TODO: Throw sqlite3_result_error_nomem if we fail to allocate memory for the aggregate context.
    if not agg_context:
        var agg_context_ptr = alloc[A](count=1)
        try:
            agg_context_ptr[0] = init_fn(context)
        except e:
            # If the user's init function raises an error, we need to convert it to a SQLite error result.
            context.result_error(t"Error in aggregate init function: {e}")
            return
        agg_context = Optional(agg_context_ptr)

    try:
        step_fn(context, agg_context.value()[])
    except e:
        context.result_error(t"Error in aggregate step function: {e}")
        return
    return


fn _call_final_callback[
    A: Movable & ImplicitlyDestructible,
    T: Movable & ImplicitlyDestructible,
    //,
    final_fn: fn(mut ctx: Context, acc: A) raises -> T,
](ctx: MutExternalPointer[sqlite3_context]) -> NoneType:
    """The xFinal callback for the aggregate function.

    This is called once at the end of the aggregation to compute the final result. This is a wrapper
    around the user provided `final_fn` that manages the aggregate context for the user and converts
    the result to the appropriate SQLite type.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `final_fn`.
        T: The return type of the final function, which must conform to `ToSQL`.
        final_fn: The user-provided function to compute the final result from the aggregate context.

    Args:
        ctx: The SQLite context for the aggregate function.
    """
    var context = Context(ctx)
    var agg_context = context.aggregate_context[A](0)
    if not agg_context:
        context.result_error_nomem()
        return

    var finalize_result: T
    try:
        finalize_result = final_fn(context, agg_context.value()[])
    except e:
        # If the user's final function raises an error, we need to convert it to a SQLite error result.
        context.result_error(t"Error in aggregate final function: {e}")
        return

    var result: ValueRef[origin_of(finalize_result)]
    try:
        result = trait_downcast[ToSQL](finalize_result).to_sql()
    except e:
        context.result_error(t"Error converting final result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    # ToSQL is implemented on most of the important stdlib types.
    if result.isa[SQLite3Null]():
        context.result_null()
    elif result.isa[SQLite3Integer]():
        context.result_int64(result[SQLite3Integer].value)
    elif result.isa[SQLite3Real]():
        context.result_double(result[SQLite3Real].value)
    elif result.isa[SQLite3Text[origin_of(result)]]():
        context.result_text(String(result[SQLite3Text[origin_of(result)]].value))
    else:
        context.result_error("Unsupported return type from scalar function.")
        return

    return


fn _call_value_callback[
    T: Movable & ImplicitlyDestructible,
    A: Copyable & ImplicitlyDestructible, //, value_fn: fn(acc: Optional[A]) raises -> T
](ctx: MutExternalPointer[sqlite3_context]) -> NoneType:
    """The xValue callback for the window function.

    This is called to compute the current value of the window function without finalizing, for use in window frames.
    This function matches the function signature expected by the C API.

    Parameters:
        T: The return type of the value function, which must conform to `ToSQL`.
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `value_fn`.
        value_fn: The user-provided function to compute the current value from the aggregate context for window functions.

    Args:
        ctx: The SQLite context for the window function.
    """
    var context = Context(ctx)
    # Set n_bytes to 0 so no unneccessary allocations occur
    var agg_context = context.aggregate_context[A](0)
    if not agg_context:
        context.result_error_nomem()
        return

    var value_result: T
    try:
        value_result = value_fn(agg_context.value()[].copy())
    except e:
        context.result_error(t"Error in window function value callback: {e}")
        return

    var result: ValueRef[origin_of(value_result)]
    try:
        result = trait_downcast[ToSQL](value_result).to_sql()
    except e:
        context.result_error(t"Error converting window function value result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    # ToSQL is implemented on most of the important stdlib types.
    if result.isa[SQLite3Null]():
        context.result_null()
    elif result.isa[SQLite3Integer]():
        context.result_int64(result[SQLite3Integer].value)
    elif result.isa[SQLite3Real]():
        context.result_double(result[SQLite3Real].value)
    elif result.isa[SQLite3Text[origin_of(result)]]():
        context.result_text(String(result[SQLite3Text[origin_of(result)]].value))
    else:
        context.result_error("Unsupported return type from value function.")
        return

    return

fn _call_inverse_callback[
    A: Movable & ImplicitlyDestructible, //, inverse_fn: fn(mut ctx: Context, mut acc: A) raises
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) -> NoneType:
    """The `xInverse` callback for user defined window function.

    This is called when a row leaves the window frame, to update the aggregate context accordingly.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `inverse_fn`.
        inverse_fn: The user-provided function to update the aggregate context when a row leaves the window frame for window functions.

    Args:
        ctx: The SQLite context for the window function.
        argc: The number of arguments passed to the function.
        argv: The arguments passed to the function.
    """
    var context = Context(ctx, argc, argv)
    var agg_context = context.aggregate_context[A](0)
    if not agg_context:
        context.result_error_nomem()
        return

    try:
        inverse_fn(context, agg_context.value()[])
    except e:
        context.result_error(t"Error in window function inverse callback: {e}")
        return
    return


@explicit_destroy("InnerConnection must be explicitly destroyed. Use self.close() to destroy.")
struct InnerConnection(Movable):
    """A connection to a SQLite3 database."""

    var db: MutExternalPointer[sqlite3_connection]
    """A pointer to the underlying sqlite3 connection. This is managed by the InnerConnection and should not be accessed directly."""

    # TODO: Enable zVfs support in the future.
    fn __init__(out self, var path: String, flags: OpenFlag) raises:
        """Open a SQLite3 database connection with default flags.

        Args:
            path: The file path to the SQLite database.
            flags: The flags to use when opening the database.

        Returns:
            A new wrapper connection around an open sqlite3 connection.

        Raises:
            Will return an `Error` if the underlying SQLite open call fails.
        """
        var ptr = MutExternalPointer[sqlite3_connection]()
        var result = sqlite_ffi()[].open_v2(path, UnsafePointer(to=ptr), flags.value, None)
        if result != SQLite3Result.OK:
            raise Error("Could not open database: ", String(result))
        self.db = ptr

    @doc_private
    fn __init__(out self):
        """Creates an empty InnerConnection.

        Returns:
            A new `InnerConnection` instance.
        """
        self.db = MutExternalPointer[sqlite3_connection]()

    fn __init__(out self, db: MutExternalPointer[sqlite3_connection]):
        """Creates a new `InnerConnection` from an existing `sqlite3_connection` pointer.

        Args:
            db: An existing `sqlite3_connection` pointer.

        Returns:
            A new `InnerConnection` instance.
        """
        self.db = db

    fn __bool__(self) -> Bool:
        """Returns whether the connection is open.

        Returns:
            Whether the pointer to the sqlite3 connection is valid or not.
        """
        return Bool(self.db)

    fn is_autocommit(self) -> Bool:
        """Returns whether the connection is in auto-commit mode.

        Returns:
            True if the connection is in auto-commit mode, False otherwise.
        """
        return sqlite_ffi()[].get_autocommit(self.db)

    fn is_busy(self) -> Bool:
        """Returns whether the connection is currently busy.

        Returns:
            True if the connection is busy, False otherwise.
        """
        var stmt = sqlite_ffi()[].next_stmt(self.db, MutExternalPointer[sqlite3_stmt]())
        while stmt:
            if sqlite_ffi()[].stmt_busy(stmt) != 0:
                return True
            stmt = sqlite_ffi()[].next_stmt(self.db, stmt)
        return False

    fn close(deinit self) -> SQLite3Result:
        """Closes the underlying sqlite3 connection.

        Returns:
            The SQLite3Result code from the close operation.
        """
        if not self.db:
            return SQLite3Result.OK

        return sqlite_ffi()[].close(self.db)

    fn changes(self) -> Int64:
        """Returns the number of rows changed by the last INSERT, UPDATE, or DELETE statement.

        Returns:
            The number of rows changed.
        """
        return sqlite_ffi()[].changes64(self.db)

    fn total_changes(self) -> Int64:
        """Returns the total number of changes made to the database.

        Returns:
            The total number of changes.
        """
        return sqlite_ffi()[].total_changes64(self.db)

    fn last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row.

        Returns:
            The row ID of the last inserted row.
        """
        return sqlite_ffi()[].last_insert_rowid(self.db)

    fn prepare(
        self, var sql: String, flags: PrepFlag = PrepFlag.PREPARE_PERSISTENT
    ) raises -> Tuple[MutExternalPointer[sqlite3_stmt], UInt]:
        """Prepares an SQL statement for execution.

        Args:
            sql: The SQL statement to prepare.
            flags: The flags to use when preparing the statement.

        Returns:
            A tuple containing a pointer to the prepared statement and the length of the remaining unused SQL text.

        Raises:
            Will return an `Error` if the underlying SQLite prepare call fails.
        """
        var stmt = MutExternalPointer[sqlite3_stmt]()
        var str = sql.as_c_string_slice().unsafe_ptr()
        var c_tail = UnsafePointer(to=str)

        try:
            self.raise_if_error(
                sqlite_ffi()[].prepare_v3(self.db, str, Int32(len(sql)), flags.value, stmt, c_tail),
            )
        except e:
            if stmt:
                _ = sqlite_ffi()[].finalize(stmt)
            raise e^

        var tail: UInt = 0
        var tail_len = len(StringSlice(unsafe_from_utf8_ptr=c_tail[]))
        if tail_len > 0:
            var n = len(sql) - tail_len

            # Somehow the remaining tail is negative, or is longer than the original sql. Set to 0.
            if n <= 0 or n >= len(sql):
                tail = 0
            else:
                tail = UInt(n)
        return stmt, tail

    fn path(self) -> Optional[Path]:
        """Returns the file path of the database.

        Returns:
            The file path of the database, or None if the database is in-memory.
        """
        var db_name = "main"
        var path = sqlite_ffi()[].db_filename(self.db, db_name)
        if not path:
            return None

        return Path(StringSlice(unsafe_from_utf8_ptr=path))

    fn is_database_read_only(self, var database: String) raises -> Bool:
        """Checks if the specified database is opened in read-only mode.

        Args:
            database: The name of the database (e.g., "main", "temp").

        Returns:
            True if the database is read-only, False otherwise.

        Raises:
            Error: If the database name is invalid or if there is an error checking the database mode.
        """
        var result = sqlite_ffi()[].db_readonly(self.db, database)
        if result == SQLite3Result.OK:
            return True
        elif result == SQLite3Result.ERROR:
            return False
        elif result.value == -1:
            raise Error(t"SQLITE_MISUSE: The given database name is not valid: {database}")
        else:
            raise Error(t"Unexpected result from sqlite3_db_readonly: {result}")

    fn raise_if_error(self, code: SQLite3Result) raises:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Raises:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        raise_if_error(self.db, code)

    fn error_msg(self, code: SQLite3Result) -> Optional[String]:
        """Checks for the error message set in sqlite3, or what the description of the provided code is.

        Args:
            code: The SQLite error code.

        Returns:
            An optional string slice containing the error message, or None if not found.
        """
        return error_msg(self.db, code)

    fn decode_error(self, code: SQLite3Result) -> Error:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Returns:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        return decode_error(self.db, code)

    # TODO: V should be constrained to ToSQL, but I want to keep extensions private from users for now.
    fn create_scalar_function[
        T: Copyable & ImplicitlyDestructible,
        V: Movable & ImplicitlyDestructible, //,
        x_func: fn(Context) raises -> V
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags, pApp: T) raises -> SQLite3Result:
        """Attach a user-defined scalar function to a database connection.

        The function will remain available until the connection is closed or
        until it is explicitly removed via `remove_function`.

        For scalar functions, only `x_func` is used. The xStep and xFinal
        callbacks are set to NULL internally, as required by SQLite.

        `slight` **creates a copy of `pApp`** to pass to SQLite, so the caller retains ownership of the original `pApp` value
        and is responsible for its lifecycle. The copied value is automatically freed using a default destructor
        when the function is removed or when the connection is closed.

        Parameters:
            T: The type of the application data to be passed to the callback.
            V: The return type of the scalar function, which must conform to `ToSQL`.
            x_func: The scalar function callback implementation.

        Args:
            fn_name: Name of the SQL function to create.
            n_arg: Number of arguments the function accepts (-1 for variable number).
            flags: Function flags (encoding, determinism, etc.).
            pApp: An optional pointer to application data that will be passed to the callback.

        Returns:
            The SQLite3Result code from the create function operation.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(V, ToSQL), String(
            t"Return type V must conform to `ToSQL` trait. {get_type_name[V]()} does not implement `ToSQL`."
        )

        # Copy data to the heap and pass a pointer to it as pApp.
        # The data will be freed using the default destructor when the function is removed or when the connection is closed.
        var pAppPtr = ptr_copy(pApp)
        return sqlite_ffi()[].create_scalar_function(
            self.db,
            fn_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.bitcast[NoneType](),
            _call_scalar_callback[x_func],
            _default_destructor,
        )

    fn create_scalar_function[
        V: Movable & ImplicitlyDestructible, //, x_func: fn(Context) raises -> V
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags,) raises -> SQLite3Result:
        """Attach a user-defined scalar function to a database connection.

        The function will remain available until the connection is closed or
        until it is explicitly removed via `remove_function`.

        For scalar functions, only `x_func` is used. The xStep and xFinal
        callbacks are set to NULL internally, as required by SQLite.

        Parameters:
            V: The return type of the scalar function, which must conform to `ToSQL`.
            x_func: The scalar function callback implementation.

        Args:
            fn_name: Name of the SQL function to create.
            n_arg: Number of arguments the function accepts (-1 for variable number).
            flags: Function flags (encoding, determinism, etc.).

        Returns:
            The SQLite3Result code from the create function operation.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(V, ToSQL), String(
            t"Return type V must conform to `ToSQL` trait. {get_type_name[V]()} does not implement `ToSQL`."
        )
        return sqlite_ffi()[].create_scalar_function(
            self.db,
            fn_name,
            c_int(n_arg),
            flags.value,
            _call_scalar_callback[x_func],
        )

    fn create_aggregate_function[
        A: Movable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        P: Copyable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags, pApp: P,) raises -> SQLite3Result:
        """Attach a user-defined aggregate function to a database connection.

        Aggregate functions process multiple rows and produce a single result.
        The `x_step` callback is called once per row, and `x_final` is called
        once at the end to produce the result.

        Use `FunctionContext.aggregate_context()` inside the callbacks to manage
        per-group state.

        Parameters:
            A: The type of the aggregate state.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            P: The type of the application data to be passed to the callbacks.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            flags: Function flags.
            pApp: An optional pointer to application data that will be passed to the callbacks.

        Returns:
            The SQLite3Result code from the create function operation.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(T, ToSQL), String(
            t"Return type T must conform to `ToSQL` trait. {get_type_name[T]()} does not implement `ToSQL`."
        )

        # Copy data to the heap and pass a pointer to it as pApp.
        # The data will be freed using the default destructor when the function is removed or when the connection is closed.
        var pAppPtr = ptr_copy(pApp)
        return sqlite_ffi()[].create_aggregate_function(
            self.db,
            fn_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.bitcast[NoneType](),
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
            _default_destructor,
        )

    fn create_aggregate_function[
        A: Movable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags,) raises -> SQLite3Result:
        """Attach a user-defined aggregate function to a database connection.

        Aggregate functions process multiple rows and produce a single result.
        The `x_step` callback is called once per row, and `x_final` is called
        once at the end to produce the result.

        Use `FunctionContext.aggregate_context()` inside the callbacks to manage
        per-group state.

        Parameters:
            A: The type of the aggregate state.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            flags: Function flags.

        Returns:
            The SQLite3Result code from the create function operation.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(T, ToSQL), String(
            t"Return type T must conform to `ToSQL` trait. {get_type_name[T]()} does not implement `ToSQL`."
        )
        return sqlite_ffi()[].create_aggregate_function(
            self.db,
            fn_name,
            c_int(n_arg),
            flags.value,
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
        )

    fn create_window_function[
        A: Copyable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        P: Copyable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
        value_fn: fn(acc: Optional[A]) raises -> T,
        inverse_fn: fn(mut ctx: Context, mut acc: A) raises,
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags, pApp: P,) raises -> SQLite3Result:
        """Attach a user-defined aggregate function to a database connection.

        Aggregate functions process multiple rows and produce a single result.
        The `x_step` callback is called once per row, and `x_final` is called
        once at the end to produce the result.

        Use `FunctionContext.aggregate_context()` inside the callbacks to manage
        per-group state.

        Parameters:
            A: The type of the aggregate state.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            P: The type of the application data to be passed to the callbacks.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.
            value_fn: The callback to compute the current value of the window function without finalizing (for use in window frames).
            inverse_fn: The callback to update the aggregate state when a row is removed from a window.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            flags: Function flags.
            pApp: An optional pointer to application data that will be passed to the callbacks.

        Returns:
            The SQLite3Result code from the create function operation.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(T, ToSQL), String(
            t"Return type T must conform to `ToSQL` trait. {get_type_name[T]()} does not implement `ToSQL`."
        )

        # Copy data to the heap and pass a pointer to it as pApp.
        # The data will be freed using the default destructor when the function is removed or when the connection is closed.
        var pAppPtr = ptr_copy(pApp)
        return sqlite_ffi()[].create_window_function(
            self.db,
            fn_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.bitcast[NoneType](),
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
            _call_value_callback[value_fn],
            _call_inverse_callback[inverse_fn],
            _default_destructor,
        )

    fn create_window_function[
        A: Copyable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
        value_fn: fn(acc: Optional[A]) raises -> T,
        inverse_fn: fn(mut ctx: Context, mut acc: A) raises,
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags,) raises -> SQLite3Result:
        """Attach a user-defined aggregate function to a database connection.

        Aggregate functions process multiple rows and produce a single result.
        The `x_step` callback is called once per row, and `x_final` is called
        once at the end to produce the result.

        Use `FunctionContext.aggregate_context()` inside the callbacks to manage
        per-group state.

        Parameters:
            A: The type of the aggregate state.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.
            value_fn: The callback to compute the current value of the window function without finalizing (for use in window frames).
            inverse_fn: The callback to update the aggregate state when a row is removed from a window.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            flags: Function flags.

        Returns:
            The SQLite3Result code from the create function operation.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(T, ToSQL), String(
            t"Return type T must conform to `ToSQL` trait. {get_type_name[T]()} does not implement `ToSQL`."
        )
        return sqlite_ffi()[].create_window_function(
            self.db,
            fn_name,
            c_int(n_arg),
            flags.value,
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
            _call_value_callback[value_fn],
            _call_inverse_callback[inverse_fn],
        )
