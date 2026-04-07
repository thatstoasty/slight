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
- **Busy Handlers**: Configure busy-wait behavior when the database is locked
- **Runtime Limits**: Query and modify SQLite runtime limits
- **Tracing**: Monitor SQL execution, profiling, and connection events
- **Extension Loading**: Load SQLite extensions with a Linear guard for safe enable/disable
- **Unlock Notification**: Handle shared-cache lock contention with unlock-notify callbacks

## Adding the `slight` package to your project

First, you'll need to enable the `pixi-build` preview by adding this to the `workspace` section of your `pixi.toml` file.

```bash
preview = ["pixi-build"]
```

Then, add `"https://prefix.dev/pixi-build-backends"` to the list of channels in your `pixi.toml` file.

### Building it from source

There's two ways to build `slight` from source: directly from the Git repository or by cloning the repository locally.

#### Building from source: Git

Run the following commands in your terminal:

```bash
pixi add -g "https://github.com/thatstoasty/slight.git" --tag v0.1.2 && pixi install
```

#### Building from source: Local

```bash
# Clone the repository to your local machine
git clone https://github.com/thatstoasty/slight.git

# Add the package to your project from the local path
pixi add -s ./path/to/slight && pixi install
```

## Configuring the SQLite Library Path

`slight` dynamically loads the SQLite3 shared library (`libsqlite3.dylib` on macOS, `libsqlite3.so` on Linux) at runtime. By default, it looks in `.pixi/envs/default/lib/` relative to the current working directory. If your SQLite library is installed elsewhere, you can point to it in two ways:

### Option 1: Compilation Argument

Pass the path as a `-D` flag when compiling with `mojo`:

```bash
# macOS
mojo -I . -D SQLITE_LIB_PATH=/usr/local/lib/libsqlite3.dylib my_app.mojo

# Linux
mojo -I . -D SQLITE_LIB_PATH=/usr/lib/x86_64-linux-gnu/libsqlite3.so my_app.mojo
```

This bakes the path into the compiled binary at compile time.

### Option 2: Environment Variable

Set the `SQLITE_LIB_PATH` environment variable before running your program:

```bash
# macOS
export SQLITE_LIB_PATH=/usr/local/lib/libsqlite3.dylib
mojo -I . my_app.mojo

# Linux
export SQLITE_LIB_PATH=/usr/lib/x86_64-linux-gnu/libsqlite3.so
mojo -I . my_app.mojo
```

The library is resolved in this order:

1. **Compilation argument** (`-D SQLITE_LIB_PATH=...`) — checked first
2. **Environment variable** (`SQLITE_LIB_PATH`) — checked if no compilation argument was provided
3. **Default path** (`.pixi/envs/default/lib/libsqlite3.dylib` or `.so`) — used as a fallback

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
    
    # Reset the statement to get users using Struct reflection.
    stmt.reset()
    for user in stmt.query[User]():
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
        _ = tx.conn[].execute("INSERT INTO accounts VALUES (?1, ?2)", ("Alice", 1000.0))
        _ = tx.conn[].execute("INSERT INTO accounts VALUES (?1, ?2)", ("Bob", 500.0))
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

### Busy Handlers

When another connection holds a lock on the database, SQLite returns `SQLITE_BUSY`. You can configure how `slight` waits for the lock to be released using either a timeout or a custom callback.

#### Busy Timeout

The simplest approach: tell SQLite to sleep and retry for up to `N` milliseconds before giving up.

```mojo
from slight.connection import Connection

fn main() raises:
    var db = Connection.open("my_database.db")

    # Wait up to 10 seconds for locks to clear
    db.busy_timeout(10000)

    # Pass 0 to disable the busy handler entirely
    db.busy_timeout(0)
```

#### Custom Busy Handler

For more control, register a callback that receives the retry count and returns `True` to retry or `False` to stop:

```mojo
from slight.connection import Connection

fn my_busy_handler(count: Int32) -> Bool:
    # Retry up to 5 times
    return count < 5

fn main() raises:
    var db = Connection.open("my_database.db")

    # Register a custom busy handler
    db.register_busy_handler[my_busy_handler]()

    # Clear the busy handler (SQLITE_BUSY is returned immediately on lock)
    db.clear_busy_handler()
```

> **Note:** There can only be one busy handler per connection. Setting a new handler or calling `busy_timeout()` clears the previous one. New connections default to a 5000ms busy timeout.

### Runtime Limits

SQLite enforces various runtime limits that you can query and modify per-connection:

```mojo
from slight.connection import Connection
from slight.limits import Limit

fn main() raises:
    var db = Connection.open_in_memory()

    # Query the current maximum SQL length
    var current = db.limit(Limit.SQL_LENGTH)
    print("Current SQL length limit:", current)

    # Lower the limit and get the previous value back
    var previous = db.set_limit(Limit.SQL_LENGTH, 10000)
    print("Previous SQL length limit:", previous)
```

Available limits:

| Limit | Description |
|-------|-------------|
| `Limit.LENGTH` | Maximum size of any string or BLOB or table row (bytes) |
| `Limit.SQL_LENGTH` | Maximum length of an SQL statement (bytes) |
| `Limit.COLUMN` | Maximum number of columns in a table, result set, index, or ORDER BY / GROUP BY |
| `Limit.EXPR_DEPTH` | Maximum depth of the parse tree on any expression |
| `Limit.COMPOUND_SELECT` | Maximum number of terms in a compound SELECT |
| `Limit.VDBE_OP` | Maximum number of VM instructions per SQL statement |
| `Limit.FUNCTION_ARG` | Maximum number of arguments on a function |
| `Limit.ATTACHED` | Maximum number of attached databases |
| `Limit.LIKE_PATTERN_LENGTH` | Maximum length of a LIKE or GLOB pattern |
| `Limit.VARIABLE_NUMBER` | Maximum parameter index in an SQL statement |
| `Limit.TRIGGER_DEPTH` | Maximum depth of recursion for triggers |
| `Limit.WORKER_THREADS` | Maximum number of worker threads per prepared statement |

### Tracing

Monitor SQL execution and connection events with the tracing API. Register a callback that receives `TraceEvent` objects for the event types you select:

```mojo
from slight.connection import Connection
from slight.trace import TraceEventCodes, TraceEvent

fn my_tracer(event: TraceEvent) -> NoneType:
    if event.is_stmt():
        print("SQL:", event.sql())
    elif event.is_profile():
        var duration_ms = event.duration_ns() / 1_000_000
        print("Completed in", duration_ms, "ms:", event.stmt_sql())
    elif event.is_row():
        print("Row produced")
    elif event.is_close():
        print("Connection closing")
    return NoneType()

fn main() raises:
    var db = Connection.open_in_memory()

    # Enable tracing for statement and profile events
    db.register_trace_function[my_tracer](
        TraceEventCodes.STMT | TraceEventCodes.PROFILE,
    )

    _ = db.execute("CREATE TABLE log (msg TEXT)")
    _ = db.execute("INSERT INTO log VALUES (?1)", ["hello"])

    # Disable tracing
    db.clear_trace_function()
```

Trace event types:

| Event | Description | Available Data |
|-------|-------------|----------------|
| `STMT` | Fired when a statement starts executing | `sql()`, `stmt_sql()`, `expanded_sql()` |
| `PROFILE` | Fired when a statement finishes | `duration_ns()`, `stmt_sql()`, `get_status()` |
| `ROW` | Fired each time a result row is produced | `stmt_sql()` |
| `CLOSE` | Fired when the connection is closing | `is_autocommit()`, `db_filename()` |

Use `TraceEventCodes.all()` to monitor all event types at once.

### Extension Loading

SQLite supports loading extensions from shared libraries. Extension loading is disabled by default for security. `slight` provides a Linear `ExtensionLoadGuard` that requires extension loading to be properly disabled after use:

```mojo
from slight.connection import Connection

fn main() raises:
    var db = Connection.open_in_memory()

    # Enable extension loading — returns a guard
    var guard = db.enable_extension_loading()

    # Load an extension (entry point is auto-detected by default)
    try:
        db.load_extension("/path/to/extension.dylib")

        # Or specify an explicit entry point
        db.load_extension("/path/to/extension.dylib", "sqlite3_ext_init")
    finally:
        # MUST disable extension loading when done (required by @explicit_destroy)
        guard^.disable_extension_loading()
```

The `ExtensionLoadGuard` uses `@explicit_destroy` to enforce that you call `disable_extension_loading()` — the compiler will emit an error if you forget.

### Unlock Notification

When using SQLite's [shared-cache mode](https://www.sqlite.org/sharedcache.html), multiple connections access the same in-memory or file-based database through a shared cache. If one connection holds a write lock, another connection attempting to read or write receives `SQLITE_LOCKED`. The unlock-notify mechanism lets a blocked connection register a callback that fires when the lock holder finishes its transaction, so the blocked operation can be retried.

#### Checking for Shared-Cache Lock Contention

Use `is_locked` to determine whether a result code indicates shared-cache lock contention (as opposed to other lock types):

```mojo
from slight.connection import Connection
from slight.flags import OpenFlag
from slight.result import SQLite3Result
from slight.unlock_notify import is_locked

fn main() raises:
    var url = "file:my_shared_db?mode=memory&cache=shared"
    var flags = OpenFlag.READ_WRITE | OpenFlag.URI | OpenFlag.CREATE
    var db = Connection.open(url, flags)

    # is_locked returns True for SQLITE_LOCKED_SHAREDCACHE (262)
    print(is_locked(db.db.db, SQLite3Result.LOCKED_SHAREDCACHE))  # True

    # Returns False for other result codes
    print(is_locked(db.db.db, SQLite3Result.OK))    # False
    print(is_locked(db.db.db, SQLite3Result.BUSY))   # False
```

#### Waiting for an Unlock Notification

Call `wait_for_unlock_notify` on a connection after it receives `SQLITE_LOCKED` in shared-cache mode. This registers an unlock-notify callback and blocks until the lock holder commits or rolls back:

```mojo
from slight.connection import Connection
from slight.flags import OpenFlag
from slight.result import SQLite3Result
from slight.transaction import TransactionBehavior

fn main() raises:
    var url = "file:unlock_demo?mode=memory&cache=shared"
    var flags = OpenFlag.READ_WRITE | OpenFlag.URI | OpenFlag.CREATE

    var db1 = Connection.open(url, flags)
    db1.execute_batch("CREATE TABLE items (value INTEGER)")

    var db2 = Connection.open(url, flags)

    # db1 acquires a write lock via an IMMEDIATE transaction
    var tx = db1.transaction(TransactionBehavior.IMMEDIATE)
    tx.conn[].execute_batch("INSERT INTO items VALUES (42)")

    # db2 can check if it's locked and wait for the notification
    var rc = db2.wait_for_unlock_notify()
    if rc == SQLite3Result.OK:
        print("Lock released, safe to retry")
    elif rc == SQLite3Result.LOCKED:
        print("Deadlock detected, should roll back")

    tx^.finish()
```

> **Note:** `wait_for_unlock_notify` uses a `SpinWaiter` internally to block until the callback fires. If `sqlite3_unlock_notify` detects that blocking would cause a deadlock, it returns `SQLITE_LOCKED` immediately — in that case, the caller should roll back the current transaction.

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
| NULLABLE COLUMN | `Optional[T]` where `T` refers to the sqlite to mojo type mappings above |

### Writing to SQL (ToSQL)

| Mojo Type | SQLite Type |
|-----------|-------------|
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | INTEGER |
| `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` | INTEGER |
| `Float16`, `Float32`, `Float64` | REAL |
| `String`, `StringLiteral`, `StringSlice` | TEXT |
| `Bool` | INTEGER (0/1) |
| `None` | NULL |
| `Optional[T]` | NULLABLE COLUMN refers to the sqlite to mojo type mappings above |

### Parameter Binding (Params)

For parameter binding, **only Tuples support heterogeneous types**. Lists and Dicts require all parameters to be of the same type, because we do not have Trait objects yet.

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
- Creating custom collations.
- Add subtype support for UDF results.
- Made `Row.get` more flexible and ergonomic by allowing users to specify the column using any type that implements a `RowIndex` trait, which would include both `UInt/Int` for positional access and `String` for named access. But instead of checking for types that implement `RowIndex` and `FromSQL` at compilation time, I want to enforce these constraints via the type checker by using trait parameters. This would make the API safer and more user-friendly, as users would get immediate feedback if they try to use unsupported types for column access or retrieval. However, extensions are not fully baked yet and exposing them to users is a worse developer experience than just doing runtime checks and leaving the `get` function signature a bit more vague. I have left this as a TODO for now. Once the extension system is more ergonomic and less buggy, I can re-enable this feature and provide a much better API for column access in `Row.get`.
- Same goes for parameter binding. Any type that implements a `Params` trait can be used as parameters for queries, but currently this is not enforced by the type checker. For now, functions accept `AnyType` for parameters and we perform a comptime assert to check if the provided type conforms to the `Params` trait, which is a bit clunky. Ideally, we would want to enforce this constraint directly in the function signature, but due to limitations in the current trait system and extension system, this is not possible without causing issues for users who just want to use simple tuples or lists for parameters. Once the trait and extension systems are more robust, I can re-enable this feature and provide a much cleaner API for parameter binding.
- Add `collect` methods to the `MappedRows` and `TypedRows` iterators to allow users to easily collect query results into a list or other collection types. This would enhance the ergonomics of working with query results and make it easier for users to manipulate and work with their data after retrieval. This is dependent on conditional conformance, as we would need `T` to be `Copyable` to be added to a List. But I don't want to constrain `T` to be `Copyable` in the iterator itself.
- Assess origins of `ValueRef` in general, because I'm pretty sure I have a few incorrect origins being used.
- I would like `RowTransformFn` to be properly parametrized on the connection and statement origins for `Row`, but I can't get partial parameter binding working for `Connection` functions. Maybe I'll revisit that one day.
