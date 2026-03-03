from std.pathlib import Path
from std.ffi import c_int
from std.reflection import get_type_name

from slight.c.api import sqlite_ffi
from slight.c.raw_bindings import (
    sqlite3_connection,
    sqlite3_stmt,
)
from slight.c.types import MutExternalPointer, MutUnsafePointer, sqlite3_context, sqlite3_value, AggFinalCallback, AggStepCallback, WindowValueCallback, WindowInverseCallback
from slight.types.to_sql import ToSQL
from slight.types.value_ref import SQLite3Null,
SQLite3Integer,
SQLite3Real,
SQLite3Text,
SQLite3Blob
from slight.functions import FunctionFlags, Context, ScalarFnCallback
from slight.flags import PrepFlag, OpenFlag
from slight.result import SQLite3Result
from slight.error import error_msg, raise_if_error, decode_error


fn _default_destructor(pApp: MutExternalPointer[NoneType]):
    """Default destructor for user-defined function application data.

    This function is used as the destructor callback when creating user-defined functions
    with application data. It checks if the provided pointer is valid and frees it if so.

    Args:
        pApp: A mutable external pointer to the application data.
    """
    if pApp:
        pApp.free()


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
    fn create_scalar_function[T: Copyable & ImplicitlyDestructible, V: ImplicitlyDestructible, //, x_func: fn (Context) raises -> V](
        self,
        fn_name: String,
        n_arg: Int,
        flags: FunctionFlags,
        # x_func: ScalarFnCallback,
        pApp: T,
        # x_func: fn () raises -> T,
    ) raises -> SQLite3Result:
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
            x_func: The scalar function callback implementation.

        Args:
            fn_name: Name of the SQL function to create.
            n_arg: Number of arguments the function accepts (-1 for variable number).
            flags: Function flags (encoding, determinism, etc.).
            pApp: An optional pointer to application data that will be passed to the callback.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(V, ToSQL), String("Return type V must conform to `ToSQL` trait. ", get_type_name[V](), " does not implement `ToSQL`.")
        # For scalar functions, SQLite requires xFunc to be non-NULL and
        # xStep/xFinal to be NULL. We call the raw C API directly to pass
        # NULL for the unused callbacks.
        fn xFunc[func: fn (Context) raises -> V](ctx: MutExternalPointer[sqlite3_context], argc: c_int, argv: MutExternalPointer[MutExternalPointer[sqlite3_value]]) raises -> NoneType:
            # Convert raw C callback to our Context wrapper and call the user-provided function
            var context = Context(ctx, argc, argv)
            var result = trait_downcast[ToSQL](func(context)).to_sql()

            # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
            if result.isa[SQLite3Null]():
                context.result_null()
            elif result.isa[SQLite3Integer]():
                context.result_int64(result[SQLite3Integer].value)
            elif result.isa[SQLite3Real]():
                context.result_double(result[SQLite3Real].value)
            elif result.isa[SQLite3Text[origin_of(result)]]():
                context.result_text(String(
                    result[SQLite3Text[origin_of(result)]].value
                ))
            else:
                raise Error("Unsupported return type from scalar function.")
            return

        # Copy data to the heap and pass a pointer to it as pApp.
        # The data will be freed using the default destructor when the function is removed or when the connection is closed.
        var pAppPtr = alloc[T](count=1)
        pAppPtr[0] = pApp.copy()

        var func_name = fn_name.copy()
        return sqlite_ffi()[].create_scalar_function(
            self.db,
            func_name,
            c_int(n_arg),
            flags.value,
            pAppPtr.bitcast[NoneType](),
            xFunc[x_func],
            _default_destructor,
        )
    
    fn create_scalar_function[V: ImplicitlyDestructible, //, x_func: fn (Context) raises -> V](
        self,
        fn_name: String,
        n_arg: Int,
        flags: FunctionFlags,
    ) raises -> SQLite3Result:
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

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(V, ToSQL), String("Return type V must conform to `ToSQL` trait. ", get_type_name[V](), " does not implement `ToSQL`.")
        # For scalar functions, SQLite requires xFunc to be non-NULL and
        # xStep/xFinal to be NULL. We call the raw C API directly to pass
        # NULL for the unused callbacks.
        
        # Wrap the user-provided function in a C callback that matches the expected signature for SQLite scalar functions.
        fn xFunc[func: fn (Context) raises -> V](ctx: MutExternalPointer[sqlite3_context], argc: c_int, argv: MutExternalPointer[MutExternalPointer[sqlite3_value]]) raises -> NoneType:
            # Convert raw C callback to our Context wrapper and call the user-provided function
            var context = Context(ctx, argc, argv)
            var result = trait_downcast[ToSQL](func(context)).to_sql()
            # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
            # ToSQL is implemented on most of the important stdlib types.
            if result.isa[SQLite3Null]():
                context.result_null()
            elif result.isa[SQLite3Integer]():
                context.result_int64(result[SQLite3Integer].value)
            elif result.isa[SQLite3Real]():
                context.result_double(result[SQLite3Real].value)
            elif result.isa[SQLite3Text[origin_of(result)]]():
                context.result_text(String(
                    result[SQLite3Text[origin_of(result)]].value
                ))
            else:
                raise Error("Unsupported return type from scalar function.")
            return
        
        var func_name = fn_name.copy()
        return sqlite_ffi()[].create_scalar_function(
            self.db,
            func_name,
            c_int(n_arg),
            flags.value,
            xFunc[x_func],
        )
