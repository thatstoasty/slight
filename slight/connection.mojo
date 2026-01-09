from pathlib import Path

from memory import Pointer
from slight.c.api import sqlite_ffi
from slight.result import SQLite3Result
from slight.inner_connection import InnerConnection
from slight.flags import PrepFlag, OpenFlag
from slight.params import Parameter
from slight.statement import Statement
from slight.row import Row, Int  # RowIndex extension for Int
from slight.types.from_sql import FromSQL
from slight.column import ColumnMetadata
from slight.transaction import Transaction, Savepoint, TransactionBehavior


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
            Self: The newly created connection.

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
        """
        var stmt, tail = self.db.prepare(sql.copy(), flags)

        # If there is trailing SQL after the first statement that contains a valid SQL statement, raise an error.
        if tail > 0:
            var tail_stmt, _ = self.db.prepare(String(sql[Int(tail) :]))
            if tail_stmt:
                raise Error(
                    "MultipleStatementsError: Prepared statement contains multiple SQL statements. Should be one."
                )

        return Statement(Pointer(to=self), stmt)

    fn execute(self, var sql: String, params: List[Parameter] = []) raises -> Int64:
        """Executes a SQL statement with the given parameters.

        Args:
            sql: The SQL statement to execute.
            params: The parameters to bind to the SQL statement.

        Returns:
            The number of rows affected by the statement.
        """
        var stmt = self.prepare(sql^)
        try:
            return stmt.execute(params)
        finally:
            _ = stmt^.finalize()

    fn execute(self, var sql: String, params: Dict[String, Parameter]) raises -> Int64:
        """Executes a SQL statement with the given parameters.

        Args:
            sql: The SQL statement to execute.
            params: The parameters to bind to the SQL statement.

        Returns:
            The number of rows affected by the statement.
        """
        var stmt = self.prepare(sql^)
        try:
            return stmt.execute(params)
        finally:
            _ = stmt^.finalize()

    fn execute(self, var sql: String, params: List[Tuple[String, Parameter]]) raises -> Int64:
        """Executes a SQL statement with the given parameters.

        Args:
            sql: The SQL statement to execute.
            params: The parameters to bind to the SQL statement.

        Returns:
            The number of rows affected by the statement.
        """
        var stmt = self.prepare(sql^)
        try:
            return stmt.execute(params)
        finally:
            _ = stmt^.finalize()

    fn query_row[
        T: Movable, //, transform: fn (Row) raises -> T
    ](self, var sql: String, params: List[Parameter] = []) raises -> T:
        """Executes the query and returns a single row.

        This is a convenience method for queries that are expected to return exactly one row.
        If the query returns more than one row, the rest are ignored.

        Parameters:
            T: The type that the row will be transformed into.
            transform: A function that takes a Row and returns a value of type T.

        Args:
            sql: The SQL query to execute.
            params: A list of parameters to bind to the statement.

        Returns:
            The single Row returned by the query.

        Raises:
            Error: If parameter binding fails, no rows are returned, or more than one row is returned.
        """
        var stmt = self.prepare(sql^)
        return stmt.query_row[transform=transform](params)
        # try:
        #     return stmt.query_row[transform=transform](params)
        # finally:
        #     _ = stmt^.finalize()

    fn query_row[
        T: Movable, //, transform: fn (Row) raises -> T
    ](self, var sql: String, params: Dict[String, Parameter]) raises -> T:
        """Executes the query and returns a single row.

        This is a convenience method for queries that are expected to return exactly one row.
        If the query returns more than one row, the rest are ignored.

        Parameters:
            T: The type that the row will be transformed into.
            transform: A function that takes a Row and returns a value of type T.

        Args:
            sql: The SQL query to execute.
            params: A list of parameters to bind to the statement.

        Returns:
            The single Row returned by the query.

        Raises:
            Error: If parameter binding fails, no rows are returned, or more than one row is returned.
        """
        var stmt = self.prepare(sql^)
        return stmt.query_row[transform=transform](params)
        # try:
        #     return stmt.query_row[transform=transform](params)
        # finally:
        #     _ = stmt^.finalize()

    fn query_row[
        T: Movable, //, transform: fn (Row) raises -> T
    ](self, var sql: String, params: List[Tuple[String, Parameter]]) raises -> T:
        """Executes the query and returns a single row.

        This is a convenience method for queries that are expected to return exactly one row.
        If the query returns more than one row, the rest are ignored.

        Parameters:
            T: The type that the row will be transformed into.
            transform: A function that takes a Row and returns a value of type T.

        Args:
            sql: The SQL query to execute.
            params: A list of parameters to bind to the statement.

        Returns:
            The single Row returned by the query.

        Raises:
            Error: If parameter binding fails, no rows are returned, or more than one row is returned.
        """
        var stmt = self.prepare(sql^)
        return stmt.query_row[transform=transform](params)
        # try:
        #     return stmt.query_row[transform](params)
        # finally:
        #     _ = stmt^.finalize()

    fn execute_batch(self, sql: String) raises:
        """Executes a batch of SQL statements.

        Args:
            sql: The batch of SQL statements to execute.
        """
        var current_sql = sql.copy()
        while len(current_sql) > 0:
            # Is it possible to copy the sql string less here? I don't want to keep allocating strings.
            var stmt, tail = self.db.prepare(current_sql.copy(), PrepFlag.PREPARE_PERSISTENT)
            if stmt and Statement(Pointer(to=self), stmt).step():
                raise Error("ExecuteReturnedResults: The executed batch returned results, which is not supported.")

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
        """Returns the row ID of the last inserted row."""
        return self.db.last_insert_row_id()

    fn one_column[
        T: FromSQL,
    ](self, var sql: String, params: List[Parameter] = []) raises -> T:
        fn get_item(row: Row) raises -> T:
            return row.get[T](0)

        return self.query_row[get_item](sql, params)

    fn one_column[
        T: FromSQL,
    ](self, var sql: String, params: Dict[String, Parameter]) raises -> T:
        fn get_item(row: Row) raises -> T:
            return row.get[T](0)

        return self.query_row[get_item](sql, params)

    fn one_column[
        T: FromSQL,
    ](self, var sql: String, params: List[Tuple[String, Parameter]]) raises -> T:
        fn get_item(row: Row) raises -> T:
            return row.get[T](0)

        return self.query_row[get_item](sql, params)

    fn column_exists(
        self,
        db_name: Optional[String],
        table_name: String,
        column_name: String,
    ) raises -> Bool:
        """Check if `table_name`.`column_name` exists.

        Args:
            db_name: The database name (main, temp, ATTACH name), or None to search all databases.
            table_name: The name of the table.
            column_name: The name of the column.

        Returns:
            True if the column exists, False otherwise.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        return self.exists(db_name, table_name, column_name)

    fn table_exists(
        self,
        db_name: Optional[String],
        table_name: String,
    ) raises -> Bool:
        """Check if `table_name` exists.

        Args:
            db_name: The database name (main, temp, ATTACH name), or None to search all databases.
            table_name: The name of the table.

        Returns:
            True if the table exists, False otherwise.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        return self.exists(db_name, table_name, None)

    fn column_metadata(
        self,
        var db_name: Optional[String],
        var table_name: String,
        var column_name: String,
    ) raises -> ColumnMetadata:
        """Extract metadata of column at specified index.

        Args:
            db_name: The database name (main, temp, ATTACH name), or None to search all databases.
            table_name: The name of the table.
            column_name: The name of the column.

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
                db_name,
                table_name,
                column_name,
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
        var db_name: Optional[String],
        var table_name: String,
        var column_name: Optional[String],
    ) raises -> Bool:
        """Check if a table or column exists.

        Args:
            db_name: The database name or None.
            table_name: The name of the table.
            column_name: The name of the column, or None to check only table existence.

        Returns:
            True if the table/column exists, False otherwise.

        Raises:
            Error: If the underlying SQLite call fails with an unexpected error.
        """
        var r = sqlite_ffi()[].table_column_metadata(
            self.db.db,
            db_name,
            table_name,
            column_name,
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

    fn transaction(mut self, behavior: Optional[TransactionBehavior] = None) raises -> Transaction[origin_of(self)]:
        """Begin a new transaction with the default behavior (DEFERRED).

        The transaction defaults to rolling back when it is dropped. If you
        want the transaction to commit, you must call `commit()` or
        `set_drop_behavior(DropBehavior.COMMIT())`.

        ## Example

        ```mojo
        from slight import Connection

        fn perform_queries(mut conn: Connection) raises:
            var tx = conn.transaction()

            _ = tx.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
            _ = tx.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

            tx.commit()
        ```

        Returns:
            A new Transaction object.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        if behavior:
            return Transaction(Pointer(to=self), behavior.value())
        else:
            return Transaction(Pointer(to=self))

    fn savepoint(mut self, name: Optional[String] = None) raises -> Savepoint[origin_of(self)]:
        """Begin a new savepoint with the default behavior (DEFERRED).

        The savepoint defaults to rolling back when it is dropped. If you want
        the savepoint to commit, you must call `commit()` or
        `set_drop_behavior(DropBehavior.COMMIT())`.

        ## Example

        ```mojo
        from slight import Connection
        fn perform_queries(mut conn: Connection) raises:
            var sp = conn.savepoint()

            _ = sp.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
            _ = sp.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

            sp.commit()
        ```

        Returns:
            A new Savepoint object.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        if name:
            return Savepoint(Pointer(to=self), name.value())
        else:
            return Savepoint(Pointer(to=self))

