# slight

`slight` is a Mojo wrapper around the SQLite3 C library, providing a safe and ergonomic interface for interacting with SQLite databases in Mojo applications.

![Mojo Version](https://img.shields.io/badge/Mojo%F0%9F%94%A5-26.1-orange)
![Build Status](https://github.com/thatstoasty/mojo-sqlite3/actions/workflows/build.yml/badge.svg)
![Test Status](https://github.com/thatstoasty/mojo-sqlite3/actions/workflows/test.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Connection Management**: Open in-memory or file-based SQLite databases
- **Prepared Statements**: Compile SQL once, execute many times with different parameters
- **Parameter Binding**: Support for positional (`?1`, `?2`) and named (`:name`, `@name`, `$name`) parameters
- **Type-Safe Queries**: Retrieve data with type-checked column access
- **Row Mapping**: Transform rows into custom structs using mapping functions
- **Transactions**: Full transaction support with `DEFERRED`, `IMMEDIATE`, and `EXCLUSIVE` modes
- **Savepoints**: Nested savepoints for fine-grained rollback control
- **Pragma Support**: Configure SQLite behavior through pragma statements

## Installation

1. First, you'll need to configure your `pixi.toml` file to include my Conda channel. Add `"https://repo.prefix.dev/mojo-community"` to the list of channels.
2. Next, add `slight` to your project's dependencies by running `pixi add slight`.
3. Finally, run `pixi install` to install in `slight` and its dependencies. You should see the `.mojopkg` files in `$CONDA_PREFIX/lib/mojo/` (usually will resolve to `.pixi/envs/default/lib/mojo/`).

## Quick Start

### Opening a Connection

```mojo
from slight.connection import Connection

fn main() raises:
    # Open an in-memory database
    var db = Connection.open_in_memory()
    
    # Or open a file-based database
    var db = Connection.open("my_database.db")
```

### Creating Tables and Inserting Data

```mojo
from slight.connection import Connection

fn main() raises:
    var db = Connection.open_in_memory()
    
    # Execute a single statement
    _ = db.execute("""
        CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT UNIQUE
        )
    """)
    
    # Execute multiple statements at once
    db.execute_batch("""
        INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
        INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com');
    """)
```

### Querying Data

```mojo
from slight.connection import Connection
from slight import Int, String

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER);
        INSERT INTO users VALUES (1, 'Alice', 30);
        INSERT INTO users VALUES (2, 'Bob', 25);
    """)
    
    # Prepare and execute a query
    var stmt = db.prepare("SELECT * FROM users")
    for row in stmt.query():
        print("ID:", row.get[Int](0))
        print("Name:", row.get[String](1))
        print("Age:", row.get[Int](2))
```

### Using Parameters

```mojo
from slight.connection import Connection
from slight import Int, String

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    
    # Positional parameters with a list
    _ = db.execute("INSERT INTO users (name) VALUES (?1)", ["Alice"])
    
    # Named parameters with a dictionary
    _ = db.execute("INSERT INTO users (name) VALUES (:name)", {":name": "Bob"})
    
    # Query with parameters
    var stmt = db.prepare("SELECT * FROM users WHERE name = ?1")
    for row in stmt.query(["Alice"]):
        print("Found:", row.get[String](1))
```

### Transforming Rows

```mojo
from slight.connection import Connection
from slight.row import Row
from slight import Int, String

@fieldwise_init
struct User(Writable):
    var id: Int
    var name: String

    fn write_to[W: Writer, //](self, mut writer: W):
        writer.write("User(id=", self.id, ", name=", self.name, ")")

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
        INSERT INTO users VALUES (1, 'Alice');
        INSERT INTO users VALUES (2, 'Bob');
    """)
    
    fn to_user(row: Row) raises -> User:
        return User(id=row.get[Int](0), name=row.get[String](1))
    
    # Map rows to User structs
    var stmt = db.prepare("SELECT * FROM users")
    for user in stmt.query_map[transform=to_user]():
        print(user)
    
    # Get a single row
    var user = db.query_row[to_user]("SELECT * FROM users WHERE id = ?1", [1])
    print("Found:", user)
```

### Transactions

```mojo
from slight.connection import Connection
from slight.transaction import TransactionBehavior

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE accounts (name TEXT, balance REAL)")
    
    # Basic transaction with context manager
    with db.transaction() as tx:
        _ = tx.conn[].execute("INSERT INTO accounts VALUES (?1, ?2)", "Alice", 1000.0)
        _ = tx.conn[].execute("INSERT INTO accounts VALUES (?1, ?2)", "Bob", 500.0)
        tx.commit()  # Explicitly commit; otherwise rolls back on scope exit
    
    # Transaction with specific behavior
    with db.transaction(TransactionBehavior.IMMEDIATE) as tx:
        _ = tx.conn[].execute("UPDATE accounts SET balance = balance - 100 WHERE name = 'Alice'")
        _ = tx.conn[].execute("UPDATE accounts SET balance = balance + 100 WHERE name = 'Bob'")
        tx.commit()
```

### Savepoints

```mojo
from slight.connection import Connection

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE log (message TEXT)")
    
    with db.transaction() as tx:
        _ = tx.conn[].execute("INSERT INTO log VALUES (?1)", ["Step 1"])
        
        # Create a savepoint for a risky operation
        with tx.savepoint() as sp:
            _ = sp.conn[].execute("INSERT INTO log VALUES (?1)", ["Risky step"])
            # Rollback just this savepoint if something goes wrong
            sp.rollback()
            # Try again
            _ = sp.conn[].execute("INSERT INTO log VALUES (?1)", ["Safe step"])
            sp.commit()
        
        tx.commit()
```

## Supported Types

### Reading from SQL (FromSQL)

| SQLite Type | Mojo Type |
|-------------|-----------|
| INTEGER | `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` |
| REAL | `Float16`, `Float32`, `Float64` |
| TEXT | `String` |
| INTEGER (0/1) | `Bool` |

### Writing to SQL (ToSQL)

| Mojo Type | SQLite Type |
|-----------|-------------|
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | INTEGER |
| `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` | INTEGER |
| `Float16`, `Float32`, `Float64` | REAL |
| `String`, `StringLiteral`, `StringSlice` | TEXT |
| `Bool` | INTEGER (0/1) |
| `None` | NULL |

## More Examples

For more detailed examples, see the `examples/` directory:

- `01_execute.mojo` - Basic execution and querying
- `02_execute_batch.mojo` - Batch execution of multiple statements
- `03_query_and_transform.mojo` - Row transformation and mapping
- `04_transactions.mojo` - Transactions and savepoints

## Attributions

This project was heavily inspired by:

- The [rusqlite](https://github.com/rusqlite/rusqlite) Rust crate.

## TODO

1. Support features for different compilation options.
2. Coalesce different parameter specification types into a Trait, to reduce code duplication.
3. Loading custom extensions.
4. Creating custom functions and collations.
5. Once Tuple supports indexing, support binding from Tuples directly instead of using variadic arguments. Variadic arguments are currently used as a workaround, but look a little confusing IMO.
