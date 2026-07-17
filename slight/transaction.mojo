from std.os import abort
from slight.connection import Connection
from slight.params import Params
from slight.row import RowTransformFn
from slight.types.from_sql import FromSQL


@fieldwise_init
struct TransactionBehavior(Equatable, ImplicitlyCopyable, TrivialRegisterPassable):
    """Options for transaction behavior.

    See [BEGIN TRANSACTION](http://www.sqlite.org/lang_transaction.html) for details.
    """

    var value: Int
    """Internal enum value."""
    comptime DEFERRED = Self(0)
    """DEFERRED means that the transaction does not actually start until the
    database is first accessed."""
    comptime IMMEDIATE = Self(1)
    """IMMEDIATE cause the database connection to start a new write
    immediately, without waiting for a writes statement."""
    comptime EXCLUSIVE = Self(2)
    """EXCLUSIVE prevents other database connections from reading the database
    while the transaction is underway."""

    def __eq__(self, other: Self) -> Bool:
        """Check if two values are equal.

        Args:
            other: The other value to compare against.

        Returns:
            True if the values are equal, False otherwise.
        """
        return self.value == other.value

    def to_sql(self) -> StaticString:
        """Convert the transaction behavior to its SQL representation.

        Returns:
            The SQL string corresponding to the transaction behavior.
        """
        if self == Self.DEFERRED:
            return "BEGIN DEFERRED"
        elif self == Self.IMMEDIATE:
            return "BEGIN IMMEDIATE"
        else:  # EXCLUSIVE
            return "BEGIN EXCLUSIVE"


@fieldwise_init
struct DeleteBehavior(Equatable, ImplicitlyCopyable, TrivialRegisterPassable):
    """Options for how a Transaction or Savepoint should behave when it is deleted."""

    var value: Int
    """Internal enum value."""
    comptime ROLLBACK = Self(0)
    """Roll back the changes. This is the default."""
    comptime COMMIT = Self(1)
    """Commit the changes."""
    comptime IGNORE = Self(2)
    """Do not commit or roll back changes - this will leave the transaction or
    savepoint open, so should be used with care."""
    comptime PANIC = Self(3)
    """Panic. Used to enforce intentional behavior during development."""

    def __eq__(self, other: Self) -> Bool:
        """Check if two DeleteBehavior values are equal.

        Args:
            other: The other value to compare against.

        Returns:
            True if the values are equal, False otherwise.
        """
        return self.value == other.value


@fieldwise_init
struct TransactionState(Equatable, ImplicitlyCopyable, TrivialRegisterPassable):
    """Transaction state of a database."""

    var value: Int
    """Internal enum value."""
    comptime NONE = Self(0)
    """No transaction is active. Equivalent to `SQLITE_TXN_NONE`."""
    comptime READ = Self(1)
    """A read transaction is active. Equivalent to `SQLITE_TXN_READ`."""
    comptime WRITE = Self(2)
    """A write transaction is active. Equivalent to `SQLITE_TXN_WRITE`."""

    def __eq__(self, other: Self) -> Bool:
        """Check if two values are equal.

        Args:
            other: The other value to compare against.

        Returns:
            True if the values are equal, False otherwise.
        """
        return self.value == other.value


struct Transaction[conn_origin: ImmutOrigin](Movable):
    """Represents a transaction on a database connection.

    Parameters:
        conn_origin: The immutable origin of the database connection pointer.

    #### Note:

    Transactions will roll back by default. Use `commit` method to explicitly
    commit the transaction, or use `rollback` to roll back when the transaction is deleted.

    #### Example:

    ```mojo
    from slight import Connection
    def perform_queries(mut conn: Connection) raises:
        var tx = conn.transaction()

        _ = tx.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
        _ = tx.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

        tx.commit()
    ```
    """

    var conn: Pointer[Connection, Self.conn_origin]
    """A pointer to the database connection."""
    var delete_behavior: DeleteBehavior
    """The behavior when the transaction is deleted."""
    var finished: Bool
    """Whether the transaction has been finished (committed or rolled back)."""

    def __init__(
        out self,
        conn: Pointer[Connection, Self.conn_origin],
        behavior: TransactionBehavior = TransactionBehavior.DEFERRED,
        delete_behavior: DeleteBehavior = DeleteBehavior.ROLLBACK
    ) raises:
        """Begin a new transaction.

        Args:
            conn: The database connection.
            behavior: The transaction behavior (DEFERRED, IMMEDIATE, or EXCLUSIVE).
            delete_behavior: The cleanup behavior, defaults to ROLLBACK.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn = conn
        self.delete_behavior = delete_behavior
        self.finished = False
        try:
            conn[].execute_batch(behavior.to_sql())
        except e:
            self^.finish()
            raise e^

    def __del__(deinit self):
        """Destructor for the Transaction.

        If the transaction has not been finished (committed or rolled back),
        it will be finished according to the current `delete_behavior`.
        """
        try:
            self^.finish()
        except:
            # There's not much we can do in a destructor if finish fails.
            # If a user wants to handle errors, they should use finish() directly.
            pass

    def __enter__(var self) -> Self:
        """Enter the transaction context manager.

        Returns:
            The transaction.
        """
        return self^

    def savepoint(self, name: Optional[String] = None) raises -> Savepoint[Self.conn_origin]:
        """Create a new savepoint within this transaction.

        Args:
            name: The name of the savepoint. If None, a default name is used.

        Returns:
            A new `Savepoint` instance.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        if name:
            return Savepoint[Self.conn_origin](self.conn, name.value())
        else:
            return Savepoint[Self.conn_origin](self.conn)

    def execute[P: AnyType](self, var sql: String, params: P = ()) raises -> Int64:
        """Executes a SQL statement with the given parameters on the underlying connection.

        Thin forwarding method to `Connection.execute`.

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
        return self.conn[].execute(sql^, params)

    def execute_batch(self, sql: Some[Writable]) raises:
        """Executes a batch of SQL statements on the underlying connection.

        Thin forwarding method to `Connection.execute_batch`.

        Args:
            sql: The batch of SQL statements to execute.

        Raises:
            Error: If the underlying SQLite call fails while preparing the statement.
        """
        self.conn[].execute_batch(sql)

    # NOTE: `prepare` is intentionally NOT forwarded here. `Connection.prepare`
    # computes its return origin from an implicit `self` borrow, which the
    # compiler treats as a distinct derived origin (`origin_of(conn_origin)`)
    # from `Self.conn_origin` itself. Every attempted signature for a thin
    # forwarding wrapper hit:
    #   "cannot implicitly convert 'Statement[origin_of(conn_origin)]' value
    #    to 'Statement[conn_origin]'"
    # Use `tx.prepare(...)` / `sp.prepare(...)` directly instead.

    def one_row[
        T: Movable,
        P: AnyType,
        //,
        transform: RowTransformFn[T],
    ](self, var sql: String, params: P = ()) raises -> T:
        """Executes a SQL query and returns a single row, using the underlying connection.

        Thin forwarding method to `Connection.one_row`.

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
        return self.conn[].one_row[transform](sql^, params)

    def maybe_one_row[
        T: Movable,
        P: AnyType,
        //,
        transform: RowTransformFn[T],
    ](self, var sql: String, params: P = ()) raises -> Optional[T]:
        """Executes a SQL query and returns a single row, or None if no rows are returned.

        Thin forwarding method to `Connection.maybe_one_row`.

        Parameters:
            T: The type to transform the row into.
            P: The type of the parameters to bind. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).
            transform: A function to transform the row into the desired type.

        Args:
            sql: The SQL query to execute.
            params: The parameters to bind to the SQL query. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Returns:
            The single row returned by the query, or None if the query returned no rows.

        Raises:
            Error: If the query fails.
        """
        return self.conn[].maybe_one_row[transform](sql^, params)

    def one_column[T: Movable, P: AnyType](self, var sql: String, params: P = ()) raises -> T:
        """Fetches a single column from the first row of the result set, using the underlying connection.

        Thin forwarding method to `Connection.one_column`.

        Parameters:
            T: The type to retrieve the value as. Must conform to `FromSQL`.
            P: The type of the parameters to bind. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Args:
            sql: The SQL query to execute.
            params: The parameters to bind to the SQL query. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Returns:
            The value of the first column in the first row of the result set.

        Raises:
            Error: If the query fails or no rows are returned.
        """
        return self.conn[].one_column[T](sql^, params)

    def last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row, using the underlying connection.

        Thin forwarding method to `Connection.last_insert_row_id`.

        Returns:
            The row ID of the last inserted row.
        """
        return self.conn[].last_insert_row_id()

    def changes(self) -> Int64:
        """Returns the number of rows changed, inserted, or deleted by the most
        recent SQL statement on the underlying connection.

        Thin forwarding method to `Connection.changes`.

        Returns:
            The number of rows changed by the last operation.
        """
        return self.conn[].changes()

    def commit(mut self) raises:
        """A convenience method which consumes and commits a transaction.

        Raises:
            Error: If the commit fails.
        """
        self.conn[].execute_batch("COMMIT")
        self.finished = True

    def rollback(mut self) raises:
        """A convenience method which consumes and rolls back a transaction.

        Raises:
            Error: If the rollback fails.
        """
        self.conn[].execute_batch("ROLLBACK")
        self.finished = True

    def finish(deinit self) raises:
        """Consumes the transaction, committing or rolling back according to the
        current setting (see `delete_behavior`).

        Functionally equivalent to the destructor implementation, but allows
        callers to see any errors that occur.

        Raises:
            Error: If the finish operation fails.
        """
        if self.finished:
            return

        if self.conn[].is_autocommit():
            return

        if self.delete_behavior == DeleteBehavior.COMMIT:
            try:
                self.commit()
            except:
                # If commit fails, try to rollback
                self.rollback()
        elif self.delete_behavior == DeleteBehavior.ROLLBACK:
            self.rollback()
        elif self.delete_behavior == DeleteBehavior.IGNORE:
            return
        elif self.delete_behavior == DeleteBehavior.PANIC:
            raise Error("Transaction deleted unexpectedly")


struct Savepoint[conn_origin: ImmutOrigin](Movable):
    """Represents a savepoint on a database connection.

    Parameters:
        conn_origin: The immutable origin of the database connection pointer.

    #### Note:

    Savepoints will roll back by default. Use `commit` method to explicitly
    commit the savepoint, or use `rollback` to roll back when the savepoint is deleted.

    #### Example:

    ```mojo
    from slight import Connection

    def perform_queries(mut conn: Connection) raises:
        var sp = conn.savepoint()

        _ = sp.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
        _ = sp.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

        sp.commit()
    ```
    """

    var conn: Pointer[Connection, Self.conn_origin]
    """A pointer to the database connection."""
    var name: String
    """The name of the savepoint."""
    var delete_behavior: DeleteBehavior
    """The behavior when the savepoint is deleted."""
    var committed: Bool
    """Whether the savepoint has been committed."""

    def __init__(
        out self,
        conn: Pointer[Connection, Self.conn_origin],
        name: String = "_slight_sp",
        delete_behavior: DeleteBehavior = DeleteBehavior.ROLLBACK
    ) raises:
        """Begin a new savepoint.

        Args:
            conn: The database connection.
            name: The name of the savepoint. Defaults to "_slight_sp".
            delete_behavior: The cleanup behavior, defaults to ROLLBACK.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn = conn
        self.name = name
        self.delete_behavior = delete_behavior
        self.committed = False
        try:
            conn[].execute_batch(t"SAVEPOINT {name}")
        except e:
            self^.finish()
            raise e^

    def __del__(deinit self):
        """Destructor for the Savepoint.

        If the savepoint has not been committed, it will be rolled back.
        """
        try:
            self^.finish()
        except:
            # There's not much we can do in a destructor if finish fails.
            # If a user wants to handle errors, they should use finish() directly.
            pass

    def __enter__(var self) -> Self:
        """Enter the savepoint context manager.

        Returns:
            The savepoint.
        """
        return self^

    def savepoint(self, name: Optional[String] = None) raises -> Self:
        """Create a new nested savepoint within this savepoint.

        Args:
            name: The name of the nested savepoint. If None, a default name is used.

        Returns:
            A new `Savepoint` instance.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        if name:
            return Self(self.conn, name.value())
        else:
            return Self(self.conn)

    def execute[P: AnyType](self, var sql: String, params: P = ()) raises -> Int64:
        """Executes a SQL statement with the given parameters on the underlying connection.

        Thin forwarding method to `Connection.execute`.

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
        return self.conn[].execute(sql^, params)

    def execute_batch(self, sql: Some[Writable]) raises:
        """Executes a batch of SQL statements on the underlying connection.

        Thin forwarding method to `Connection.execute_batch`.

        Args:
            sql: The batch of SQL statements to execute.

        Raises:
            Error: If the underlying SQLite call fails while preparing the statement.
        """
        self.conn[].execute_batch(sql)

    # NOTE: `prepare` is intentionally NOT forwarded here. `Connection.prepare`
    # computes its return origin from an implicit `self` borrow, which the
    # compiler treats as a distinct derived origin (`origin_of(conn_origin)`)
    # from `Self.conn_origin` itself. Every attempted signature for a thin
    # forwarding wrapper hit:
    #   "cannot implicitly convert 'Statement[origin_of(conn_origin)]' value
    #    to 'Statement[conn_origin]'"
    # Use `tx.prepare(...)` / `sp.prepare(...)` directly instead.

    def one_row[
        T: Movable,
        P: AnyType,
        //,
        transform: RowTransformFn[T],
    ](self, var sql: String, params: P = ()) raises -> T:
        """Executes a SQL query and returns a single row, using the underlying connection.

        Thin forwarding method to `Connection.one_row`.

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
        return self.conn[].one_row[transform](sql^, params)

    def maybe_one_row[
        T: Movable,
        P: AnyType,
        //,
        transform: RowTransformFn[T],
    ](self, var sql: String, params: P = ()) raises -> Optional[T]:
        """Executes a SQL query and returns a single row, or None if no rows are returned.

        Thin forwarding method to `Connection.maybe_one_row`.

        Parameters:
            T: The type to transform the row into.
            P: The type of the parameters to bind. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).
            transform: A function to transform the row into the desired type.

        Args:
            sql: The SQL query to execute.
            params: The parameters to bind to the SQL query. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Returns:
            The single row returned by the query, or None if the query returned no rows.

        Raises:
            Error: If the query fails.
        """
        return self.conn[].maybe_one_row[transform](sql^, params)

    def one_column[T: Movable, P: AnyType](self, var sql: String, params: P = ()) raises -> T:
        """Fetches a single column from the first row of the result set, using the underlying connection.

        Thin forwarding method to `Connection.one_column`.

        Parameters:
            T: The type to retrieve the value as. Must conform to `FromSQL`.
            P: The type of the parameters to bind. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Args:
            sql: The SQL query to execute.
            params: The parameters to bind to the SQL query. Must conform to the `Params` trait (e.g., a tuple or a list of parameters).

        Returns:
            The value of the first column in the first row of the result set.

        Raises:
            Error: If the query fails or no rows are returned.
        """
        return self.conn[].one_column[T](sql^, params)

    def last_insert_row_id(self) -> Int64:
        """Returns the row ID of the last inserted row, using the underlying connection.

        Thin forwarding method to `Connection.last_insert_row_id`.

        Returns:
            The row ID of the last inserted row.
        """
        return self.conn[].last_insert_row_id()

    def changes(self) -> Int64:
        """Returns the number of rows changed, inserted, or deleted by the most
        recent SQL statement on the underlying connection.

        Thin forwarding method to `Connection.changes`.

        Returns:
            The number of rows changed by the last operation.
        """
        return self.conn[].changes()

    def commit(mut self) raises:
        """A convenience method which consumes and commits a savepoint.

        Raises:
            Error: If the commit fails.
        """
        self.conn[].execute_batch(t"RELEASE {self.name}")
        self.committed = True

    def rollback(mut self) raises:
        """Roll back a savepoint.

        ## Note

        Unlike Transactions, savepoints remain active after they have been
        rolled back, and can be rolled back again or committed.

        Raises:
            Error: If the rollback fails.
        """
        self.conn[].execute_batch(t"ROLLBACK TO {self.name}")

    def finish(deinit self) raises:
        """Consumes the savepoint, committing or rolling back according to the
        current setting (see `delete_behavior`).

        Functionally equivalent to the destructor implementation, but allows
        callers to see any errors that occur.

        Raises:
            Error: If the finish operation fails.
        """
        if self.committed:
            return

        if self.delete_behavior == DeleteBehavior.COMMIT:
            try:
                self.commit()
            except:
                # If commit fails, try to rollback and then commit
                self.rollback()
                self.commit()
        elif self.delete_behavior == DeleteBehavior.ROLLBACK:
            self.rollback()
            self.commit()  # Release the savepoint after rollback
        elif self.delete_behavior == DeleteBehavior.IGNORE:
            pass
        elif self.delete_behavior == DeleteBehavior.PANIC:
            raise Error("Savepoint deleted unexpectedly")