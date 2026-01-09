from memory import Pointer
from os import abort
from slight.connection import Connection


@fieldwise_init
@register_passable("trivial")
struct TransactionBehavior(ImplicitlyCopyable, Equatable):
    """Options for transaction behavior.
    
    See [BEGIN TRANSACTION](http://www.sqlite.org/lang_transaction.html) for details.
    """
    
    var value: Int
    comptime DEFERRED = Self(0)
    """DEFERRED means that the transaction does not actually start until the
    database is first accessed."""
    comptime IMMEDIATE = Self(1)
    """IMMEDIATE cause the database connection to start a new write
    immediately, without waiting for a writes statement."""
    comptime EXCLUSIVE = Self(2)
    """EXCLUSIVE prevents other database connections from reading the database
    while the transaction is underway."""
    
    fn __eq__(self, other: Self) -> Bool:
        """Check if two TransactionBehavior values are equal."""
        return self.value == other.value
    
    fn to_sql(self) -> String:
        """Convert the transaction behavior to its SQL representation."""
        if self == Self.DEFERRED:
            return "BEGIN DEFERRED"
        elif self == Self.IMMEDIATE:
            return "BEGIN IMMEDIATE"
        else:  # EXCLUSIVE
            return "BEGIN EXCLUSIVE"


@fieldwise_init
@register_passable("trivial")
struct DropBehavior(ImplicitlyCopyable, Equatable):
    """Options for how a Transaction or Savepoint should behave when it is dropped."""
    
    var value: Int
    comptime ROLLBACK = Self(0)
    """Roll back the changes. This is the default."""
    comptime COMMIT = Self(1)
    """Commit the changes."""
    comptime IGNORE = Self(2)
    """Do not commit or roll back changes - this will leave the transaction or
    savepoint open, so should be used with care."""
    comptime PANIC = Self(3)
    """Panic. Used to enforce intentional behavior during development."""

    fn __eq__(self, other: Self) -> Bool:
        """Check if two DropBehavior values are equal."""
        return self.value == other.value


@fieldwise_init
@register_passable("trivial")
struct TransactionState(ImplicitlyCopyable, Equatable):
    """Transaction state of a database."""
    
    var value: Int
    comptime NONE = Self(0)
    """No transaction is active. Equivalent to `SQLITE_TXN_NONE`."""
    comptime READ = Self(1)
    """A read transaction is active. Equivalent to `SQLITE_TXN_READ`."""
    comptime WRITE = Self(2)
    """A write transaction is active. Equivalent to `SQLITE_TXN_WRITE`."""

    fn __eq__(self, other: Self) -> Bool:
        """Check if two TransactionState values are equal."""
        return self.value == other.value


struct Transaction[conn_origin: ImmutOrigin](Movable):
    """Represents a transaction on a database connection.

    ## Note

    Transactions will roll back by default. Use `commit` method to explicitly
    commit the transaction, or use `set_drop_behavior` to change what happens
    when the transaction is dropped.

    ## Example

    ```mojo
    from slight import Connection
    fn perform_queries(mut conn: Connection) raises:
        var tx = conn.transaction()
        
        _ = tx.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
        _ = tx.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

        tx.commit()
    ```
    """
    
    var conn: Pointer[Connection, Self.conn_origin]
    """A pointer to the database connection."""
    var drop_behavior: DropBehavior
    """The behavior when the transaction is dropped."""
    var finished: Bool
    """Whether the transaction has been finished (committed or rolled back)."""
    
    fn __init__(
        out self,
        conn: Pointer[Connection, Self.conn_origin],
        behavior: TransactionBehavior = TransactionBehavior.DEFERRED,
    ) raises:
        """Begin a new transaction.

        Args:
            conn: The database connection.
            behavior: The transaction behavior (DEFERRED, IMMEDIATE, or EXCLUSIVE).

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn = conn
        self.drop_behavior = DropBehavior.ROLLBACK
        self.finished = False
        try:
            conn[].execute_batch(behavior.to_sql())
        except e:
            self^.finish()
            raise e^
    
    fn __del__(deinit self):
        try:
            self^.finish()
        except:
            # There's not much we can do in a destructor if finish fails.
            # If a user wants to handle errors, they should use finish() directly.
            pass
    
    fn __enter__(var self) -> Self:
        return self^
    
    fn savepoint(self, name: Optional[String] = None) raises -> Savepoint[Self.conn_origin]:
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
    
    fn commit(mut self) raises:
        """A convenience method which consumes and commits a transaction.
        
        Raises:
            Error: If the commit fails.
        """
        self.conn[].execute_batch("COMMIT")
        self.finished = True
    
    fn rollback(mut self) raises:
        """A convenience method which consumes and rolls back a transaction.
        
        Raises:
            Error: If the rollback fails.
        """
        self.conn[].execute_batch("ROLLBACK")
        self.finished = True
    
    fn finish(deinit self) raises:
        """Consumes the transaction, committing or rolling back according to the
        current setting (see `drop_behavior`).

        Functionally equivalent to the destructor implementation, but allows
        callers to see any errors that occur.
        
        Raises:
            Error: If the finish operation fails.
        """
        if self.finished:
            return
        
        if self.conn[].is_autocommit():
            return
        
        if self.drop_behavior == DropBehavior.COMMIT:
            try:
                self.commit()
            except:
                # If commit fails, try to rollback
                self.rollback()
        elif self.drop_behavior == DropBehavior.ROLLBACK:
            self.rollback()
        elif self.drop_behavior == DropBehavior.IGNORE:
            return
        elif self.drop_behavior == DropBehavior.PANIC:
            abort("Transaction dropped unexpectedly")


struct Savepoint[conn_origin: ImmutOrigin](Movable):
    """Represents a savepoint on a database connection.

    ## Note

    Savepoints will roll back by default. Use `commit` method to explicitly
    commit the savepoint, or use `set_drop_behavior` to change what happens
    when the savepoint is dropped.

    ## Example

    ```mojo
    from slight import Connection

    fn perform_queries(mut conn: Connection) raises:
        var sp = conn.savepoint()
        
        _ = sp.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
        _ = sp.conn[].execute("INSERT INTO users (name) VALUES (?)", ["Bob"])
        
        sp.commit()
    ```
    """
    
    var conn: Pointer[Connection, Self.conn_origin]
    """A pointer to the database connection."""
    var name: String
    """The name of the savepoint."""
    var drop_behavior: DropBehavior
    """The behavior when the savepoint is dropped."""
    var committed: Bool
    """Whether the savepoint has been committed."""
    
    fn __init__(
        out self,
        conn: Pointer[Connection, Self.conn_origin],
        name: String = "_slight_sp",
    ) raises:
        """Begin a new savepoint.

        Args:
            conn: The database connection.
            name: The name of the savepoint. Defaults to "_slight_sp".

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn = conn
        self.name = name
        self.drop_behavior = DropBehavior.ROLLBACK
        self.committed = False
        try:
            conn[].execute_batch(String("SAVEPOINT ", name))
        except e:
            self^.finish()
            raise e^
    
    fn __del__(deinit self):
        try:
            self^.finish()
        except:
            # There's not much we can do in a destructor if finish fails.
            # If a user wants to handle errors, they should use finish() directly.
            pass
    
    fn __enter__(var self) -> Self:
        return self^
    
    fn savepoint(self, name: Optional[String] = None) raises -> Self:
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
    
    fn commit(mut self) raises:
        """A convenience method which consumes and commits a savepoint.
        
        Raises:
            Error: If the commit fails.
        """
        self.conn[].execute_batch(String("RELEASE ", self.name))
        self.committed = True

    fn rollback(mut self) raises:
        """Roll back a savepoint.

        ## Note

        Unlike Transactions, savepoints remain active after they have been
        rolled back, and can be rolled back again or committed.
        
        Raises:
            Error: If the rollback fails.
        """
        self.conn[].execute_batch(String("ROLLBACK TO ", self.name))
    
    fn finish(deinit self) raises:
        """Consumes the savepoint, committing or rolling back according to the
        current setting (see `drop_behavior`).

        Functionally equivalent to the destructor implementation, but allows
        callers to see any errors that occur.
        
        Raises:
            Error: If the finish operation fails.
        """
        if self.committed:
            return
        
        if self.drop_behavior == DropBehavior.COMMIT:
            try:
                self.commit()
            except:
                # If commit fails, try to rollback and then commit
                self.rollback()
                self.commit()
        elif self.drop_behavior == DropBehavior.ROLLBACK:
            self.rollback()
            self.commit()  # Release the savepoint after rollback
        elif self.drop_behavior == DropBehavior.IGNORE:
            pass
        elif self.drop_behavior == DropBehavior.PANIC:
            raise Error("Savepoint dropped unexpectedly")
