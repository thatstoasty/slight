from slight.c.api import sqlite_ffi
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.column import ColumnMetadata
from slight.flags import OpenFlag, PrepFlag
from slight.functions import Context, FunctionFlags
from slight.inner_connection import InnerConnection
from slight.params import Params
from slight.pragma import Sql
from slight.raw_statement import RawStatement
from slight.result import SQLite3Result
from slight.row import Int, Row  # RowIndex extension for Int
from slight.statement import Statement
from slight.transaction import Savepoint, Transaction, TransactionBehavior
from slight.types.from_sql import FromSQL
from slight.types.to_sql import ToSQL
from std.ffi import c_int
from std.memory import Pointer
from std.pathlib import Path
from std.reflection import get_type_name


struct Connection(Movable):
    """A connection to a SQLite database."""

    var db: InnerConnection
    """The inner SQLite connection."""

    @staticmethod
    fn open(
        out connection: Self,
        path: Path,
        flags: OpenFlag = OpenFlag(),
    ) raises:
        """Open a new connection to a SQLite database. If a database does not exist
        at the path, one is created.

        ```mojo
        from slight import Connection

        fn main() raises:
            var conn = Connection.open("my.db")
            # Use the connection...
            ...
        ```

        ## Flags:

        `Connection.open(path)` opens the connection with the following default flags:
        `SQLITE_OPEN_READ_WRITE`, `SQLITE_OPEN_CREATE`, and `SQLITE_OPEN_URI`.

        These flags have the following effects:

        - Open the database for both reading or writing.
        - Create the database if one does not exist at the path.
        - Allow the filename to be interpreted as a URI (see <https://www.sqlite.org/uri.html#uri_filenames_in_sqlite>
          for details).

        Args:
            path: The path to the SQLite database file.
            flags: The flags to use when opening the database.

        Returns:
            The newly created connection.

        Raises:
            Will return an `Error` if the underlying SQLite open call fails.
        """
        connection = Self(InnerConnection(String(path), flags))

    @staticmethod
    fn open_in_memory(
        out connection: Self,
        flags: OpenFlag = OpenFlag(),
    ) raises:
        """Open a new connection to an in-memory SQLite database.

        In-memory databases are temporary and are destroyed when the connection
        is closed. They are useful for testing, temporary data processing, or
        when you need a fast database that doesn't persist to disk.

        Args:
            flags: The flags to use when opening the database. Defaults to
                   `SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI`.

        Returns:
            The newly created in-memory connection.

        Raises:
            Error: If the underlying SQLite open call fails.
        """
        connection = Self(InnerConnection(":memory:", flags))

    @doc_private
    fn __init__(out self):
        """Initialize a new connection with an empty inner connection."""
        self.db = InnerConnection()

    @doc_private
    fn __init__(out self, var conn: InnerConnection):
        """Initialize a new connection with the given inner connection."""
        self.db = conn^

    fn __init__(out self, var path: String) raises:
        """Initialize a new connection with the given path to a SQLite database.

        Args:
            path: The path to the SQLite database file.

        Raises:
            Will raise an `Error` if the underlying SQLite open call fails.
        """
        self = Connection.open(path)

    fn __del__(deinit self):
        """Closes the connection when it is deleted."""
        if self.db:
            _ = self^.close()

    fn __enter__(var self) -> Self:
        """Enter the context manager.

        Returns:
            The connection itself.
        """
        return self^

    fn raise_if_error(self, code: SQLite3Result) raises:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Raises:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        self.db.raise_if_error(code)

    fn error_msg(self, code: SQLite3Result) -> Optional[String]:
        """Checks for the error message set in sqlite3, or what the description of the provided code is.

        Args:
            code: The SQLite error code.

        Returns:
            An optional string slice containing the error message, or None if not found.
        """
        return self.db.error_msg(code)

    fn decode_error(self, code: SQLite3Result) -> Error:
        """Return an error if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Returns:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        return self.db.decode_error(code)

    fn close(deinit self):
        """Closes the sqlite3 connection."""
        _ = self.db^.close()

    fn is_autocommit(self) -> Bool:
        """Returns whether the connection is in auto-commit mode.

        Returns:
            True if the connection is in auto-commit mode, False otherwise.
        """
        return self.db.is_autocommit()

    fn is_busy(self) -> Bool:
        """Returns whether the connection is currently executing a statement.

        Returns:
            True if the connection is busy, False otherwise.
        """
        return self.db.is_busy()

    fn changes(self) -> Int64:
        """Returns the number of rows that were changed, inserted, or deleted
        by the most recent SQL statement.

        Returns:
            The number of rows changed by the last operation.
        """
        return self.db.changes()

    fn total_changes(self) -> Int64:
        """Returns the total number of rows that were changed, inserted, or deleted
        since the database connection was opened.

        Returns:
            The total number of rows changed since the connection was opened.
        """
        return self.db.total_changes()

    fn prepare(self, sql: String, flags: PrepFlag = PrepFlag.PREPARE_PERSISTENT) raises -> Statement[origin_of(self)]:
        """Prepares a SQL statement for execution.

        Args:
            sql: The SQL statement to prepare.
            flags: The preparation flags to use.

        Returns:
            The prepared statement.

        Raises:
            Error: If the underlying SQLite prepare call fails or if multiple statements are found in the SQL string.
        """
        var stmt, tail = self.db.prepare(sql.copy(), flags)

        # If there is trailing SQL after the first statement that contains a valid SQL statement, raise an error.
        if tail > 0:
            var tail_stmt, _ = self.db.prepare(String(sql[Int(tail) :]))
            if tail_stmt:
                raise Error(
                    "MultipleStatementsError: Prepared statement contains multiple SQL statements. Should be one."
                )

        return Statement(Pointer(to=self), RawStatement(stmt))

    fn execute[P: AnyType](self, var sql: String, params: P = ()) raises -> Int64:
        """Executes a SQL statement with the given parameters.

        Parameters:
            P: The type of the parameters to bind. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Args:
            sql: The SQL statement to execute.
            params: The parameters to bind to the SQL statement. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Returns:
            The number of rows affected by the statement.

        Raises:
            Error: If parameter binding fails or the underlying SQLite call fails.
        """
        comptime assert conforms_to(P, Params), String(
            "`params` must conform to the `Params` trait. ",
            get_type_name[P](),
            " does not implement `Params`. Try a tuple or a list of parameters.",
        )
        var stmt = self.prepare(sql^)
        try:
            return stmt.execute(params)
        finally:
            _ = stmt^.finalize()

    fn execute_batch(self, sql: String) raises:
        """Executes a batch of SQL statements.

        Args:
            sql: The batch of SQL statements to execute.

        Raises:
            Error: If the underlying SQLite call fails or if any of the statements in the batch return results, which is not supported.
        """
        var current_sql = sql.copy()
        while len(current_sql) > 0:
            # Is it possible to copy the sql string less here? I don't want to keep allocating strings.
            var stmt, tail = self.db.prepare(current_sql.copy(), PrepFlag.PREPARE_PERSISTENT)
            if stmt and Statement(Pointer(to=self), RawStatement(stmt)).step():
                pass  # some pragmas return results
                # raise Error("ExecuteReturnedResults: The executed batch returned results, which is not supported.")

            if tail == 0 or Int(tail) >= len(current_sql):
                break

            current_sql = String(current_sql[Int(tail) :])

    fn path(self) -> Optional[Path]:
        """Returns the file path of the database.

        Returns:
            The file path of the database, or None if the database is in-memory.
        """
        return self.db.path()

    fn last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row.

        Returns:
            The row ID of the last inserted row.
        """
        return self.db.last_insert_row_id()

    # fn one_column[P: AnyType, //, T: FromSQL](self, var sql: String, params: P = ()) raises -> T:
    #     """Fetches a single column from the first row of the result set.

    #     Parameters:
    #         P: The type of the parameters to bind.
    #         T: The type to retrieve the value as. Must be Copyable, Movable, and FromSQL.

    #     Args:
    #         sql: The SQL query to execute.
    #         params: The parameters to bind to the SQL query. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

    #     Returns:
    #         The value of the first column in the first row of the result set.

    #     Raises:
    #         Error: If the query fails or no rows are returned.
    #     """
    #     comptime assert conforms_to(P, Params), "`params` must conform to the `Params` trait. Try a tuple or a list of parameters."
    #     fn get_item(row: Row) raises -> T:
    #         return row.get[T](0)

    #     return self.prepare(sql^).query[get_item](params)

    fn one_row[
        T: Movable, P: AnyType, //, transform: fn(Row) raises -> T
    ](self, var sql: String, params: P = ()) raises -> T:
        """Executes a SQL query and returns a single row.

        Parameters:
            T: The type to transform the row into.
            P: The type of the parameters to bind. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).
            transform: A function to transform the row into the desired type.

        Args:
            sql: The SQL query to execute.
            params: The parameters to bind to the SQL query. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Returns:
            The single row returned by the query.

        Raises:
            Error: If the query fails or does not return exactly one row.
        """
        comptime assert conforms_to(P, Params), String(
            "`params` must conform to the `Params` trait. ",
            get_type_name[P](),
            " does not implement `Params`. Try a tuple or a list of parameters.",
        )
        var rows = self.prepare(sql^).query[transform](params)
        try:
            return next(rows)
        except StopIteration:
            raise Error("No rows returned by query.")

    fn column_exists(
        self,
        table: String,
        column: String,
        db: Optional[String] = None,
    ) raises -> Bool:
        """Check if `table`.`column` exists.

        Args:
            table: The name of the table.
            column: The name of the column.
            db: The database name (main, temp, ATTACH name), or None to search all databases.

        Returns:
            True if the column exists, False otherwise.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        return self.exists(table=table, db=db, column=column)

    fn table_exists(
        self,
        table: String,
        db: Optional[String] = None,
    ) raises -> Bool:
        """Check if `table` exists.

        Args:
            table: The name of the table.
            db: The database name (main, temp, ATTACH name), or None to search all databases.

        Returns:
            True if the table exists, False otherwise.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        return self.exists(table=table, db=db)

    fn column_metadata(
        self,
        var table: String,
        var column: String,
        var db: Optional[String] = None,
    ) raises -> ColumnMetadata:
        """Extract metadata of column at specified index.

        Args:
            table: The name of the table.
            column: The name of the column.
            db: The database name (main, temp, ATTACH name), or None to search all databases.

        Returns:
            `ColumnMetadata` containing:
            - declared data type (Optional[String])
            - name of default collation sequence (Optional[String])
            - True if column has a NOT NULL constraint
            - True if column is part of the PRIMARY KEY
            - True if column is AUTOINCREMENT

        Raises:
            Error: If the underlying SQLite call fails.
        """
        var not_null: Int32 = 0
        var primary_key: Int32 = 0
        var auto_inc: Int32 = 0
        var data_type: Optional[String] = None
        var coll_seq: Optional[String] = None

        self.raise_if_error(
            sqlite_ffi()[].table_column_metadata(
                self.db.db,
                db,
                table,
                column,
                data_type,
                coll_seq,
                not_null,
                primary_key,
                auto_inc,
            )
        )

        return ColumnMetadata(
            data_type=data_type.value() if data_type else Optional[String](None),
            collation_sequence=coll_seq.value() if coll_seq else Optional[String](None),
            not_null=not_null != 0,
            primary_key=primary_key != 0,
            auto_increment=auto_inc != 0,
        )

    fn exists(
        self,
        var table: String,
        var db: Optional[String] = None,
        var column: Optional[String] = None,
    ) raises -> Bool:
        """Check if a table or column exists.

        Args:
            table: The name of the table.
            db: The database name (main, temp, ATTACH name), or None to search all databases.
            column: The name of the column, or None to check only table existence.

        Returns:
            True if the table/column exists, False otherwise.

        Raises:
            Error: If the underlying SQLite call fails with an unexpected error.
        """
        var r = sqlite_ffi()[].table_column_metadata(
            self.db.db,
            db,
            table,
            column,
            None,
            None,
            None,
            None,
            None,
        )

        if r == SQLite3Result.OK:
            return True
        elif r == SQLite3Result.ERROR:
            return False
        else:
            raise self.decode_error(r)

    fn transaction(self, behavior: Optional[TransactionBehavior] = None) raises -> Transaction[origin_of(self)]:
        """Begin a new transaction with the default behavior (DEFERRED).

        The transaction defaults to rolling back when it is dropped. If you
        want the transaction to commit, you must call `commit()` or
        `set_drop_behavior(DropBehavior.COMMIT())`.

        Args:
            behavior: The transaction behavior (DEFERRED, IMMEDIATE, or EXCLUSIVE).

        Returns:
            A new Transaction object.

        Raises:
            Error: If the underlying SQLite call fails.

                #### Example:

        ```mojo
        from slight import Connection

        fn perform_queries(mut conn: Connection) raises:
            var tx = conn.transaction()

            _ = tx.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
            _ = tx.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

            tx.commit()
        ```
        """
        if behavior:
            return Transaction(Pointer(to=self), behavior.value())
        else:
            return Transaction(Pointer(to=self))

    fn savepoint(self, name: Optional[String] = None) raises -> Savepoint[origin_of(self)]:
        """Begin a new savepoint with the default behavior (DEFERRED).

        The savepoint defaults to rolling back when it is dropped. If you want
        the savepoint to commit, you must call `commit()` or
        `set_drop_behavior(DropBehavior.COMMIT())`.

        Args:
            name: The name of the savepoint. If None, an unnamed savepoint is created.

        Returns:
            A new Savepoint object.

        Raises:
            Error: If the underlying SQLite call fails.

        #### Example:

        ```mojo
        from slight import Connection
        fn perform_queries(mut conn: Connection) raises:
            var sp = conn.savepoint()

            _ = sp.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
            _ = sp.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

            sp.commit()
        ```
        """
        if name:
            return Savepoint(Pointer(to=self), name.value())
        else:
            return Savepoint(Pointer(to=self))

    fn pragma_query_value[
        T: Movable,
        //,
        transform: fn(Row) raises -> T,
    ](self, pragma: String, schema: Optional[String] = None,) raises -> T:
        """Query the current value of a pragma.

        Some pragmas will return multiple rows/values which cannot be retrieved
        with this method. Use `pragma_query()` for those cases.

        Prefer [PRAGMA function](https://sqlite.org/pragma.html#pragfunc) introduced in SQLite 3.20:
        `SELECT user_version FROM pragma_user_version;`

        Parameters:
            T: The return type.
            transform: A function to transform the row into the desired type.

        Args:
            pragma: The name of the pragma.
            schema: Optional schema name (e.g., "main", "temp").

        Returns:
            The value returned by the pragma.

        Raises:
            Error: If the underlying SQLite call fails.

        #### Example:

        ```mojo
        from slight import Connection
        from slight.row import Row

        fn get_int(r: Row) raises -> Int:
            return r.get[Int](0)

        fn main() raises:
            var db = Connection.open_in_memory()
            var user_version = db.pragma_query_value[get_int]("user_version")
            print(user_version)
        ```
        """
        var query = Sql()
        query.push_pragma(pragma, schema)
        return self.one_row[transform](String(query))

    fn pragma_query[
        callback: fn(Row) raises -> None
    ](self, schema: Optional[String], pragma: String,) raises:
        """Query the current rows/values of a pragma.

        Prefer [PRAGMA function](https://sqlite.org/pragma.html#pragfunc) introduced in SQLite 3.20:
        `SELECT * FROM pragma_collation_list;`

        Parameters:
            callback: A function to process each row.

        Args:
            schema: Optional schema name (e.g., "main", "temp").
            pragma: The name of the pragma.

        Raises:
            Error: If the underlying SQLite call fails.

        #### Example:

        ```mojo
        from slight import Connection
        from slight.row import Row, String

        fn print_collation(r: Row) raises:
            var name = r.get[String](1)
            print(name)

        fn main() raises:
            var db = Connection.open_in_memory()
            db.pragma_query[print_collation](None, "collation_list")
        ```
        """
        var query = Sql()
        query.push_pragma(pragma, schema)
        for row in self.prepare(String(query)).query(()):
            callback(row)

    fn pragma[
        T: AnyType, //, callback: fn(Row) raises -> None
    ](self, pragma: StringSlice, value: T, schema: Optional[String] = None,) raises:
        """Query the current value(s) of a pragma associated with a value.

        This method can be used with query-only pragmas which need an argument
        (e.g., `table_info('one_tbl')`) or pragmas which return value(s)
        (e.g., `integrity_check`).

        Prefer [PRAGMA function](https://sqlite.org/pragma.html#pragfunc) introduced in SQLite 3.20:
        `SELECT * FROM pragma_table_info(?1);`

        Parameters:
            T: The type of the value argument. Must conform to `ToSQL`.
            callback: A function to process each row.

        Args:
            pragma: The name of the pragma.
            value: The value argument for the pragma.
            schema: Optional schema name (e.g., "main", "temp").

        Raises:
            Error: If the underlying SQLite call fails.

        #### Example:

        ```mojo
        from slight import Connection
        from slight.row import Row, String

        fn print_column(r: Row) raises:
            var col = r.get[String](1)
            print(col)

        fn main() raises:
            var db = Connection.open_in_memory()
            db.pragma[print_column]("table_info", "sqlite_master")
        ```
        """
        comptime assert conforms_to(T, ToSQL), String(
            "`value` must conform to `ToSQL` trait. ", get_type_name[T](), " does not implement `ToSQL`."
        )
        var sql = Sql()
        sql.push_pragma(pragma, schema)
        # The argument may be either in parentheses or separated by an equal sign
        sql.open_brace()
        sql.push_value(value)
        sql.close_brace()
        for row in self.prepare(String(sql)).query(()):
            callback(row)

    fn pragma_update[
        T: AnyType, //
    ](self, pragma: StringSlice, value: T, schema: Optional[String] = None,) raises:
        """Set a new value to a pragma.

        Some pragmas will return the updated value which cannot be retrieved
        with this method. Use `pragma_update_and_check()` for those cases.

        Parameters;
            T: The type of the value argument. Must conform to the `ToSQL` trait.

        Args:
            pragma: The name of the pragma.
            value: The new value for the pragma. Must conform to `ToSQL`.
            schema: Optional schema name (e.g., "main", "temp").

        Raises:
            Error: If the underlying SQLite call fails.

        #### Example:

        ```mojo
        from slight import Connection

        fn main() raises:
            var db = Connection.open_in_memory()
            db.pragma_update("user_version", 1)
        ```
        """
        var sql = Sql()
        sql.push_pragma(pragma, schema)
        # The argument may be either in parentheses or separated by an equal sign
        sql.push_equal_sign()
        sql.push_value(value)
        self.execute_batch(String(sql))

    fn pragma_update_and_check[
        T: Movable, V: AnyType, //, transform: fn(Row) raises -> T
    ](self, pragma: StringSlice, value: V, schema: Optional[String] = None,) raises -> T:
        """Set a new value to a pragma and return the updated value.

        Only a few pragmas automatically return the updated value.

        Parameters:
            T: The return type.
            V: The type of the value argument. Must conform to the `ToSQL` trait.
            transform: A function to transform the row into the desired type.

        Args:
            pragma: The name of the pragma.
            value: The new value for the pragma. Must conform to `ToSQL`.
            schema: Optional schema name (e.g., "main", "temp").

        Returns:
            The value returned by the pragma after update.

        Raises:
            Error: If the underlying SQLite call fails.

                #### Example:

        ```mojo
        from slight import Connection
        from slight.row import Row, String

        fn get_string(r: Row) raises -> String:
            return r.get[String](0)

        fn main() raises:
            var db = Connection.open_in_memory()
            var mode = db.pragma_update_and_check[get_string](
                "journal_mode", "OFF"
            )
            print(mode)
        ```
        """
        comptime assert conforms_to(V, ToSQL), String(
            "`value` must conform to `ToSQL` trait. ", get_type_name[V](), " does not implement `ToSQL`."
        )
        var sql = Sql()
        sql.push_pragma(pragma, schema)
        # The argument may be either in parentheses or separated by an equal sign
        sql.push_equal_sign()
        sql.push_value(value)
        return self.one_row[transform](String(sql))

    # TODO: V should be constrained to ToSQL.
    fn create_scalar_function[
        P: Copyable & ImplicitlyDestructible, V: Movable & ImplicitlyDestructible, //, x_func: fn(Context) raises -> V
    ](
        self,
        fn_name: String,
        n_arg: Int,
        user_data: P,
        flags: FunctionFlags = FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    ) raises:
        """Attach a user-defined scalar function to a database connection.

        The function will remain available until the connection is closed or
        until it is explicitly removed via `remove_function`.

        For scalar functions, only `x_func` is used. The xStep and xFinal
        callbacks are set to NULL internally, as required by SQLite.

        Parameters:
            T: The type of the application data to pass to the callback. Must be Copyable and ImplicitlyDestructible.
            V: The return type of the scalar function. Must conform to `ToSQL`.
            x_func: The scalar function callback implementation.

        Args:
            fn_name: Name of the SQL function to create.
            n_arg: Number of arguments the function accepts (-1 for variable number).
            user_data: Data that is passed to the callback when the function is called. Can be used to store context or state for the function.
            flags: Function flags (encoding, determinism, etc.). Defaults to UTF-8 encoding and deterministic behavior.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        # For scalar functions, SQLite requires xFunc to be non-NULL and
        # xStep/xFinal to be NULL. We call the raw C API directly to pass
        # NULL for the unused callbacks.
        var result = self.db.create_scalar_function[x_func](fn_name, n_arg, flags, user_data.copy())
        self.raise_if_error(result)

    # TODO: When extensions work, switch to ToSQL
    fn create_scalar_function[
        V: Movable & ImplicitlyDestructible, //, x_func: fn(Context) raises -> V
    ](
        self,
        fn_name: String,
        n_arg: Int,
        flags: FunctionFlags = FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    ) raises:
        """Attach a user-defined scalar function to a database connection.

        The function will remain available until the connection is closed or
        until it is explicitly removed via `remove_function`.

        For scalar functions, only `x_func` is used. The xStep and xFinal
        callbacks are set to NULL internally, as required by SQLite.

        Parameters:
            V: The return type of the scalar function. Must conform to `ToSQL`.
            x_func: The scalar function callback implementation.

        Args:
            fn_name: Name of the SQL function to create.
            n_arg: Number of arguments the function accepts (-1 for variable number).
            flags: Function flags (encoding, determinism, etc.).

        Raises:
            Error: If the function could not be attached to the connection.
        """
        # For scalar functions, SQLite requires xFunc to be non-NULL and
        # xStep/xFinal to be NULL. We call the raw C API directly to pass
        # NULL for the unused callbacks.
        comptime assert conforms_to(V, ToSQL), String(
            "Return type V must conform to `ToSQL` trait. ", get_type_name[V](), " does not implement `ToSQL`."
        )
        var result = self.db.create_scalar_function[x_func](fn_name, n_arg, flags)
        self.raise_if_error(result)

    fn create_aggregate_function[
        A: Movable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        P: Copyable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
    ](
        self,
        fn_name: String,
        n_arg: Int,
        user_data: P,
        flags: FunctionFlags = FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    ) raises:
        """Attach a user-defined aggregate function to a database connection.

        Aggregate functions process multiple rows and produce a single result.
        The `x_step` callback is called once per row, and `x_final` is called
        once at the end to produce the result.

        Use `FunctionContext.aggregate_context()` inside the callbacks to manage
        per-group state.

        Parameters:
            A: The type of the aggregate state. Must be Movable.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            P: The type of the application data to pass to the callbacks.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            user_data: Data that is passed to the callbacks when the function is called. Can be used to store context or state for the function.
            flags: Function flags.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        # For aggregate functions, SQLite requires xFunc to be NULL and
        # xStep/xFinal to be non-NULL.
        comptime assert conforms_to(T, ToSQL), String(
            "Return type T must conform to `ToSQL` trait. ", get_type_name[T](), " does not implement `ToSQL`."
        )
        var result = self.db.create_aggregate_function[init_fn, step_fn, final_fn](fn_name, n_arg, flags, user_data)
        self.raise_if_error(result)

    fn create_aggregate_function[
        A: Movable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
    ](
        self,
        fn_name: String,
        n_arg: Int,
        flags: FunctionFlags = FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    ) raises:
        """Attach a user-defined aggregate function to a database connection.

        Aggregate functions process multiple rows and produce a single result.
        The `x_step` callback is called once per row, and `x_final` is called
        once at the end to produce the result.

        Use `FunctionContext.aggregate_context()` inside the callbacks to manage
        per-group state.

        Parameters:
            A: The type of the aggregate state. Must be Movable.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            flags: Function flags.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        # For aggregate functions, SQLite requires xFunc to be NULL and
        # xStep/xFinal to be non-NULL.
        comptime assert conforms_to(T, ToSQL), String(
            "Return type T must conform to `ToSQL` trait. ", get_type_name[T](), " does not implement `ToSQL`."
        )
        var result = self.db.create_aggregate_function[init_fn, step_fn, final_fn](fn_name, n_arg, flags)
        self.raise_if_error(result)

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
    ](
        self,
        fn_name: String,
        n_arg: Int,
        user_data: P,
        flags: FunctionFlags = FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    ) raises:
        """Attach a user-defined aggregate window function to a database connection.

        Window functions operate over a sliding window of rows. In addition to
        the `x_step` and `x_final` callbacks (like aggregate functions), they require
        `x_value` (to return the current aggregate value without finalizing) and
        `x_inverse` (to remove a row leaving the window frame).

        See https://sqlite.org/windowfunctions.html#udfwinfunc for more information.

        Parameters:
            A: The type of the aggregate state. Must be Movable.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            P: The type of the application data to pass to the callbacks.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.
            value_fn: The callback to compute the current aggregate value without finalizing.
            inverse_fn: The callback to update the aggregate state when a row leaves the window frame.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            user_data: Data that is passed to the callbacks when the function is called. Can be used to store context or state for the function.
            flags: Function flags.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(T, ToSQL), String(
            "Return type T must conform to `ToSQL` trait. ", get_type_name[T](), " does not implement `ToSQL`."
        )
        var result = self.db.create_window_function[init_fn, step_fn, final_fn, value_fn, inverse_fn](
            fn_name, n_arg, flags, user_data
        )
        self.raise_if_error(result)

    fn create_window_function[
        A: Copyable & ImplicitlyDestructible,
        T: Movable & ImplicitlyDestructible,
        //,
        init_fn: fn(mut ctx: Context) raises -> A,
        step_fn: fn(mut ctx: Context, mut acc: A) raises,
        final_fn: fn(mut ctx: Context, acc: A) raises -> T,
        value_fn: fn(acc: Optional[A]) raises -> T,
        inverse_fn: fn(mut ctx: Context, mut acc: A) raises,
    ](
        self,
        fn_name: String,
        n_arg: Int,
        flags: FunctionFlags = FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    ) raises:
        """Attach a user-defined aggregate window function to a database connection.

        Window functions operate over a sliding window of rows. In addition to
        the `x_step` and `x_final` callbacks (like aggregate functions), they require
        `x_value` (to return the current aggregate value without finalizing) and
        `x_inverse` (to remove a row leaving the window frame).

        See https://sqlite.org/windowfunctions.html#udfwinfunc for more information.

        Parameters:
            A: The type of the aggregate state. Must be Movable.
            T: The return type of the aggregate function. Must conform to `ToSQL`.
            init_fn: The callback to initialize the aggregate state for a new group.
            step_fn: The callback to update the aggregate state for each row in the group.
            final_fn: The callback to compute the final result from the aggregate state.
            value_fn: The callback to compute the current aggregate value without finalizing.
            inverse_fn: The callback to update the aggregate state when a row leaves the window frame.

        Args:
            fn_name: Name of the SQL aggregate function to create.
            n_arg: Number of arguments (-1 for variable number).
            flags: Function flags.

        Raises:
            Error: If the function could not be attached to the connection.
        """
        comptime assert conforms_to(T, ToSQL), String(
            "Return type T must conform to `ToSQL` trait. ", get_type_name[T](), " does not implement `ToSQL`."
        )
        var result = self.db.create_window_function[init_fn, step_fn, final_fn, value_fn, inverse_fn](
            fn_name, n_arg, flags
        )
        self.raise_if_error(result)

    # fn remove_function(
    #     self,
    #     mut fn_name: String,
    #     n_arg: Int,
    # ) raises:
    #     """Remove a user-defined function from a database connection.

    #     `fn_name` and `n_arg` should match the name and number of arguments
    #     given to `create_scalar_function`, `create_aggregate_function`, or
    #     `create_window_function`.

    #     Args:
    #         fn_name: Name of the SQL function to remove.
    #         n_arg: Number of arguments the function was registered with.

    #     Raises:
    #         Error: If the function could not be removed.
    #     """
    #     # To delete a function, pass NULL for all callbacks and pApp,
    #     # with UTF8 encoding.
    #     var result = sqlite_ffi()[].lib.get_function[
    #         fn (
    #             MutExternalPointer[sqlite3_connection],  # db
    #             ImmutUnsafePointer[c_char],  # zFunctionName
    #             c_int,  # nArg
    #             c_int,  # eTextRep (UTF8)
    #             MutExternalPointer[NoneType],  # pApp (NULL)
    #             MutExternalPointer[NoneType],  # xFunc (NULL)
    #             MutExternalPointer[NoneType],  # xStep (NULL)
    #             MutExternalPointer[NoneType],  # xFinal (NULL)
    #             MutExternalPointer[NoneType],  # destructor (NULL)
    #         ) -> c_int
    #     ]("sqlite3_create_function_v2")(
    #         self.db,
    #         fn_name.as_c_string_slice().unsafe_ptr(),
    #         c_int(n_arg),
    #         FunctionFlags.UTF8.value,
    #         MutExternalPointer[NoneType](),  # pApp = NULL
    #         MutExternalPointer[NoneType](),  # xFunc = NULL
    #         MutExternalPointer[NoneType](),  # xStep = NULL
    #         MutExternalPointer[NoneType](),  # xFinal = NULL
    #         MutExternalPointer[NoneType](),  # destructor = NULL
    #     )
    #     self.raise_if_error(self.db, SQLite3Result(result))
