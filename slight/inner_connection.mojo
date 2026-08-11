"""SQLite Inner DB Connection."""
from std.ffi import c_char, c_int, CStringSlice
from std.memory.alloc import Allocation, dealloc
from std.pathlib import Path
from slight.c.types import (
    MutExternalPointer,
    sqlite3_module,
    AggFinalCallback,
    AggStepCallback,
    WindowInverseCallback,
    WindowValueCallback,
    CollationCompareCallbackFn,
    CommitHookCallbackFn,
    RollbackHookCallbackFn,
    UpdateHookCallbackFn,
    sqlite3_context,
    sqlite3_value,
    sqlite3_connection,
    sqlite3_stmt,
    sqlite3_backup,
    sqlite3_blob,
    SQLITE_DESERIALIZE_FREEONCLOSE,
    SQLITE_DESERIALIZE_READONLY,
    SQLITE_DESERIALIZE_RESIZEABLE,
)
from slight.checkpoint import CheckpointMode
from slight.blob import Blob
from slight.busy import BusyHandlerFn, _busy_handler_callback
from slight.api import sqlite_ffi
from slight.trace import TraceFn, TraceEventCodes, _trace_v2_callback
from slight.hooks import (
    CommitHookFn,
    RollbackHookFn,
    UpdateHookFn,
    _commit_hook_trampoline_ptr,
    _rollback_hook_trampoline_ptr,
    _update_hook_trampoline_ptr,
)
from slight.collation import (
    CollationCompareFn,
    _collation_compare_callback,
    _no_op_collation_destructor,
)
from slight.progress import ProgressHandlerFn, _progress_handler_callback
from slight.authorizer import AuthorizerFn, _authorizer_callback
from slight.unlock_notify import (
    is_locked,
    wait_for_unlock_notify,
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
    _typed_destructor,
)
from slight.flags import OpenFlag, PrepFlag
from slight.functions import FunctionFlags
from slight.context import Context
from slight.result import SQLite3Result
from slight.util import CopyDestructible, MoveDestructible, ptr_copy, str_slice_to_path
from slight.vtab import (
    VTabConnectFn,
    VTabBestIndexFn,
    VTabOpenFn,
    VTabFilterFn,
    VTabNextFn,
    VTabEofFn,
    VTabColumnFn,
    VTabRowidFn,
    make_read_only_module,
)


def _free_module(var module: Allocation[sqlite3_module]):
    """Free a `sqlite3_module` allocation owned by an `InnerConnection`.

    Args:
        module: The module allocation to free.
    """
    dealloc(module^)


@fieldwise_init
@explicit_destroy("InnerConnection must be explicitly destroyed. Use self.close() to destroy.")
struct InnerConnection(Deinitable where False, Movable):
    """A connection to a SQLite3 database."""

    var db: MutExternalPointer[sqlite3_connection]
    """A pointer to the underlying sqlite3 connection. This is managed by the InnerConnection and should not be accessed directly."""
    var modules: List[Allocation[sqlite3_module]]
    """Virtual table modules registered on this connection.

    SQLite only borrows the module pointers passed to `sqlite3_create_module_v2`,
    so the allocations are owned here and freed in `close()` once `sqlite3_close`
    has unregistered them."""

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
        var ptr = MutExternalPointer[sqlite3_connection].unsafe_dangling()
        var result = sqlite_ffi()[].open_v2(path, Pointer(to=ptr), flags.value, None)
        if result != SQLite3Result.OK:
            raise Error(t"Could not open database: {String(result)}")
        self.db = ptr
        self.modules = []

    def unsafe_ptr[
        origin: Origin, address_space: AddressSpace, //
    ](ref[origin, address_space] self) -> Pointer[sqlite3_connection, origin, address_space=address_space]:
        """Retrieves a pointer to the underlying memory.

        Parameters:
            origin: The origin of the `InnerConnection`.
            address_space: The `AddressSpace` of the `InnerConnection`.

        Returns:
            The pointer to the underlying memory.
        """
        return (
            self.db.unsafe_mut_cast[origin.mut]()
            .unsafe_origin_cast[origin]()
            .unsafe_address_space_cast[address_space]()
        )

    def is_autocommit(self) -> Bool:
        """Returns whether the connection is in auto-commit mode.

        Returns:
            True if the connection is in auto-commit mode, False otherwise.
        """
        return sqlite_ffi()[].get_autocommit(self.unsafe_ptr())

    def is_busy(self) -> Bool:
        """Returns whether the connection is currently busy.

        Returns:
            True if the connection is busy, False otherwise.
        """
        var stmt = sqlite_ffi()[].next_stmt(self.unsafe_ptr(), None)
        while stmt:
            if sqlite_ffi()[].stmt_busy(stmt.value()):
                return True
            stmt = sqlite_ffi()[].next_stmt(self.unsafe_ptr(), stmt)
        return False

    def close(deinit self) -> SQLite3Result:
        """Closes the underlying sqlite3 connection.

        Closing the connection unregisters any virtual table modules registered
        on it, so the module allocations are only freed afterwards.

        Returns:
            The SQLite3Result code from the close operation.
        """
        var result = sqlite_ffi()[].close(self.unsafe_ptr())
        self.modules^.deinit_with(_free_module)
        return result

    def interrupt(mut self) -> None:
        """Interrupts the longest-running query currently executing on this
        connection, causing it to abort at its earliest opportunity.
        """
        sqlite_ffi()[].interrupt(self.unsafe_ptr())

    def is_interrupted(self) -> Bool:
        """Returns whether an interrupt is currently pending on this connection.

        Returns:
            True if `interrupt()` has been called and the interrupt is still
            pending, False otherwise.
        """
        return sqlite_ffi()[].is_interrupted(self.unsafe_ptr())

    def changes(self) -> Int64:
        """Returns the number of rows changed by the last INSERT, UPDATE, or DELETE statement.

        Returns:
            The number of rows changed.
        """
        return sqlite_ffi()[].changes64(self.unsafe_ptr())

    def total_changes(self) -> Int64:
        """Returns the total number of changes made to the database.

        Returns:
            The total number of changes.
        """
        return sqlite_ffi()[].total_changes64(self.unsafe_ptr())

    def last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row.

        Returns:
            The row ID of the last inserted row.
        """
        return sqlite_ffi()[].last_insert_rowid(self.unsafe_ptr())

    def prepare(
        mut self, var sql: String, flags: PrepFlag = PrepFlag.NONE
    ) raises -> Tuple[Optional[MutExternalPointer[sqlite3_stmt]], UInt]:
        """Prepares an SQL statement for execution.

        Args:
            sql: The SQL statement to prepare.
            flags: The flags to use when preparing the statement.

        Returns:
            A tuple containing a pointer to the prepared statement and the length of the remaining unused SQL text.

        Raises:
            Will return an `Error` if the underlying SQLite prepare call fails.
        """
        var stmt: Optional[MutExternalPointer[sqlite3_stmt]] = None
        var str = sql.as_c_string_slice().unsafe_ptr()
        var c_tail = Pointer(to=str)

        try:
            self.raise_if_error(
                sqlite_ffi()[].prepare_v3(self.unsafe_ptr(), str, Int32(sql.byte_length()), flags.value, stmt, c_tail),
            )
        except e:
            if stmt:
                _ = sqlite_ffi()[].finalize(stmt.value())
            raise e^

        var tail: UInt = 0
        var tail_len = len(CStringSlice(unsafe_from_ptr=c_tail[]).as_bytes())
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
        return sqlite_ffi()[].db_filename(self.unsafe_ptr(), db_name).and_then[To=Path](str_slice_to_path)

    def is_database_read_only(self, var database: String) raises -> Bool:
        """Checks if the specified database is opened in read-only mode.

        Args:
            database: The name of the database (e.g., "main", "temp").

        Returns:
            True if the database is read-only, False otherwise.

        Raises:
            Error: If the database name is invalid or if there is an error checking the database mode.
        """
        var result = sqlite_ffi()[].db_readonly(self.unsafe_ptr(), database)
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
        raise_if_error(self.unsafe_ptr(), code)

    def error_msg(self, code: SQLite3Result) -> Optional[String]:
        """Checks for the error message set in sqlite3, or what the description of the provided code is.

        Args:
            code: The SQLite error code.

        Returns:
            An optional string slice containing the error message, or None if not found.
        """
        return error_msg(self.unsafe_ptr(), code)

    def decode_error(self, code: SQLite3Result) -> Error:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Returns:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        return decode_error(self.unsafe_ptr(), code)

    # TODO: V should be constrained to ToSQL, but I want to keep extensions private from users for now.
    def create_scalar_function[
        P: CopyDestructible,
        V: MoveDestructible,
        //,
        x_func: ScalarUDF[V],
    ](mut self, fn_name: StringSpan, n_arg: Int, flags: FunctionFlags, pApp: P) -> SQLite3Result:
        """Attach a user-defined scalar function to a database connection.

        The function will remain available until the connection is closed or
        until it is explicitly removed via `remove_function`.

        For scalar functions, only `x_func` is used. The xStep and xFinal
        callbacks are set to NULL internally, as required by SQLite.

        `slight` **creates a copy of `pApp`** to pass to SQLite, so the caller retains ownership of the original `pApp` value
        and is responsible for its lifecycle. The copied value is automatically freed using a default destructor
        when the function is removed or when the connection is closed.

        Parameters:
            P: The type of the application data to be passed to the callback.
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
            t"Return type V must conform to `ToSQL` trait. {reflect[V].name()} does not implement `ToSQL`."
        )

        # Copy data to the heap and pass a pointer to it as pApp.
        # The copy is destroyed and freed by `_typed_destructor[...]` when the
        # function is removed or when the connection is closed.
        var pAppPtr = ptr_copy(pApp)
        return sqlite_ffi()[].create_scalar_function(
            self.unsafe_ptr(),
            fn_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.unsafe_bitcast[NoneType](),
            _call_scalar_callback[x_func],
            _typed_destructor[P],
        )

    def create_scalar_function[
        V: MoveDestructible, //, x_func: ScalarUDF[V]
    ](mut self, fn_name: StringSpan, n_arg: Int, flags: FunctionFlags,) -> SQLite3Result:
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
            t"Return type V must conform to `ToSQL` trait. {reflect[V].name()} does not implement `ToSQL`."
        )
        return sqlite_ffi()[].create_scalar_function(
            self.unsafe_ptr(),
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
    ](mut self, fn_name: StringSpan, n_arg: Int, flags: FunctionFlags, pApp: P) -> SQLite3Result:
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
            t"Return type T must conform to `ToSQL` trait. {reflect[T].name()} does not implement `ToSQL`."
        )

        # Copy data to the heap and pass a pointer to it as pApp.
        # The copy is destroyed and freed by `_typed_destructor[...]` when the
        # function is removed or when the connection is closed.
        var pAppPtr = ptr_copy(pApp)
        return sqlite_ffi()[].create_aggregate_function(
            self.unsafe_ptr(),
            fn_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.unsafe_bitcast[NoneType](),
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
            _typed_destructor[P],
        )

    def create_aggregate_function[
        A: MoveDestructible,
        T: MoveDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
    ](mut self, fn_name: StringSpan, n_arg: Int, flags: FunctionFlags,) -> SQLite3Result:
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
            t"Return type T must conform to `ToSQL` trait. {reflect[T].name()} does not implement `ToSQL`."
        )
        return sqlite_ffi()[].create_aggregate_function(
            self.unsafe_ptr(),
            fn_name,
            c_int(n_arg),
            flags.value,
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
        )

    def create_window_function[
        A: CopyDestructible,
        T: MoveDestructible,
        P: CopyDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
        value_fn: WindowAggregateValueUDF[A, T],
        inverse_fn: WindowAggregateInverseUDF[A],
    ](mut self, fn_name: StringSpan, n_arg: Int, flags: FunctionFlags, pApp: P) -> SQLite3Result:
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
        """
        comptime assert conforms_to(T, ToSQL), String(
            t"Return type T must conform to `ToSQL` trait. {reflect[T].name()} does not implement `ToSQL`."
        )

        # Copy data to the heap and pass a pointer to it as pApp.
        # The copy is destroyed and freed by `_typed_destructor[...]` when the
        # function is removed or when the connection is closed.
        var pAppPtr = ptr_copy(pApp)
        return sqlite_ffi()[].create_window_function(
            self.unsafe_ptr(),
            fn_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.unsafe_bitcast[NoneType](),
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
            _call_value_callback[value_fn],
            _call_inverse_callback[inverse_fn],
            _typed_destructor[P],
        )

    def create_window_function[
        A: CopyDestructible,
        T: MoveDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
        value_fn: WindowAggregateValueUDF[A, T],
        inverse_fn: WindowAggregateInverseUDF[A],
    ](mut self, fn_name: StringSpan, n_arg: Int, flags: FunctionFlags,) -> SQLite3Result:
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
        """
        comptime assert conforms_to(T, ToSQL), String(
            t"Return type T must conform to `ToSQL` trait. {reflect[T].name()} does not implement `ToSQL`."
        )
        return sqlite_ffi()[].create_window_function(
            self.unsafe_ptr(),
            fn_name,
            c_int(n_arg),
            flags.value,
            _call_step_callback[init_fn, step_fn],
            _call_final_callback[final_fn],
            _call_value_callback[value_fn],
            _call_inverse_callback[inverse_fn],
        )

    def create_module[
        T: MoveDestructible,
        C: MoveDestructible,
        connect_fn: VTabConnectFn[T],
        best_index_fn: VTabBestIndexFn[T],
        open_fn: VTabOpenFn[T, C],
        filter_fn: VTabFilterFn[C],
        next_fn: VTabNextFn[C],
        eof_fn: VTabEofFn[C],
        column_fn: VTabColumnFn[C],
        rowid_fn: VTabRowidFn[C],
    ](mut self, module_name: StringSpan) -> SQLite3Result:
        """Register a read-only virtual table module with this connection.

        Allocates a `sqlite3_module` on the heap, fills in all required and
        stub callbacks, then calls `sqlite3_create_module_v2` to register it.
        SQLite only borrows the module pointer, so the allocation is retained by
        this connection and freed by `close()` after `sqlite3_close` has
        unregistered it.

        Parameters:
            T: The user-provided virtual table state type.
            C: The user-provided cursor state type.
            connect_fn: Called for both xCreate and xConnect.
            best_index_fn: Called for xBestIndex.
            open_fn: Called for xOpen to create a new cursor.
            filter_fn: Called for xFilter to begin a scan.
            next_fn: Called for xNext to advance the cursor.
            eof_fn: Called for xEof to check end-of-rows.
            column_fn: Called for xColumn to retrieve a column value.
            rowid_fn: Called for xRowid to retrieve the rowid.

        Args:
            module_name: Name to register the virtual table module under.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var module = make_read_only_module[
            connect_fn,
            best_index_fn,
            open_fn,
            filter_fn,
            next_fn,
            eof_fn,
            column_fn,
            rowid_fn,
        ]()
        # Register first, then take ownership. The allocation is retained even
        # when registration fails, since SQLite is given a NULL destructor and
        # so never frees it on the error path either.
        var result = sqlite_ffi()[].create_module(self.unsafe_ptr(), module_name, module.unsafe_ptr())
        self.modules.append(module^)
        return result

    def remove_function(
        mut self,
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

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # To delete a function, pass NULL for all callbacks and pApp,
        # with UTF8 encoding.
        var func_name = fn_name.copy()
        return sqlite_ffi()[].remove_function(
            self.unsafe_ptr(),
            func_name,
            c_int(n_arg),
        )

    def busy_timeout(mut self, ms: c_int) -> SQLite3Result:
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
        return sqlite_ffi()[].busy_timeout(self.unsafe_ptr(), ms)

    def busy_handler(mut self, callback: BusyHandlerFn) -> SQLite3Result:
        """Register a callback to handle `SQLITE_BUSY` errors.

        The callback is invoked with the number of prior retries.
        Return `True` from the callback to retry, `False` to stop.

        There can only be a single busy handler per database connection.
        Setting a new busy handler clears any previously set handler.
        Calling `busy_timeout()` also clears any custom busy handler.

        Args:
            callback: A busy handler callback function.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var fn_val = callback
        # Transmute: store def pointer VALUE as the void pointer address
        # (same as Rust's `f as *mut c_void`). Taking the ADDRESS of `fn_val`
        # here would hand SQLite a pointer into this frame, which dies on
        # return — SQLite dereferences it later, from a dead stack slot.
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        return sqlite_ffi()[].busy_handler(
            self.unsafe_ptr(),
            _busy_handler_callback,
            ctx,
        )

    def clear_busy_handler(mut self) -> SQLite3Result:
        """Clears the set busy handler callback.

        The busy handler is cleared and `SQLITE_BUSY` is returned immediately upon encountering a lock.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # Passing timeout=0 clears all busy handlers (per SQLite docs).
        return sqlite_ffi()[].busy_timeout(self.unsafe_ptr(), 0)

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
        return sqlite_ffi()[].limit(self.unsafe_ptr(), c_int(limit.value), c_int(-1))

    def set_limit(mut self, limit: Limit, new_val: Int32) -> Int32:
        """Changes a run-time limit, returning the prior value.

        Args:
            limit: The limit category to change.
            new_val: The new value for the limit.

        Returns:
            The previous value of the limit, or -1 if the limit category is
            invalid.
        """
        return sqlite_ffi()[].limit(self.unsafe_ptr(), c_int(limit.value), c_int(new_val))

    def trace_v2(mut self, mask: TraceEventCodes, callback: TraceFn) -> SQLite3Result:
        """Register a trace callback (version 2).

        The callback is invoked for each event type selected by `mask`.

        Args:
            mask: Bitmask of `TraceEventCodes` to monitor.
            callback: A trace callback function.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var fn_val = callback
        # Transmute: store def pointer VALUE as the void pointer address
        # (same as Rust's `f as *mut c_void`)
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        return sqlite_ffi()[].trace_v2(
            self.unsafe_ptr(),
            mask.value,
            _trace_v2_callback,
            ctx,
        )

    def clear_trace_v2(mut self) -> SQLite3Result:
        """Disable tracing by unregistering the trace callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # Passing mask=0 disables tracing regardless of the callback pointer.
        return sqlite_ffi()[].trace_v2(
            self.unsafe_ptr(),
            UInt32(0),
            _trace_v2_callback,
            None,
        )

    def register_commit_hook(mut self, callback: CommitHookFn) -> None:
        """Register a callback invoked whenever a transaction is committed.

        Args:
            callback: A `CommitHookFn` callback. Returning `True` converts the commit into a rollback.
        """
        var fn_val = callback
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        _ = sqlite_ffi()[].commit_hook(self.unsafe_ptr(), _commit_hook_trampoline_ptr(), ctx)

    def clear_commit_hook(mut self) -> None:
        """Unregister the commit hook, if any.

        Passes a NULL `xCallback` so SQLite fully unregisters the hook rather
        than leaving an inert trampoline registered.
        """
        _ = sqlite_ffi()[].commit_hook(self.unsafe_ptr(), None, None)

    def register_rollback_hook(mut self, callback: RollbackHookFn) -> None:
        """Register a callback invoked whenever a transaction is rolled back.

        Args:
            callback: A `RollbackHookFn` callback.
        """
        var fn_val = callback
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        _ = sqlite_ffi()[].rollback_hook(self.unsafe_ptr(), _rollback_hook_trampoline_ptr(), ctx)

    def clear_rollback_hook(mut self) -> None:
        """Unregister the rollback hook, if any.

        Passes a NULL `xCallback` so SQLite fully unregisters the hook rather
        than leaving an inert trampoline registered.
        """
        _ = sqlite_ffi()[].rollback_hook(self.unsafe_ptr(), None, None)

    def register_update_hook(mut self, callback: UpdateHookFn) -> None:
        """Register a callback invoked whenever a row is inserted, updated,
        or deleted in a rowid table.

        Args:
            callback: An `UpdateHookFn` callback.
        """
        var fn_val = callback
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        sqlite_ffi()[].update_hook(self.unsafe_ptr(), _update_hook_trampoline_ptr(), ctx)

    def clear_update_hook(mut self) -> None:
        """Unregister the update hook, if any.

        Passes a NULL `xCallback` so SQLite fully unregisters the hook rather
        than leaving an inert trampoline registered.
        """
        sqlite_ffi()[].update_hook(self.unsafe_ptr(), None, None)

    def create_collation(mut self, mut name: String, flags: c_int, compare: CollationCompareFn) -> SQLite3Result:
        """Define a new collating sequence.

        Args:
            name: Name of the collating sequence.
            flags: Text encoding flags (e.g. SQLITE_UTF8).
            compare: A `CollationCompareFn` comparator.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var fn_val = compare
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        return sqlite_ffi()[].create_collation_v2(
            self.unsafe_ptr(),
            name,
            flags,
            ctx,
            _collation_compare_callback,
            _no_op_collation_destructor,
        )

    def remove_collation(mut self, mut name: String, flags: c_int) -> SQLite3Result:
        """Remove a previously registered collating sequence.

        Passing a NULL comparator to `sqlite3_create_collation_v2` removes
        the named collating sequence.

        Args:
            name: Name of the collating sequence to remove.
            flags: Text encoding flags that were used to register it.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var null_compare = Pointer(to=Int(0)).unsafe_bitcast[CollationCompareCallbackFn]()[]
        return sqlite_ffi()[].create_collation_v2(
            self.unsafe_ptr(),
            name,
            flags,
            MutExternalPointer[NoneType](unsafe_from_address=1),
            null_compare,
            _no_op_collation_destructor,
        )

    def register_progress_handler(mut self, n_ops: Int, callback: ProgressHandlerFn) -> None:
        """Register a callback invoked approximately every `n_ops` virtual
        machine instructions during query execution.

        Args:
            n_ops: Approximate number of VM instructions between invocations.
            callback: A `ProgressHandlerFn` callback. Returning `True`
                interrupts the running query.
        """
        var fn_val = callback
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        sqlite_ffi()[].progress_handler(self.unsafe_ptr(), c_int(n_ops), _progress_handler_callback, ctx)

    def clear_progress_handler(mut self) -> None:
        """Unregister the progress handler, if any."""
        # Passing 0 for nOps disables the progress handler.
        sqlite_ffi()[].progress_handler(
            self.unsafe_ptr(), c_int(0), _progress_handler_callback, MutExternalPointer[NoneType](unsafe_from_address=1)
        )

    def register_authorizer(mut self, callback: AuthorizerFn) -> SQLite3Result:
        """Register an authorizer callback invoked during statement
        preparation for actions requiring authorization.

        Args:
            callback: An `AuthorizerFn` callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var fn_val = callback
        var fn_as_int = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
        var ctx = MutExternalPointer[NoneType](unsafe_from_address=fn_as_int)
        return sqlite_ffi()[].set_authorizer[_authorizer_callback](self.unsafe_ptr(), ctx)

    def clear_authorizer(mut self) -> SQLite3Result:
        """Unregister the authorizer callback, if any.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return sqlite_ffi()[].remove_authorizer(self.unsafe_ptr())

    def log(mut self, err_code: Int32, mut msg: String):
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

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return sqlite_ffi()[].enable_load_extension(self.unsafe_ptr(), c_int(1 if enable else 0))

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
        var errmsg: Optional[MutExternalPointer[c_char]] = None
        var ep = entry_point.copy()
        var result = sqlite_ffi()[].load_extension(
            self.unsafe_ptr(),
            path,
            ep,
            errmsg,
        )
        if result == SQLite3Result.OK:
            return

        # Extract the error message returned by SQLite, then free it.
        var message: Optional[String] = None
        if errmsg:
            var errmsg_ptr = errmsg.take()
            message = String(unsafe_from_utf8_ptr=errmsg_ptr)
            sqlite_ffi()[].free(errmsg_ptr.unsafe_bitcast[NoneType]())

        raise Error(error_from_sqlite_code(result, message))

    def serialize(mut self, var schema: String = "main") raises -> List[Byte]:
        """Serializes a database into an in-memory copy in the standard SQLite
        file format.

        Args:
            schema: Name of the database schema to serialize (e.g. "main").

        Returns:
            A byte copy of the serialized database.

        Raises:
            Error: If serialization fails (e.g. out of memory).
        """
        var size: Int64 = 0
        var maybe_buf = sqlite_ffi()[].serialize(self.unsafe_ptr(), schema, Pointer(to=size), 0)
        if not maybe_buf:
            raise Error("sqlite3_serialize failed: out of memory")

        var buf = maybe_buf.value()
        var data = List[Byte](capacity=len(buf))
        data.extend(buf)
        sqlite_ffi()[].free(buf.unsafe_ptr().unsafe_bitcast[NoneType]())
        return data^

    def deserialize(mut self, var data: List[Byte], var schema: String = "main", read_only: Bool = False) raises:
        """Deserializes a database from an in-memory byte buffer, replacing the
        current contents of the given schema.

        The buffer is copied into memory allocated by SQLite, which takes
        ownership of it and frees it when the connection closes (or is
        deserialized into again).

        Args:
            data: The serialized database, in the standard SQLite file format.
            schema: Name of the database schema to deserialize into (e.g. "main").
            read_only: If True, the deserialized database is treated as read-only
                and cannot be resized. If False, SQLite is allowed to grow the
                buffer as the database expands.

        Raises:
            Error: If the buffer cannot be allocated, or if deserialization fails.
        """
        var size = UInt64(len(data))
        var maybe_ptr = sqlite_ffi()[].malloc64(size)
        if not maybe_ptr:
            raise Error("sqlite3_malloc64 failed: out of memory")

        var ptr = maybe_ptr.value().unsafe_bitcast[Byte]()
        for i in range(len(data)):
            ptr.unsafe_offset(i).unsafe_write(data[i])

        var flags = SQLITE_DESERIALIZE_FREEONCLOSE
        if read_only:
            flags |= SQLITE_DESERIALIZE_READONLY
        else:
            flags |= SQLITE_DESERIALIZE_RESIZEABLE

        self.raise_if_error(
            sqlite_ffi()[].deserialize(self.unsafe_ptr(), schema, ptr, Int64(size), Int64(size), flags),
        )

    def wal_checkpoint(mut self, var schema: Optional[String] = None) raises:
        """Checkpoints the write-ahead log using the default (passive) mode.

        Args:
            schema: Name of the database schema to checkpoint (e.g. "main").
                If None, all attached databases are checkpointed.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.raise_if_error(sqlite_ffi()[].wal_checkpoint(self.unsafe_ptr(), schema^))

    def wal_checkpoint_v2(mut self, mode: CheckpointMode, var schema: Optional[String] = None) raises -> Tuple[Int, Int]:
        """Checkpoints the write-ahead log with additional control over the
        checkpoint operation.

        Args:
            mode: The checkpoint mode (PASSIVE, FULL, RESTART, or TRUNCATE).
            schema: Name of the database schema to checkpoint (e.g. "main").
                If None, all attached databases are checkpointed.

        Returns:
            A tuple `(log_frames, checkpointed_frames)` containing the total
            number of frames in the WAL log, and the number of frames that
            were checkpointed.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        var log_frames: c_int = 0
        var checkpointed_frames: c_int = 0
        self.raise_if_error(
            sqlite_ffi()[].wal_checkpoint_v2(
                self.unsafe_ptr(),
                schema^,
                c_int(mode.value),
                Pointer(to=log_frames),
                Pointer(to=checkpointed_frames),
            )
        )
        return (Int(log_frames), Int(checkpointed_frames))

    def backup_init(
        mut self,
        mut dest: InnerConnection,
        var dest_schema: String,
        var source_schema: String,
    ) raises -> MutExternalPointer[sqlite3_backup]:
        """Initializes a backup operation copying this connection's database
        into `dest`.

        Args:
            dest: The destination connection.
            dest_schema: Name of the destination database schema (e.g. "main").
            source_schema: Name of the source database schema (e.g. "main").

        Returns:
            A handle to the backup operation.

        Raises:
            Error: If the backup could not be initialized.
        """
        var maybe_backup = sqlite_ffi()[].backup_init(dest.db, dest_schema, self.unsafe_ptr(), source_schema)
        if not maybe_backup:
            raise self.decode_error(self.errcode_result())
        return maybe_backup.value()

    def errcode_result(self) -> SQLite3Result:
        """Returns the most recent result code produced by this connection.

        Returns:
            The most recent SQLite result code.
        """
        return sqlite_ffi()[].errcode(self.unsafe_ptr())

    def backup_step(mut self, p: MutExternalPointer[sqlite3_backup], n_pages: Int) -> SQLite3Result:
        """Copies up to `n_pages` pages from the source database to the
        destination database of a backup operation.

        Args:
            p: The backup handle.
            n_pages: Number of pages to copy, or -1 to copy all remaining pages.

        Returns:
            SQLITE_DONE if the backup is complete, SQLITE_OK if more pages
            remain, or another SQLite result code on error.
        """
        return sqlite_ffi()[].backup_step(p, c_int(n_pages))

    def backup_finish(mut self, p: MutExternalPointer[sqlite3_backup]) -> SQLite3Result:
        """Finishes a backup operation and releases the backup handle.

        Args:
            p: The backup handle.

        Returns:
            The SQLite result code from finishing the backup.
        """
        return sqlite_ffi()[].backup_finish(p)

    def backup_remaining(self, p: MutExternalPointer[sqlite3_backup]) -> Int:
        """Returns the number of pages still to be backed up.

        Args:
            p: The backup handle.

        Returns:
            The number of pages remaining to be copied.
        """
        return Int(sqlite_ffi()[].backup_remaining(p).value)

    def backup_page_count(self, p: MutExternalPointer[sqlite3_backup]) -> Int:
        """Returns the total number of pages in the source database.

        Args:
            p: The backup handle.

        Returns:
            The total number of pages in the source database.
        """
        return Int(sqlite_ffi()[].backup_page_count(p).value)

    def is_locked(self, rc: SQLite3Result) -> Bool:
        """Check whether a result code indicates shared-cache lock contention.

        Args:
            rc: The result code returned by a recent SQLite API call.

        Returns:
            True if the error is SQLITE_LOCKED due to shared-cache contention.
        """
        return is_locked(self.unsafe_ptr(), rc)

    def wait_for_unlock_notify(self) -> SQLite3Result:
        """Block until an unlock-notify callback fires, then return SQLITE_OK.

        Should only be called after a `SQLITE_LOCKED` result in shared-cache mode.
        If registering the notification would cause deadlock, returns SQLITE_LOCKED
        immediately; the caller should roll back the current transaction.

        Returns:
            SQLITE_OK when the lock is released, or an error code.
        """
        return wait_for_unlock_notify(self.unsafe_ptr())
