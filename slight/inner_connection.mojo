from std.ffi import c_char, c_int
from std.pathlib import Path
from std.reflection import get_type_name
from slight.busy import BusyHandlerFn, _busy_handler_callback
from slight.c.api import sqlite_ffi
from slight.c.raw_bindings import sqlite3_connection, sqlite3_stmt
from slight.trace import TraceFn, TraceEventCodes, _trace_v2_callback
from slight.unlock_notify import (
    is_locked,
    wait_for_unlock_notify,
)
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
from slight.limits import Limit
from slight.functions import (
    ScalarUDF,
    AggregateInitUDF,
    AggregateStepUDF,
    AggregateFinalUDF,
    WindowAggregateValueUDF,
    WindowAggregateInverseUDF,
)
from slight.types.to_sql import ToSQL
from slight.error import decode_error, error_msg, error_from_sqlite_code, raise_if_error
from slight.functions import (
    _call_scalar_callback,
    _call_step_callback,
    _call_final_callback,
    _call_value_callback,
    _call_inverse_callback,
    _default_destructor,
)
from slight.flags import OpenFlag, PrepFlag
from slight.functions import FunctionFlags
from slight.context import Context
from slight.result import SQLite3Result
from slight.util import CopyDestructible, MoveDestructible


def ptr_copy[T: CopyDestructible](data: T) -> MutExternalPointer[T]:
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


@explicit_destroy("InnerConnection must be explicitly destroyed. Use self.close() to destroy.")
struct InnerConnection(Movable):
    """A connection to a SQLite3 database."""

    var db: MutExternalPointer[sqlite3_connection]
    """A pointer to the underlying sqlite3 connection. This is managed by the InnerConnection and should not be accessed directly."""

    # TODO: Enable zVfs support in the future.
    def __init__(out self, var path: String, flags: OpenFlag) raises:
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

    def __init__(out self):
        """Creates an empty InnerConnection.

        Returns:
            A new `InnerConnection` instance.
        """
        self.db = MutExternalPointer[sqlite3_connection]()

    def __init__(out self, db: MutExternalPointer[sqlite3_connection]):
        """Creates a new `InnerConnection` from an existing `sqlite3_connection` pointer.

        Args:
            db: An existing `sqlite3_connection` pointer.

        Returns:
            A new `InnerConnection` instance.
        """
        self.db = db

    def __bool__(self) -> Bool:
        """Returns whether the connection is open.

        Returns:
            Whether the pointer to the sqlite3 connection is valid or not.
        """
        return Bool(self.db)

    def is_autocommit(self) -> Bool:
        """Returns whether the connection is in auto-commit mode.

        Returns:
            True if the connection is in auto-commit mode, False otherwise.
        """
        return sqlite_ffi()[].get_autocommit(self.db)

    def is_busy(self) -> Bool:
        """Returns whether the connection is currently busy.

        Returns:
            True if the connection is busy, False otherwise.
        """
        var stmt = sqlite_ffi()[].next_stmt(self.db, MutExternalPointer[sqlite3_stmt]())
        while stmt:
            if sqlite_ffi()[].stmt_busy(stmt):
                return True
            stmt = sqlite_ffi()[].next_stmt(self.db, stmt)
        return False

    def close(deinit self) -> SQLite3Result:
        """Closes the underlying sqlite3 connection.

        Returns:
            The SQLite3Result code from the close operation.
        """
        if not self.db:
            return SQLite3Result.OK

        return sqlite_ffi()[].close(self.db)

    def changes(self) -> Int64:
        """Returns the number of rows changed by the last INSERT, UPDATE, or DELETE statement.

        Returns:
            The number of rows changed.
        """
        return sqlite_ffi()[].changes64(self.db)

    def total_changes(self) -> Int64:
        """Returns the total number of changes made to the database.

        Returns:
            The total number of changes.
        """
        return sqlite_ffi()[].total_changes64(self.db)

    def last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row.

        Returns:
            The row ID of the last inserted row.
        """
        return sqlite_ffi()[].last_insert_rowid(self.db)

    def prepare(
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
                sqlite_ffi()[].prepare_v3(self.db, str, Int32(sql.byte_length()), flags.value, stmt, c_tail),
            )
        except e:
            if stmt:
                _ = sqlite_ffi()[].finalize(stmt)
            raise e^

        var tail: UInt = 0
        var tail_len = StringSlice(unsafe_from_utf8_ptr=c_tail[]).byte_length()
        if tail_len > 0:
            var n = sql.byte_length() - tail_len

            # Somehow the remaining tail is negative, or is longer than the original sql. Set to 0.
            if n <= 0 or n >= sql.byte_length():
                tail = 0
            else:
                tail = UInt(n)
        return stmt, tail

    def path(self) -> Optional[Path]:
        """Returns the file path of the database.

        Returns:
            The file path of the database, or None if the database is in-memory.
        """
        var db_name = "main"
        var path = sqlite_ffi()[].db_filename(self.db, db_name)
        if not path:
            return None

        return Path(StringSlice(unsafe_from_utf8_ptr=path))

    def is_database_read_only(self, var database: String) raises -> Bool:
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

    def raise_if_error(self, code: SQLite3Result) raises:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Raises:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        raise_if_error(self.db, code)

    def error_msg(self, code: SQLite3Result) -> Optional[String]:
        """Checks for the error message set in sqlite3, or what the description of the provided code is.

        Args:
            code: The SQLite error code.

        Returns:
            An optional string slice containing the error message, or None if not found.
        """
        return error_msg(self.db, code)

    def decode_error(self, code: SQLite3Result) -> Error:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Returns:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        return decode_error(self.db, code)

    # TODO: V should be constrained to ToSQL, but I want to keep extensions private from users for now.
    def create_scalar_function[
        T: CopyDestructible,
        V: MoveDestructible, //,
        x_func: ScalarUDF[V],
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags, pApp: T) -> SQLite3Result:
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

    def create_scalar_function[
        V: MoveDestructible, //, x_func: ScalarUDF[V]
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags,) -> SQLite3Result:
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

    def create_aggregate_function[
        A: MoveDestructible,
        T: MoveDestructible,
        P: CopyDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags, pApp: P) -> SQLite3Result:
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

    def create_aggregate_function[
        A: MoveDestructible,
        T: MoveDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
    ](self, fn_name: String, n_arg: Int, flags: FunctionFlags,) -> SQLite3Result:
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

    # def create_window_function[
    #     A: CopyDestructible,
    #     T: MoveDestructible,
    #     P: CopyDestructible,
    #     //,
    #     init_fn: AggregateInitUDF[A],
    #     step_fn: AggregateStepUDF[A],
    #     final_fn: AggregateFinalUDF[A, T],
    #     value_fn: WindowAggregateValueUDF[A, T],
    #     inverse_fn: WindowAggregateInverseUDF[A],
    # ](self, fn_name: String, n_arg: Int, flags: FunctionFlags, pApp: P) -> SQLite3Result:
    #     """Attach a user-defined aggregate function to a database connection.

    #     Aggregate functions process multiple rows and produce a single result.
    #     The `x_step` callback is called once per row, and `x_final` is called
    #     once at the end to produce the result.

    #     Use `FunctionContext.aggregate_context()` inside the callbacks to manage
    #     per-group state.

    #     Parameters:
    #         A: The type of the aggregate state.
    #         T: The return type of the aggregate function. Must conform to `ToSQL`.
    #         P: The type of the application data to be passed to the callbacks.
    #         init_fn: The callback to initialize the aggregate state for a new group.
    #         step_fn: The callback to update the aggregate state for each row in the group.
    #         final_fn: The callback to compute the final result from the aggregate state.
    #         value_fn: The callback to compute the current value of the window function without finalizing (for use in window frames).
    #         inverse_fn: The callback to update the aggregate state when a row is removed from a window.

    #     Args:
    #         fn_name: Name of the SQL aggregate function to create.
    #         n_arg: Number of arguments (-1 for variable number).
    #         flags: Function flags.
    #         pApp: An optional pointer to application data that will be passed to the callbacks.

    #     Returns:
    #         The SQLite3Result code from the create function operation.
    #     """
    #     comptime assert conforms_to(T, ToSQL), String(
    #         t"Return type T must conform to `ToSQL` trait. {get_type_name[T]()} does not implement `ToSQL`."
    #     )

    #     # Copy data to the heap and pass a pointer to it as pApp.
    #     # The data will be freed using the default destructor when the function is removed or when the connection is closed.
    #     var pAppPtr = ptr_copy(pApp)
    #     return sqlite_ffi()[].create_window_function(
    #         self.db,
    #         fn_name,
    #         c_int(n_arg),
    #         flags.value,
    #         pAppPtr.bitcast[NoneType](),
    #         _call_step_callback[init_fn, step_fn],
    #         _call_final_callback[final_fn],
    #         _call_value_callback[value_fn],
    #         _call_inverse_callback[inverse_fn],
    #         _default_destructor,
    #     )

    # def create_window_function[
    #     A: CopyDestructible,
    #     T: MoveDestructible,
    #     //,
    #     init_fn: AggregateInitUDF[A],
    #     step_fn: AggregateStepUDF[A],
    #     final_fn: AggregateFinalUDF[A, T],
    #     value_fn: WindowAggregateValueUDF[A, T],
    #     inverse_fn: WindowAggregateInverseUDF[A],
    # ](self, fn_name: String, n_arg: Int, flags: FunctionFlags,) -> SQLite3Result:
    #     """Attach a user-defined aggregate function to a database connection.

    #     Aggregate functions process multiple rows and produce a single result.
    #     The `x_step` callback is called once per row, and `x_final` is called
    #     once at the end to produce the result.

    #     Use `FunctionContext.aggregate_context()` inside the callbacks to manage
    #     per-group state.

    #     Parameters:
    #         A: The type of the aggregate state.
    #         T: The return type of the aggregate function. Must conform to `ToSQL`.
    #         init_fn: The callback to initialize the aggregate state for a new group.
    #         step_fn: The callback to update the aggregate state for each row in the group.
    #         final_fn: The callback to compute the final result from the aggregate state.
    #         value_fn: The callback to compute the current value of the window function without finalizing (for use in window frames).
    #         inverse_fn: The callback to update the aggregate state when a row is removed from a window.

    #     Args:
    #         fn_name: Name of the SQL aggregate function to create.
    #         n_arg: Number of arguments (-1 for variable number).
    #         flags: Function flags.

    #     Returns:
    #         The SQLite3Result code from the create function operation.
    #     """
    #     comptime assert conforms_to(T, ToSQL), String(
    #         t"Return type T must conform to `ToSQL` trait. {get_type_name[T]()} does not implement `ToSQL`."
    #     )
    #     return sqlite_ffi()[].create_window_function(
    #         self.db,
    #         fn_name,
    #         c_int(n_arg),
    #         flags.value,
    #         _call_step_callback[init_fn, step_fn],
    #         _call_final_callback[final_fn],
    #         _call_value_callback[value_fn],
    #         _call_inverse_callback[inverse_fn],
    #     )

    def remove_function(
        self,
        fn_name: String,
        n_arg: Int,
    ) -> SQLite3Result:
        """Remove a user-defined function from a database connection.

        `fn_name` and `n_arg` should match the name and number of arguments
        given to `create_scalar_function`, `create_aggregate_function`, or
        `create_window_function`.

        Args:
            fn_name: Name of the SQL function to remove.
            n_arg: Number of arguments the function was registered with.
        """
        # To delete a function, pass NULL for all callbacks and pApp,
        # with UTF8 encoding.
        var func_name = fn_name.copy()
        return sqlite_ffi()[].remove_function(
            self.db,
            func_name,
            c_int(n_arg),
        )

    def busy_timeout(self, ms: c_int) -> SQLite3Result:
        """Set a busy handler that sleeps for a specified amount of time when a
        table is locked.

        The handler will sleep multiple times until at least `ms` milliseconds
        of sleeping have accumulated. Calling this with an argument less than
        or equal to zero turns off all busy handlers.

        Args:
            ms: Maximum time to wait in milliseconds.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return sqlite_ffi()[].busy_timeout(self.db, ms)

    def busy_handler[callback: Optional[BusyHandlerFn]](
        self,
    ) -> SQLite3Result:
        """Register a callback to handle `SQLITE_BUSY` errors.

        If `callback` is `None`, then the busy handler is cleared and
        `SQLITE_BUSY` is returned immediately upon encountering a lock.
        Otherwise, the callback is invoked with the number of prior retries.
        Return `True` from the callback to retry, `False` to stop.

        There can only be a single busy handler per database connection.
        Setting a new busy handler clears any previously set handler.
        Calling `busy_timeout()` also clears any custom busy handler.

        Parameters:
            callback: A function `def(Int32) -> Bool`, or `None` to clear.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        comptime if callback:
            var fn_val = callback.value()
            var fn_ptr = UnsafePointer(to=fn_val).bitcast[NoneType]()
            return sqlite_ffi()[].busy_handler(
                self.db,
                _busy_handler_callback,
                fn_ptr,
            )
        else:
            # Passing timeout=0 clears all busy handlers (per SQLite docs).
            return sqlite_ffi()[].busy_timeout(self.db, 0)

    def limit(self, limit: Limit) -> Int32:
        """Returns the current value of a run-time limit.

        Passing -1 as the second argument to `sqlite3_limit` queries the
        current value without changing it.

        Args:
            limit: The limit category to query.

        Returns:
            The current value of the limit, or -1 if the limit category is
            invalid.
        """
        return sqlite_ffi()[].limit(self.db, c_int(limit.value), c_int(-1))

    def set_limit(self, limit: Limit, new_val: Int32) -> Int32:
        """Changes a run-time limit, returning the prior value.

        Args:
            limit: The limit category to change.
            new_val: The new value for the limit.

        Returns:
            The previous value of the limit, or -1 if the limit category is
            invalid.
        """
        return sqlite_ffi()[].limit(self.db, c_int(limit.value), c_int(new_val))

    def trace_v2[callback: Optional[TraceFn]](
        self,
        mask: TraceEventCodes,
    ) -> SQLite3Result:
        """Register or clear a trace callback (version 2).

        If `callback` is `None`, tracing is disabled. Otherwise the callback
        is invoked for each event type selected by `mask`.

        Parameters:
            callback: An optional trace callback function. If None, tracing is disabled.

        Args:
            mask: Bitmask of `TraceEventCodes` to monitor.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        comptime if callback:
            var fn_val = callback.value()
            # Transmute: store def pointer VALUE as the void pointer address
            # (same as Rust's `f as *mut c_void`)
            var fn_as_int = UnsafePointer(to=fn_val).bitcast[Int]()[]
            var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
            return sqlite_ffi()[].trace_v2(
                    self.db,
                    mask.value,
                    _trace_v2_callback,
                    ctx,
                )
        else:
            # Passing a null callback disables tracing.
            return sqlite_ffi()[].trace_v2(
                    self.db,
                    UInt32(0),
                    _trace_v2_callback,
                    MutExternalPointer[NoneType](),
                )

    def log(self, err_code: Int32, mut msg: String):
        """Write a message to the SQLite error log.

        Args:
            err_code: An SQLite error code to associate with the message.
            msg: The log message text.
        """
        sqlite_ffi()[].log(c_int(err_code), msg)

    def set_extension_loading(mut self, *, enable: Bool) -> SQLite3Result:
        """Enable or disable the ability to load SQLite extensions.

        When extension loading is enabled, you can use `load_extension` to load
        shared libraries that implement SQLite extensions. For security reasons,
        extension loading is disabled by default.

        Args:
            enable: If True, enables extension loading. If False, disables it.
        """
        return sqlite_ffi()[].enable_load_extension(self.db, c_int(1 if enable else 0))

    def load_extension(mut self, dylib_path: Path, entry_point: Optional[String] = None) raises:
        """Load an SQLite extension library.

        Extension loading must be enabled via `set_extension_loading(enable=True)`
        before calling this function.

        Args:
            dylib_path: File path to the shared library containing the extension.
            entry_point: Name of the entry point function. If None, SQLite uses
                the default entry point.

        Raises:
            Error: If the extension cannot be loaded.
        """
        var path = String(dylib_path)
        var errmsg = MutExternalPointer[c_char]()
        var ep = entry_point.copy()
        var result = sqlite_ffi()[].load_extension(
            self.db, path, ep, errmsg,
        )
        if result == SQLite3Result.OK:
            return

        # Extract the error message returned by SQLite, then free it.
        var message: Optional[String] = None
        if errmsg:
            message = String(unsafe_from_utf8_ptr=errmsg)
            sqlite_ffi()[].free(errmsg.bitcast[NoneType]())

        raise Error(error_from_sqlite_code(result, message))

    def is_locked(self, rc: SQLite3Result) -> Bool:
        """Check whether a result code indicates shared-cache lock contention.

        Args:
            rc: The result code returned by a recent SQLite API call.

        Returns:
            True if the error is SQLITE_LOCKED due to shared-cache contention.
        """
        return is_locked(self.db, rc)

    def wait_for_unlock_notify(self) -> SQLite3Result:
        """Block until an unlock-notify callback fires, then return SQLITE_OK.

        Should only be called after a `SQLITE_LOCKED` result in shared-cache mode.
        If registering the notification would cause deadlock, returns SQLITE_LOCKED
        immediately; the caller should roll back the current transaction.

        Returns:
            SQLITE_OK when the lock is released, or an error code.
        """
        return wait_for_unlock_notify(self.db)

