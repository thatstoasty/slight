# slight

`slight` is a Mojo wrapper around the SQLite3 C library, providing a safe and ergonomic interface for interacting with SQLite databases in Mojo applications.

![Mojo Version](https://img.shields.io/badge/Mojo%F0%9F%94%A5-26.2-orange)
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
- **Scalar Functions**: Register custom SQL functions that operate on a single row
- **Aggregate Functions**: Register custom SQL aggregate functions that process multiple rows
- **Window Functions**: Register custom SQL window functions over sliding frames

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
    for user in stmt.query[to_user]():
        print(user)
    
    # Get a single row
    var user = db.one_row[to_user]("SELECT * FROM users WHERE id = ?1", [1])
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

### Scalar Functions

Register custom SQL functions that operate on a single row:

```mojo
from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row

fn halve(ctx: Context) raises -> Float64:
    return ctx.get_double(0) / 2.0

fn main() raises:
    var db = Connection.open_in_memory()

    # Register a scalar function named "halve" that takes 1 argument
    db.create_scalar_function[halve](
        "halve",
        n_arg=1,
    )

    fn get_result(row: Row) raises -> Float64:
        return row.get[Float64](0)

    print(db.one_row[get_result]("SELECT halve(10.0)"))  # 5.0
```

### Aggregate Functions

Register custom SQL aggregate functions that process multiple rows into a single result:

```mojo
from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row

fn sum_init(mut ctx: Context) raises -> Int64:
    return 0

fn sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)

fn sum_finalize(mut ctx: Context, acc: Int64) raises -> Int64:
    return acc

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE numbers (value INTEGER);
        INSERT INTO numbers VALUES (1);
        INSERT INTO numbers VALUES (2);
        INSERT INTO numbers VALUES (3);
    """)

    db.create_aggregate_function[sum_init, sum_step, sum_finalize](
        "my_sum",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    )

    fn get_result(row: Row) raises -> Int64:
        return row.get[Int64](0)

    print(db.one_row[get_result]("SELECT my_sum(value) FROM numbers"))  # 6
```

### Window Functions

Register custom SQL window functions that operate over a sliding frame of rows. Window functions extend aggregate functions with `inverse` (to remove a row leaving the frame) and `value` (to return the current result without finalizing) callbacks:

```mojo
from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row

fn sum_init(mut ctx: Context) raises -> Int64:
    return 0

fn sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)

fn sum_finalize(mut ctx: Context, acc: Int64) raises -> Optional[Int64]:
    return acc

fn sum_inverse(mut ctx: Context, mut acc: Int64) raises:
    acc -= ctx.get_int64(0)

fn sum_value(acc: Optional[Int64]) raises -> Optional[Int64]:
    return acc.copy()

fn main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE numbers (value INTEGER);
        INSERT INTO numbers VALUES (1);
        INSERT INTO numbers VALUES (2);
        INSERT INTO numbers VALUES (3);
        INSERT INTO numbers VALUES (4);
        INSERT INTO numbers VALUES (5);
    """)

    db.create_window_function[sum_init, sum_step, sum_finalize, sum_value, sum_inverse](
        "my_sum",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
    )

    fn get_row(row: Row) raises -> String:
        return t"{row.get[Int64](0)} | {row.get[Int64](1)}"

    # Sliding window: sum of current row and the one before it
    var stmt = db.prepare("""
        SELECT value,
               my_sum(value) OVER (ORDER BY value ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)
        FROM numbers
    """)
    for row in stmt.query[get_row]():
        print(row)
    # Output: 1|1, 2|3, 3|5, 4|7, 5|9
```

## Supported Types

### Reading from SQL (FromSQL)

| SQLite Type | Mojo Type |
|-------------|-----------|
| INTEGER | `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` |
| REAL | `Float16`, `Float32`, `Float64` |
| TEXT | `String` |
| INTEGER (0/1) | `Bool` |
| BLOB | `List[Byte]` |
| NULL | `None` |
| NULLABLE COLUMN | `Option[T]` where `T` refers to the sqlite to mojo type mappings above |

### Writing to SQL (ToSQL)

| Mojo Type | SQLite Type |
|-----------|-------------|
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | INTEGER |
| `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` | INTEGER |
| `Float16`, `Float32`, `Float64` | REAL |
| `String`, `StringLiteral`, `StringSlice` | TEXT |
| `Bool` | INTEGER (0/1) |
| `None` | NULL |
| `Option[T]` | NULLABLE COLUMN refers to the sqlite to mojo type mappings above |

### Parameter Binding (Params)

For parameter binding **only Tuples support heterogeneous types**. Lists and Dicts require all parameters to be of the same type, because we do not have Trait objects yet.

| Mojo Type | Binding Style | Heterogeneous Supported? |
|-----------|---------------|-------------------------|
| `Tuple` | Positional parameters (`?1`, `?2`, etc.) | Yes |
| `List` | Positional parameters (`?1`, `?2`, etc.) | No |
| `Dict` | Named parameters (`:name`, `@name`, `$name` ) | No |

## More Examples

For more detailed examples, see the `examples/` directory:

- `01_execute.mojo` - Basic execution and querying
- `02_execute_batch.mojo` - Batch execution of multiple statements
- `03_query_and_transform.mojo` - Row transformation and mapping
- `04_transactions.mojo` - Transactions and savepoints
- `05_scalar_functions.mojo` - Custom scalar SQL functions
- `06_aggregate_functions.mojo` - Custom aggregate SQL functions
- `07_window_functions.mojo` - Custom window SQL functions

## Attributions

This project was heavily inspired by:

- The [rusqlite](https://github.com/rusqlite/rusqlite) Rust crate.

And took notes from:

- The [Mojo DuckDB](https://github.com/sbrunk/duckdb.mojo) package.

## TODO

- Support features for different compilation options.
- Loading custom extensions.
- Creating custom collations.
- Made `Row.get` more flexible and ergonomic by allowing users to specify the column using any type that implements a `RowIndex` trait, which would include both `UInt/Int` for positional access and `String` for named access. But instead of checking for types that implement `RowIndex` and `FromSQL` at compilation time, I want to enforce these constraints via the type checker by using trait parameters. This would make the API safer and more user-friendly, as users would get immediate feedback if they try to use unsupported types for column access or retrieval. However, extensions are not fully baked yet and exposing them to users is a worse developer experience than just doing runtime checks and leaving the `get` function signature a bit more vague. I have left this as a TODO for now. Once the extension system is more ergonomic and less buggy, I can re-enable this feature and provide a much better API for column access in `Row.get`.
- Same goes for parameter binding. Any type that implements a `Params` trait can be used as parameters for queries, but currently this is not enforced by the type checker. For now, functions accept `AnyType` for parameters and we perform a comptime assert to check if the provided type conforms to the `Params` trait, which is a bit clunky. Ideally, we would want to enforce this constraint directly in the function signature, but due to limitations in the current trait system and extension system, this is not possible without causing issues for users who just want to use simple tuples or lists for parameters. Once the trait and extension systems are more robust, I can re-enable this feature and provide a much cleaner API for parameter binding.
- Add `collect` methods to the `MappedRows` and `TypedRows` iterators to allow users to easily collect query results into a list or other collection types. This would enhance the ergonomics of working with query results and make it easier for users to manipulate and work with their data after retrieval. This is dependent on conditional conformance, as we would need `T` to be `Copyable` to be added to a List. But I don't want to constrain `T` to be `Copyable` in the iterator itself.
- Assess origins of `ValueRef` in general, because I'm pretty sure I have a few incorrect origins being used.
