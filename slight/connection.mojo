from std.ffi import c_int
from std.memory import Pointer
from std.pathlib import Path
from std.reflection import get_type_name
from slight.busy import BusyHandlerFn
from slight.c.api import sqlite_ffi
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.trace import TraceFn, TraceEventCodes
from slight.column import ColumnMetadata
from slight.context import Context
from slight.flags import OpenFlag, PrepFlag
from slight.functions import FunctionFlags
from slight.inner_connection import InnerConnection
from slight.limits import Limit
from slight.params import Params
from slight.pragma import Sql
from slight.raw_statement import RawStatement
from slight.result import SQLite3Result
from slight.row import Int, Row, RowTransformFn # RowIndex extension for Int
from slight.statement import Statement
from slight.transaction import Savepoint, Transaction, TransactionBehavior
from slight.types.from_sql import FromSQL
from slight.types.to_sql import ToSQL
from slight.load_extension import ExtensionLoadGuard
from slight.util import CopyDestructible, MoveDestructible
from slight.functions import (
    ScalarUDF,
    AggregateInitUDF,
    AggregateStepUDF,
    AggregateFinalUDF,
    WindowAggregateValueUDF,
    WindowAggregateInverseUDF,
)


struct Connection(Movable):
    """A connection to a SQLite database."""

    var db: InnerConnection
    """The inner SQLite connection."""

    @staticmethod
    def open(
        out connection: Self,
        path: Path,
        flags: OpenFlag = OpenFlag(),
    ) raises:
        """Open a new connection to a SQLite database. If a database does not exist
        at the path, one is created.

        ```mojo
        from slight import Connection

        def main() raises:
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
    def open_in_memory(
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

    def __init__(out self):
        """Initialize a new connection with an empty inner connection."""
        self.db = InnerConnection()

    def __init__(out self, var conn: InnerConnection):
        """Initialize a new connection with the given inner connection."""
        self.db = conn^

    def __init__(out self, var path: String) raises:
        """Initialize a new connection with the given path to a SQLite database.

        Args:
            path: The path to the SQLite database file.

        Raises:
            Will raise an `Error` if the underlying SQLite open call fails.
        """
        self = Connection.open(path)

    def __del__(deinit self):
        """Closes the connection when it is deleted."""
        if self.db:
            _ = self^.close()

    def __enter__(var self) -> Self:
        """Enter the context manager.

        Returns:
            The connection itself.
        """
        return self^

    def raise_if_error(self, code: SQLite3Result) raises:
        """Raises if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Raises:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        self.db.raise_if_error(code)

    def error_msg(self, code: SQLite3Result) -> Optional[String]:
        """Checks for the error message set in sqlite3, or what the description of the provided code is.

        Args:
            code: The SQLite error code.

        Returns:
            An optional string slice containing the error message, or None if not found.
        """
        return self.db.error_msg(code)

    def decode_error(self, code: SQLite3Result) -> Error:
        """Return an error if the SQLite error code is not `SQLITE_OK`.

        Args:
            code: The SQLite error code.

        Returns:
            Error: If the SQLite error code is not `SQLITE_OK`.
        """
        return self.db.decode_error(code)

    def close(deinit self):
        """Closes the sqlite3 connection."""
        _ = self.db^.close()

    def is_autocommit(self) -> Bool:
        """Returns whether the connection is in auto-commit mode.

        Returns:
            True if the connection is in auto-commit mode, False otherwise.
        """
        return self.db.is_autocommit()

    def is_busy(self) -> Bool:
        """Returns whether the connection is currently executing a statement.

        Returns:
            True if the connection is busy, False otherwise.
        """
        return self.db.is_busy()

    def changes(self) -> Int64:
        """Returns the number of rows that were changed, inserted, or deleted
        by the most recent SQL statement.

        Returns:
            The number of rows changed by the last operation.
        """
        return self.db.changes()

    def total_changes(self) -> Int64:
        """Returns the total number of rows that were changed, inserted, or deleted
        since the database connection was opened.

        Returns:
            The total number of rows changed since the connection was opened.
        """
        return self.db.total_changes()

    def prepare(self, sql: String, flags: PrepFlag = PrepFlag.PREPARE_PERSISTENT) raises -> Statement[origin_of(self)]:
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
            # TODO: Switch to grapheme slicing on next Mojo release.
            var tail_stmt, _ = self.db.prepare(String(sql[byte=Int(tail) :]))
            if tail_stmt:
                raise Error(
                    "MultipleStatementsError: Prepared statement contains multiple SQL statements. Should be one."
                )

        return Statement(Pointer(to=self), RawStatement(stmt))

    def execute[P: AnyType](self, var sql: String, params: P = ()) raises -> Int64:
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

    def execute_batch(self, sql: Some[Writable]) raises:
        """Executes a batch of SQL statements.

        Args:
            sql: The batch of SQL statements to execute.

        Raises:
            Error: If the underlying SQLite call fails or if any of the statements in the batch return results, which is not supported.
        """
        var current_sql = String(sql)
        while current_sql.byte_length() > 0:
            # Is it possible to copy the sql string less here? I don't want to keep allocating strings.
            var stmt, tail = self.db.prepare(current_sql.copy(), PrepFlag.PREPARE_PERSISTENT)
            if stmt and Statement(Pointer(to=self), RawStatement(stmt)).step():
                pass  # some pragmas return results
                # raise Error("ExecuteReturnedResults: The executed batch returned results, which is not supported.")

            if tail == 0 or Int(tail) >= current_sql.byte_length():
                break

            current_sql = String(current_sql[byte=Int(tail) :])

    def path(self) -> Optional[Path]:
        """Returns the file path of the database.

        Returns:
            The file path of the database, or None if the database is in-memory.
        """
        return self.db.path()

    def last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row.

        Returns:
            The row ID of the last inserted row.
        """
        return self.db.last_insert_row_id()

    # def one_column[P: AnyType, //, T: FromSQL](self, var sql: String, params: P = ()) raises -> T:
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
    #     def get_item(row: Row) raises -> T:
    #         return row.get[T](0)

    #     return self.prepare(sql^).query[get_item](params)

    def one_row[
        T: Movable, P: AnyType, //, transform: RowTransformFn[T],
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
        var stmt = self.prepare(sql^)
        var rows = stmt.query[transform](params)
        try:
            return next(rows)
        except StopIteration:
            raise Error("No rows returned by query.")

    def column_exists(
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

    def table_exists(
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

    def column_metadata(
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

    def exists(
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

    def transaction(self, behavior: Optional[TransactionBehavior] = None) raises -> Transaction[origin_of(self)]:
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

        def perform_queries(mut conn: Connection) raises:
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

    def savepoint(self, name: Optional[String] = None) raises -> Savepoint[origin_of(self)]:
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
        def perform_queries(mut conn: Connection) raises:
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

    def pragma_query_value[
        T: Movable,
        //,
        transform: def(Row) raises thin -> T,
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

        def get_int(r: Row) raises -> Int:
            return r.get[Int](0)

        def main() raises:
            var db = Connection.open_in_memory()
            var user_version = db.pragma_query_value[get_int]("user_version")
            print(user_version)
        ```
        """
        var query = Sql()
        query.push_pragma(pragma, schema)
        return self.one_row[transform](String(query))

    def pragma_query[
        callback: def(Row) raises thin -> None
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

        def print_collation(r: Row) raises:
            var name = r.get[String](1)
            print(name)

        def main() raises:
            var db = Connection.open_in_memory()
            db.pragma_query[print_collation](None, "collation_list")
        ```
        """
        var query = Sql()
        query.push_pragma(pragma, schema)
        for row in self.prepare(String(query)).query(()):
            callback(row)

    def pragma[
        T: AnyType, //, callback: def(Row) raises thin -> None
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

        def print_column(r: Row) raises:
            var col = r.get[String](1)
            print(col)

        def main() raises:
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

    def pragma_update[
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

        def main() raises:
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

    def pragma_update_and_check[
        T: Movable, V: AnyType, //, transform: def(Row) raises thin -> T
    ](self, pragma: StringSlice, value: V, schema: Optional[String] = None) raises -> T:
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

        def get_string(r: Row) raises -> String:
            return r.get[String](0)

        def main() raises:
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
    def create_scalar_function[
        P: CopyDestructible, V: MoveDestructible, //, x_func: ScalarUDF[V]
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
            P: The type of the application data to pass to the callback. Must be Copyable and ImplicitlyDestructible.
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
    def create_scalar_function[
        V: MoveDestructible, //, x_func: ScalarUDF[V]
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

    def create_aggregate_function[
        A: MoveDestructible,
        T: MoveDestructible,
        P: CopyDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
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

    def create_aggregate_function[
        A: MoveDestructible,
        T: MoveDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
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
            fn_name, n_arg, flags, user_data,
        )
        self.raise_if_error(result)

    def create_window_function[
        A: CopyDestructible,
        T: MoveDestructible,
        //,
        init_fn: AggregateInitUDF[A],
        step_fn: AggregateStepUDF[A],
        final_fn: AggregateFinalUDF[A, T],
        value_fn: WindowAggregateValueUDF[A, T],
        inverse_fn: WindowAggregateInverseUDF[A],
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

    def remove_function(self, fn_name: String, n_arg: Int) raises:
        """Remove a user-defined function from a database connection.

        `fn_name` and `n_arg` should match the name and number of arguments
        given to `create_scalar_function`, `create_aggregate_function`, or
        `create_window_function`.

        Args:
            fn_name: Name of the SQL function to remove.
            n_arg: Number of arguments the function was registered with.

        Raises:
            Error: If the function could not be removed.
        """
        # To delete a function, pass NULL for all callbacks and pApp,
        # with UTF8 encoding.
        var result = self.db.remove_function(fn_name, n_arg)
        self.raise_if_error(result)

    def busy_timeout(self, ms: Int) raises:
        """Set a busy handler that sleeps for a specified amount of time when a
        table is locked.

        The handler will sleep multiple times until at least `ms` milliseconds
        of sleeping have accumulated. Calling this with an argument equal to
        zero turns off all busy handlers.

        There can only be a single busy handler for a particular database
        connection at any given moment. If another busy handler was defined
        (using `busy_handler`) prior to calling this routine, that other busy
        handler is cleared.

        Newly created connections currently have a default busy timeout of
        5000ms, but this may be subject to change.

        Args:
            ms: Maximum time to wait in milliseconds. Pass 0 to disable.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.raise_if_error(self.db.busy_timeout(c_int(ms)))

    def register_busy_handler[callback: Optional[BusyHandlerFn]](self) raises:
        """Register a callback to handle `SQLITE_BUSY` errors.

        If `callback` is `None`, then `SQLITE_BUSY` is returned immediately
        upon encountering the lock. The argument to the busy handler callback
        is the number of times that the busy handler has been invoked
        previously for the same locking event. If the busy callback returns
        `False`, then no additional attempts are made to access the database
        and `SQLITE_BUSY` is returned to the application. If the callback
        returns `True`, then another attempt is made to access the database
        and the cycle repeats.

        There can only be a single busy handler defined for each database
        connection. Setting a new busy handler clears any previously set
        handler. Note that calling `busy_timeout()` or evaluating
        `PRAGMA busy_timeout=N` will change the busy handler and thus clear
        any previously set busy handler.

        Newly created connections default to a `busy_timeout()` handler with a
        timeout of 5000ms, although this is subject to change.

        Parameters:
            callback: Busy handler callback function.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.raise_if_error(self.db.busy_handler[callback]())
    
    def clear_busy_handler(self) raises:
        """Clear the busy handler, if any."""
        self.raise_if_error(self.db.busy_handler[None]())

    def limit(self, limit: Limit) raises -> Int32:
        """Returns the current value of a run-time `Limit`.

        Args:
            limit: The limit category to query.

        Returns:
            The current value of the limit.

        Raises:
            Error: If the limit category is invalid.
        """
        var rc = self.db.limit(limit)
        if rc < 0:
            raise Error(t"{limit} is invalid")
        return rc

    def set_limit(self, limit: Limit, new_val: Int32) raises -> Int32:
        """Changes a run-time `Limit`, returning the prior value.

        Args:
            limit: The limit category to change.
            new_val: The new value for the limit. Must be non-negative.

        Returns:
            The previous value of the limit.

        Raises:
            Error: If `new_val` is negative or the limit category is invalid.
        """
        if new_val < 0:
            raise Error(t"{new_val} is invalid")
        var rc = self.db.set_limit(limit, new_val)
        if rc < 0:
            raise Error(t"{limit} is invalid")
        return rc

    def register_trace_function[trace_fn: TraceFn](self, mask: TraceEventCodes) raises:
        """Register or clear a trace callback.

        When `trace_fn` is provided, it will be called for each trace event
        whose type is selected by `mask`. Pass `None` to disable tracing.

        There can only be a single tracer per connection. Setting a new tracer
        replaces the previous one.

        Parameters:
            trace_fn: A `TraceFn` callback.

        Args:
            mask: Bitmask of `TraceEventCodes` to monitor.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.raise_if_error(self.db.trace_v2[trace_fn](mask))
    
    def clear_trace_function(self) raises:
        """Clear the trace callback, if any."""
        self.raise_if_error(self.db.trace_v2[None](TraceEventCodes.empty()))

    def log(self, err_code: Int32, mut msg: String):
        """Write a message to the SQLite error log.

        Args:
            err_code: An SQLite error code to associate with the message.
            msg: The log message text.
        """
        self.db.log(err_code, msg)

    def enable_extension_loading(mut self) raises -> ExtensionLoadGuard[origin_of(self)]:
        """Enable extension loading for this connection.

        Returns:
            An `ExtensionLoadGuard` which will require explicitly disabling extension loading.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.raise_if_error(self.db.set_extension_loading(enable=True))
        return ExtensionLoadGuard(Pointer(to=self))

    def disable_extension_loading(mut self) raises:
        """Disable extension loading for this connection.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.raise_if_error(self.db.set_extension_loading(enable=False))

    def load_extension(mut self, dylib_path: String, entry_point: Optional[String] = None) raises:
        """Load an SQLite extension library.

        Extension loading must first be enabled via `enable_extension_loading()`.

        Args:
            dylib_path: File path to the shared library containing the extension.
            entry_point: Name of the entry point function. If None, SQLite uses
                the default entry point.

        Raises:
            Error: If the extension cannot be loaded.
        """
        self.db.load_extension(dylib_path, entry_point)

    def is_locked(self, rc: SQLite3Result) -> Bool:
        """Check whether a result code indicates shared-cache lock contention.

        Args:
            rc: The result code returned by a recent SQLite API call.

        Returns:
            True if the error is SQLITE_LOCKED due to shared-cache contention.
        """
        return self.db.is_locked(rc)

    def wait_for_unlock_notify(self) -> SQLite3Result:
        """Block until an unlock-notify callback fires, then return SQLITE_OK.

        Should only be called after a `SQLITE_LOCKED` result in shared-cache mode.
        If registering the notification would cause deadlock, returns SQLITE_LOCKED
        immediately; the caller should roll back the current transaction.

        Returns:
            SQLITE_OK when the lock is released, or an error code.
        """
        return self.db.wait_for_unlock_notify()

