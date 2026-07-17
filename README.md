# slight

`slight` is a Mojo wrapper around the SQLite3 C library, providing a safe and ergonomic interface for interacting with SQLite databases in Mojo applications.

![Mojo Version](https://img.shields.io/badge/Mojo%F0%9F%94%A5-1.0.0b2-orange)
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
- **Serialization**: Copy a database to/from an in-memory byte buffer
- **Interrupt**: Cancel a long-running query from another thread
- **Online Backup**: Copy a live database into another connection, all at once or incrementally
- **Incremental BLOB I/O**: Read and write BLOB values in chunks without loading them fully into memory
- **WAL Checkpointing**: Manually checkpoint a database in write-ahead-log mode

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
pixi add -g "https://github.com/thatstoasty/slight.git" --tag v0.2.1 && pixi install
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

def main() raises:
    # Open an in-memory database
    var db = Connection.open_in_memory()
    
    # Or open a file-based database
    var db = Connection.open("my_database.db")
```

### Creating Tables and Inserting Data

```mojo
from slight.connection import Connection

def main() raises:
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

def main() raises:
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

def main() raises:
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

    def write_to[W: Writer, //](self, mut writer: W):
        writer.write("User(id=", self.id, ", name=", self.name, ")")

def main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
        INSERT INTO users VALUES (1, 'Alice');
        INSERT INTO users VALUES (2, 'Bob');
    """)
    
    def to_user(row: Row) raises -> User:
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
    
    # Get a single column from a single row, without a transform function
    var count = db.one_column[Int]("SELECT count(*) FROM users")
    print("Count:", count)
    
    # Get a single row that may not exist, without raising
    var maybe_user = db.maybe_one_row[to_user]("SELECT * FROM users WHERE id = ?1", [99])
    if maybe_user:
        print("Found:", maybe_user.value())
    else:
        print("No user with that id")
```

### Transactions

```mojo
from slight.connection import Connection
from slight.transaction import TransactionBehavior

def main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE accounts (name TEXT, balance REAL)")
    
    # Basic transaction with context manager
    # `Transaction`/`Savepoint` forward common Connection methods
    # (execute, execute_batch, one_row, maybe_one_row, one_column,
    # last_insert_row_id, changes) directly, so `tx` is optional here.
    with db.transaction() as tx:
        _ = tx.execute("INSERT INTO accounts VALUES (?1, ?2)", ("Alice", 1000.0))
        _ = tx.execute("INSERT INTO accounts VALUES (?1, ?2)", ("Bob", 500.0))
        tx.commit()  # Explicitly commit; otherwise rolls back on scope exit
    
    # Transaction with specific behavior
    with db.transaction(TransactionBehavior.IMMEDIATE) as tx:
        _ = tx.execute("UPDATE accounts SET balance = balance - 100 WHERE name = 'Alice'")
        _ = tx.execute("UPDATE accounts SET balance = balance + 100 WHERE name = 'Bob'")
        tx.commit()
```

### Savepoints

```mojo
from slight.connection import Connection

def main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE log (message TEXT)")
    
    with db.transaction() as tx:
        _ = tx.execute("INSERT INTO log VALUES (?1)", ["Step 1"])
        
        # Create a savepoint for a risky operation
        with tx.savepoint() as sp:
            _ = sp.execute("INSERT INTO log VALUES (?1)", ["Risky step"])
            # Rollback just this savepoint if something goes wrong
            sp.rollback()
            # Try again
            _ = sp.execute("INSERT INTO log VALUES (?1)", ["Safe step"])
            sp.commit()
        
        tx.commit()
```

### Scalar Functions

Register custom SQL functions that operate on a single row:

```mojo
from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row

def halve(ctx: Context) raises -> Float64:
    return ctx.get_double(0) / 2.0

def main() raises:
    var db = Connection.open_in_memory()

    # Register a scalar function named "halve" that takes 1 argument
    db.create_scalar_function[halve](
        "halve",
        n_arg=1,
    )

    def get_result(row: Row) raises -> Float64:
        return row.get[Float64](0)

    print(db.one_row[get_result]("SELECT halve(10.0)"))  # 5.0
```

### Aggregate Functions

Register custom SQL aggregate functions that process multiple rows into a single result:

```mojo
from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row

def sum_init(mut ctx: Context) raises -> Int64:
    return 0

def sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)

def sum_finalize(mut ctx: Context, acc: Int64) raises -> Int64:
    return acc

def main() raises:
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

    def get_result(row: Row) raises -> Int64:
        return row.get[Int64](0)

    print(db.one_row[get_result]("SELECT my_sum(value) FROM numbers"))  # 6
```

### Window Functions

Register custom SQL window functions that operate over a sliding frame of rows. Window functions extend aggregate functions with `inverse` (to remove a row leaving the frame) and `value` (to return the current result without finalizing) callbacks:

```mojo
from slight.connection import Connection
from slight.functions import Context, FunctionFlags
from slight.row import Row

def sum_init(mut ctx: Context) raises -> Int64:
    return 0

def sum_step(mut ctx: Context, mut acc: Int64) raises:
    acc += ctx.get_int64(0)

def sum_finalize(mut ctx: Context, acc: Int64) raises -> Optional[Int64]:
    return acc

def sum_inverse(mut ctx: Context, mut acc: Int64) raises:
    acc -= ctx.get_int64(0)

def sum_value(acc: Optional[Int64]) raises -> Optional[Int64]:
    return acc.copy()

def main() raises:
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

    def get_row(row: Row) raises -> String:
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

def main() raises:
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

def my_busy_handler(count: Int32) -> Bool:
    # Retry up to 5 times
    return count < 5

def main() raises:
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

def main() raises:
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
| ------- | ------------- |
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

def my_tracer(event: TraceEvent) -> NoneType:
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

def main() raises:
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
| ------- | ------------- | ---------------- |
| `STMT` | Fired when a statement starts executing | `sql()`, `stmt_sql()`, `expanded_sql()` |
| `PROFILE` | Fired when a statement finishes | `duration_ns()`, `stmt_sql()`, `get_status()` |
| `ROW` | Fired each time a result row is produced | `stmt_sql()` |
| `CLOSE` | Fired when the connection is closing | `is_autocommit()`, `db_filename()` |

Use `TraceEventCodes.all()` to monitor all event types at once.

### Commit, Rollback, and Update Hooks

Register callbacks that fire when a transaction commits or rolls back, or when a row is inserted, updated, or deleted:

```mojo
from slight.connection import Connection
from slight.hooks import UpdateOperation

def my_commit_hook() -> Bool:
    print("about to commit")
    # Return True to veto the commit and convert it into a rollback.
    return False

def my_rollback_hook() -> NoneType:
    print("transaction rolled back")
    return NoneType()

def my_update_hook(op: UpdateOperation, db_name: String, table_name: String, rowid: Int64) -> NoneType:
    print("row", rowid, "in", table_name, "changed:", op)
    return NoneType()

def main() raises:
    var db = Connection.open_in_memory()

    db.register_commit_hook[my_commit_hook]()
    db.register_rollback_hook[my_rollback_hook]()
    db.register_update_hook[my_update_hook]()

    db.execute_batch("CREATE TABLE t (id INTEGER)")
    _ = db.execute("INSERT INTO t (id) VALUES (?1)", (1,))

    # Clear any of the hooks individually
    db.clear_commit_hook()
    db.clear_rollback_hook()
    db.clear_update_hook()
```

> **Note:** Returning `True` from a commit hook converts the commit into a rollback (SQLite semantics: a non-zero return aborts the commit). There can only be one hook of each kind per connection; registering a new one replaces the previous one. `UpdateOperation` is one of `INSERT`, `UPDATE`, or `DELETE`.

### Custom Collations

Define custom string comparison functions for use with `COLLATE` in SQL:

```mojo
from slight.connection import Connection

def case_insensitive_compare(left: Span[Byte, ImmutUntrackedOrigin], right: Span[Byte, ImmutUntrackedOrigin]) -> Int:
    # A real implementation would lowercase/normalize before comparing.
    if left < right:
        return -1
    elif left > right:
        return 1
    return 0

def main() raises:
    var db = Connection.open_in_memory()

    db.create_collation[case_insensitive_compare]("NOCASE_CUSTOM")

    db.execute_batch("CREATE TABLE t (name TEXT)")
    _ = db.execute("INSERT INTO t (name) VALUES (?1)", ("Bob",))

    # Use the collation in a query
    var stmt = db.prepare("SELECT name FROM t ORDER BY name COLLATE NOCASE_CUSTOM")

    # Remove the collation when no longer needed
    db.remove_collation("NOCASE_CUSTOM")
```

> **Note:** The comparator receives the raw bytes of the two values and returns an ordering integer analogous to C's `strcmp`: negative if `left < right`, zero if equal, positive if `left > right`. `remove_collation` raises if referenced afterward from SQL.

### Progress Handler

Register a callback that fires periodically during long-running queries, useful for progress reporting or aborting a runaway query:

```mojo
from slight.connection import Connection

def my_progress_handler() -> Bool:
    print("still working...")
    # Return True to interrupt (abort) the running query.
    return False

def main() raises:
    var db = Connection.open_in_memory()

    # Invoke the handler roughly every 1000 VM instructions
    db.register_progress_handler[my_progress_handler](1000)

    _ = db.execute("SELECT 1")

    db.clear_progress_handler()
```

> **Note:** Returning `True` interrupts the running query, causing it to fail with an error. There can only be one progress handler per connection; registering a new one replaces the previous one.

### Authorizer

Register a callback invoked during statement preparation for every action that requires authorization, allowing you to allow, deny, or ignore individual operations:

```mojo
from slight.authorizer import AuthAction, AuthResult
from slight.connection import Connection

def deny_drops(
    action: AuthAction,
    arg1: Optional[String],
    arg2: Optional[String],
    db_name: Optional[String],
    trigger_or_view: Optional[String],
) -> AuthResult:
    if action == AuthAction.DROP_TABLE:
        return AuthResult.DENY
    return AuthResult.OK

def main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t (x INTEGER)")

    db.register_authorizer[deny_drops]()

    # This raises, because DROP TABLE is denied.
    # db.execute_batch("DROP TABLE t")

    db.clear_authorizer()
```

> **Note:** `AuthResult.DENY` aborts the SQL statement with an error; `AuthResult.IGNORE` disallows just the specific action (e.g. a denied column read is treated as NULL) while letting the rest of the statement proceed; `AuthResult.OK` allows the action. `AuthAction` covers common action codes (`CREATE_TABLE`, `DROP_TABLE`, `READ`, `INSERT`, `UPDATE`, `DELETE`, `SELECT`, `PRAGMA`, `TRANSACTION`, `ATTACH`, `DETACH`, `FUNCTION`); see [SQLite's authorizer action codes](https://www.sqlite.org/c3ref/c_alter_table.html) for the full list. Registering or clearing an authorizer invalidates previously prepared statements.

### Extension Loading

SQLite supports loading extensions from shared libraries. Extension loading is disabled by default for security. `slight` provides a Linear `ExtensionLoadGuard` that requires extension loading to be properly disabled after use:

```mojo
from slight.connection import Connection

def main() raises:
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

def main() raises:
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

def main() raises:
    var url = "file:unlock_demo?mode=memory&cache=shared"
    var flags = OpenFlag.READ_WRITE | OpenFlag.URI | OpenFlag.CREATE

    var db1 = Connection.open(url, flags)
    db1.execute_batch("CREATE TABLE items (value INTEGER)")

    var db2 = Connection.open(url, flags)

    # db1 acquires a write lock via an IMMEDIATE transaction
    var tx = db1.transaction(TransactionBehavior.IMMEDIATE)
    tx.execute_batch("INSERT INTO items VALUES (42)")

    # db2 can check if it's locked and wait for the notification
    var rc = db2.wait_for_unlock_notify()
    if rc == SQLite3Result.OK:
        print("Lock released, safe to retry")
    elif rc == SQLite3Result.LOCKED:
        print("Deadlock detected, should roll back")

    tx^.finish()
```

> **Note:** `wait_for_unlock_notify` uses a `SpinWaiter` internally to block until the callback fires. If `sqlite3_unlock_notify` detects that blocking would cause a deadlock, it returns `SQLITE_LOCKED` immediately — in that case, the caller should roll back the current transaction.

### Serialization

SQLite can serialize a database into an in-memory byte buffer in the standard SQLite file format, and deserialize that buffer back into a connection. This is useful for snapshotting, copying, or transmitting an in-memory database (e.g. one created with `Connection.open_in_memory()`), since otherwise there is no file on disk to copy.

```mojo
from slight.connection import Connection

def main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
        INSERT INTO users VALUES (1, 'Alice');
        INSERT INTO users VALUES (2, 'Bob');
    """)

    # Serialize copies the database into an in-memory buffer.
    var data = db.serialize()

    # Deserialize loads that buffer into another connection, replacing its
    # current contents.
    var copy = Connection.open_in_memory()
    copy.deserialize(data^)

    var stmt = copy.prepare("SELECT id, name FROM users ORDER BY id")
    for row in stmt.query():
        print(row.get[Int](0), ":", row.get[String](1))
```

Pass `read_only=True` to `deserialize` to load the buffer as a read-only database, rejecting any writes:

```mojo
var snapshot = Connection.open_in_memory()
snapshot.deserialize(data^, read_only=True)

try:
    _ = snapshot.execute("DELETE FROM users")
except e:
    print("Write rejected:", e)  # attempt to write a readonly database
```

> **Note:** `deserialize` transfers ownership of the buffer to SQLite, which frees it when the connection closes (or when that schema is deserialized into again). By default the deserialized database is writable and SQLite is allowed to grow the underlying buffer as it expands; with `read_only=True` it cannot be modified or resized.

### Interrupt

Call `interrupt` to cancel the longest-running query currently executing on a connection, causing it to abort at its earliest opportunity. This is typically called from a different thread than the one running the query (e.g. in response to a user cancel action):

```mojo
from slight.connection import Connection

def main() raises:
    var db = Connection.open_in_memory()

    # From another thread:
    db.interrupt()

    # is_interrupted() reports whether an interrupt is currently pending.
    print(db.is_interrupted())
```

> **Note:** It is not safe to call `interrupt` on a connection that is closed or might close before the call returns.

### Backup

SQLite's [online backup API](https://www.sqlite.org/backup.html) copies the contents of one database connection into another while the source remains usable. This is the primary way to back up or duplicate an in-memory database, since it has no file on disk to copy directly.

For the common case of copying an entire database in one call, use `backup_to`:

```mojo
from slight.connection import Connection

def main() raises:
    var source = Connection.open_in_memory()
    source.execute_batch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
        INSERT INTO users VALUES (1, 'Alice');
        INSERT INTO users VALUES (2, 'Bob');
    """)

    var dest = Connection.open_in_memory()
    source.backup_to(dest)

    var stmt = dest.prepare("SELECT id, name FROM users ORDER BY id")
    for row in stmt.query():
        print(row.get[Int](0), ":", row.get[String](1))
```

For fine-grained control (e.g. copying a fixed number of pages at a time so the source connection remains responsive), use `backup` to get a `Backup` handle and step it manually:

```mojo
from slight.connection import Connection

def main() raises:
    var source = Connection.open_in_memory()
    source.execute_batch("CREATE TABLE t (value INTEGER)")

    var dest = Connection.open_in_memory()
    var backup = source.backup(Pointer(to=dest))

    # Copy 5 pages at a time until the backup is complete.
    while backup.step(5):
        print("remaining pages:", backup.remaining(), "/", backup.pagecount())

    backup^.finish()
```

> **Note:** A `Backup` finishes itself automatically when it goes out of scope, absorbing any error that occurs while doing so. Call `.finish()` explicitly if you want to observe that error.

### Incremental BLOB I/O

Use `blob_open` to get a handle for reading or writing a BLOB value in chunks, rather than loading the entire value into memory. This is useful for large BLOBs.

```mojo
from slight.connection import Connection

def main() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE images (id INTEGER PRIMARY KEY, data BLOB)")
    _ = db.execute("INSERT INTO images (id, data) VALUES (1, ?1)", [List[Byte](1, 2, 3, 4, 5, 6, 7, 8)])

    var blob = db.blob_open("images", "data", row_id=1)
    print("size:", blob.bytes())

    # Read the first 4 bytes.
    var chunk = blob.read(4, offset=0)

    blob^.close()
```

Open with `read_only=False` to write into the BLOB in place:

```mojo
var blob = db.blob_open("images", "data", row_id=1, read_only=False)
var patch: List[Byte] = [9, 9, 9]
blob.write(Span(patch), offset=2)
blob^.close()
```

> **Note:** A `Blob` closes itself automatically when it goes out of scope, absorbing any error that occurs while doing so (mirroring `Statement`'s cleanup model). Call `.close()` explicitly if you want to observe that error. Writing requires the BLOB to have been opened with `read_only=False`.

### WAL Checkpointing

When a database is in [write-ahead-log (WAL) mode](https://www.sqlite.org/wal.html), changes accumulate in a separate WAL file until they are checkpointed back into the main database file. Checkpoints normally happen automatically, but `wal_checkpoint` and `wal_checkpoint_v2` allow triggering one manually:

```mojo
from slight.connection import Connection

def main() raises:
    var db = Connection.open("my.db")
    db.execute_batch("PRAGMA journal_mode=WAL")
    db.execute_batch("CREATE TABLE t (value INTEGER)")
    _ = db.execute("INSERT INTO t (value) VALUES (?1)", (1,))

    # Passive checkpoint using SQLite's default mode.
    db.wal_checkpoint()
```

`wal_checkpoint_v2` additionally accepts a `CheckpointMode` and reports how many frames were in the WAL log and how many were checkpointed:

```mojo
from slight.checkpoint import CheckpointMode

var log_frames, checkpointed_frames = db.wal_checkpoint_v2(CheckpointMode.FULL)
print(checkpointed_frames, "/", log_frames, "frames checkpointed")
```

`CheckpointMode` has four variants: `PASSIVE` (the default, non-blocking), `FULL`, `RESTART`, and `TRUNCATE` (each progressively more aggressive about blocking writers/readers and truncating the WAL file — see the [SQLite documentation](https://www.sqlite.org/c3ref/wal_checkpoint_v2.html) for details).

> **Note:** WAL mode requires a real file on disk; it does not apply to in-memory databases (`Connection.open_in_memory()`).

## Supported Types

### Reading from SQL (FromSQL)

| SQLite Type | Mojo Type |
| ------------- | ----------- |
| INTEGER | `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` |
| REAL | `Float16`, `Float32`, `Float64` |
| TEXT | `String` |
| INTEGER (0/1) | `Bool` |
| BLOB | `List[Byte]` |
| NULL | `None` |
| NULLABLE COLUMN | `Optional[T]` where `T` refers to the sqlite to mojo type mappings above |

### Writing to SQL (ToSQL)

| Mojo Type | SQLite Type |
| ----------- | ------------- |
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
| ----------- | --------------- | ------------------------- |
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
- `08_serialize.mojo` - Serializing and deserializing databases

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
- Assess origins of `ValueRef` in general, because I'm pretty sure I have a few incorrect origins being used.
- I would like `RowTransformFn` to be properly parametrized on the connection and statement origins for `Row`, but I can't get partial parameter binding working for `Connection` functions. Maybe I'll revisit that one day.
- Improve CSV Reader logic.
- Add a `prepare_cached` on `Connection` that caches and reuses compiled `Statement`s by SQL text (like `rusqlite`'s `CachedStatement`). Attempted this and hit a wall: `RawStatement` is `@explicit_destroy` (intentionally, since it wraps a `sqlite3_stmt*`), which rules out `Dict[String, RawStatement]` as a cache (the compiler crashes trying to bind `RawStatement` to `Dict`'s `V: Copyable & ImplicitlyDestructible` value-type constraint) and also rules out `List[RawStatement]` (a `List` of non-`ImplicitlyDeletable` elements must be explicitly destroyed via `destroy_with()`, which doesn't actually exist on `List` in the current stdlib). Revisit once there's a container type that supports non-implicitly-destructible values, or once `RawStatement` gains some other cache-friendly ownership story.
- `Transaction.prepare`/`Savepoint.prepare` are intentionally not forwarded to the underlying `Connection.prepare` (unlike `execute`, `execute_batch`, `one_row`, `maybe_one_row`, `one_column`, `last_insert_row_id`, `changes`, which are). `Connection.prepare`'s return type is `Statement[origin_of(self)]`, and when called through `self.conn[]` inside a thin wrapper, the compiler treats the resulting origin as a distinct derived origin (`origin_of(conn_origin)`) rather than `Self.conn_origin` itself, so no return-type annotation I tried satisfied the borrow checker. Use `tx.prepare(...)` / `sp.prepare(...)` directly for now.
- I need to look over what functions should borrow self mutably for Connection and Statement. It doesn't feel correct to take a Connection mutably then run a query that modifies the DB connection it wraps?
