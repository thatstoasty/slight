"""Transaction and Savepoint Examples.

This example demonstrates how to use transactions and savepoints in slight
for atomic database operations with rollback capabilities.
"""

from slight.connection import Connection
from slight.transaction import Transaction, Savepoint, TransactionBehavior, DropBehavior
from slight.row import Row
from slight import Int, Bool, SIMD, Dict, List
from slight.types.to_sql import SIMD

comptime dummy_int: Int = 1
comptime dummy_float: Float64 = 1.0
comptime dummy_bool: Bool = False


fn print_account_balances(db: Connection) raises:
    """Helper function to print all account balances."""
    print("Current account balances:")
    var stmt = db.prepare("SELECT name, balance FROM accounts ORDER BY name")
    for row in stmt.query():
        print("  ", row.get[String](0), ":", row.get[Float64](1))


fn example_basic_transaction() raises:
    """Demonstrates basic transaction usage with commit."""
    print("=== Basic Transaction Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE accounts (name TEXT, balance REAL);
        INSERT INTO accounts VALUES ('Alice', 1000.0);
        INSERT INTO accounts VALUES ('Bob', 500.0);
    """)

    print("Before transaction:")
    print_account_balances(db)

    # Use a transaction to transfer money atomically
    with db.transaction() as tx:
        # Deduct from Alice
        _ = tx.conn[].execute(
            "UPDATE accounts SET balance = balance - ?1 WHERE name = ?2",
            200.0, "Alice"
        )
        # Add to Bob
        _ = tx.conn[].execute(
            "UPDATE accounts SET balance = balance + ?1 WHERE name = ?2",
            200.0, "Bob"
        )
        tx.commit()

    print("After committed transaction (transferred $200 from Alice to Bob):")
    print_account_balances(db)


fn example_transaction_rollback() raises:
    """Demonstrates transaction rollback - changes are discarded."""
    print("=== Transaction Rollback Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE accounts (name TEXT, balance REAL);
        INSERT INTO accounts VALUES ('Alice', 1000.0);
    """)

    print("Before transaction:")
    print_account_balances(db)

    # This transaction will be rolled back (default behavior)
    with db.transaction() as tx:
        _ = tx.conn[].execute(
            "UPDATE accounts SET balance = balance + ?1 WHERE name = ?2",
            9999.0, "Alice"
        )
        print("Inside transaction (before rollback):")
        print_account_balances(tx.conn[])
        # tx.rollback() is implicit when exiting without commit

    print("After rolled back transaction (changes discarded):")
    print_account_balances(db)


fn example_savepoints() raises:
    """Demonstrates nested savepoints for partial rollbacks."""
    print("=== Savepoints Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE inventory (item TEXT, quantity INTEGER);
        INSERT INTO inventory VALUES ('Apples', 100);
    """)

    fn print_inventory(conn: Connection) raises:
        var stmt = conn.prepare("SELECT item, quantity FROM inventory")
        for row in stmt.query():
            print("  ", row.get[String](0), ":", row.get[Int](1))

    print("Initial inventory:")
    print_inventory(db)

    with db.transaction() as tx:
        # First operation: Add oranges
        _ = tx.conn[].execute("INSERT INTO inventory VALUES (?1, ?2)", "Oranges", 50)
        print("\nAfter adding Oranges:")
        print_inventory(tx.conn[])

        # Savepoint for a risky operation
        with tx.savepoint() as sp:
            _ = sp.conn[].execute("UPDATE inventory SET quantity = ?1 WHERE item = ?2", 0, "Apples")
            print("\nInside savepoint (set Apples to 0):")
            print_inventory(sp.conn[])
            # Oops! We don't want to zero out apples, rollback this savepoint
            sp.rollback()

            # Try again with a smaller reduction
            _ = sp.conn[].execute("UPDATE inventory SET quantity = quantity - ?1 WHERE item = ?2", 10, "Apples")
            sp.commit()

        print("\nAfter savepoint (Apples reduced by 10 instead of zeroed):")
        print_inventory(tx.conn[])

        tx.commit()

    print("\nFinal inventory after transaction:")
    print_inventory(db)


fn example_nested_savepoints() raises:
    """Demonstrates deeply nested savepoints."""
    print("=== Nested Savepoints Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE log (level INTEGER, message TEXT)")

    with db.transaction() as tx:
        _ = tx.conn[].execute("INSERT INTO log VALUES (?1, ?2)", 1, "Transaction started")

        with tx.savepoint() as sp1:
            _ = sp1.conn[].execute("INSERT INTO log VALUES (?1, ?2)", 2, "Savepoint 1")

            with sp1.savepoint() as sp2:
                _ = sp2.conn[].execute("INSERT INTO log VALUES (?1, ?2)", 3, "Savepoint 2")

                with sp2.savepoint() as sp3:
                    _ = sp3.conn[].execute("INSERT INTO log VALUES (?1, ?2)", 4, "Savepoint 3 - will rollback")
                    # Rollback sp3 only
                    sp3.rollback()
                    _ = sp3.conn[].execute("INSERT INTO log VALUES (?1, ?2)", 4, "Savepoint 3 - after rollback")
                    sp3.commit()

                sp2.commit()
            sp1.commit()
        tx.commit()

    print("Log entries (notice level 4 'will rollback' is gone):")
    var stmt = db.prepare("SELECT level, message FROM log ORDER BY rowid")
    for row in stmt.query():
        print("  Level", row.get[Int](0), ":", row.get[String](1))


fn example_transaction_behaviors() raises:
    """Demonstrates different transaction isolation behaviors."""
    print("\n=== Transaction Behaviors Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE data (value INTEGER)")

    # DEFERRED: Locks are acquired lazily (default)
    print("DEFERRED transaction (default - acquires locks lazily):")
    with db.transaction(TransactionBehavior.DEFERRED) as tx:
        _ = tx.conn[].execute("INSERT INTO data VALUES (?1)", [1])
        tx.commit()
    print("  Inserted value 1")

    # IMMEDIATE: Acquires a write lock immediately
    print("IMMEDIATE transaction (acquires write lock immediately):")
    with db.transaction(TransactionBehavior.IMMEDIATE) as tx:
        _ = tx.conn[].execute("INSERT INTO data VALUES (?1)", [2])
        tx.commit()
    print("  Inserted value 2")

    # EXCLUSIVE: Prevents other connections from reading
    print("EXCLUSIVE transaction (exclusive access):")
    with db.transaction(TransactionBehavior.EXCLUSIVE) as tx:
        _ = tx.conn[].execute("INSERT INTO data VALUES (?1)", [3])
        tx.commit()
    print("  Inserted value 3")

    fn get_sum(r: Row) raises -> Int:
        return r.get[Int](0)

    var total = db.query_row[get_sum]("SELECT SUM(value) FROM data")
    print("Total sum:", total)


fn example_drop_behavior() raises:
    """Demonstrates using drop_behavior to control transaction finalization."""
    print("\n=== Drop Behavior Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE items (name TEXT)")

    # Default drop behavior is ROLLBACK
    var tx = db.transaction()
    _ = tx.conn[].execute("INSERT INTO items VALUES (?1)", ["will_rollback"])
    tx^.finish()  # Rolls back by default

    # Change drop behavior to COMMIT
    tx = db.transaction()
    _ = tx.conn[].execute("INSERT INTO items VALUES (?1)", ["will_commit"])
    tx.drop_behavior = DropBehavior.COMMIT
    tx^.finish()  # Commits because of drop_behavior

    print("Items in table (only 'will_commit' should appear):")
    var stmt = db.prepare("SELECT name FROM items")
    for row in stmt.query():
        print("  ", row.get[String](0))


fn main() raises:
    example_basic_transaction()
    example_transaction_rollback()
    example_savepoints()
    example_nested_savepoints()
    example_transaction_behaviors()
    example_drop_behavior()
