from std.ffi import c_char, c_int, c_uchar, c_uint
from std.memory import OpaquePointer
from std.utils import StaticTuple


comptime ImmutExternalPointer = ImmutUnsafePointer[origin=ImmutExternalOrigin, address_space=AddressSpace.GENERIC, ...]
"""Immutable External Pointer.

Parameters:
    type: The type of the data the pointer points to.
"""
comptime ImmutExternalOpaquePointer = ImmutExternalPointer[NoneType]
"""Immutable External Opaque Pointer.

Parameters:
    type: The type of the data the pointer points to.
"""
comptime MutExternalPointer = MutUnsafePointer[origin=MutExternalOrigin, address_space=AddressSpace.GENERIC, ...]
"""Mutable External Pointer.

Parameters:
    type: The type of the data the pointer points to.
"""
comptime MutExternalOpaquePointer = MutExternalPointer[NoneType]
"""Mutable External Opaque Pointer.

Parameters:
    type: The type of the data the pointer points to.
"""


@fieldwise_init
struct DataType(Equatable, Movable, TrivialRegisterPassable):
    """Fundamental Datatypes.

    Every value in SQLite has one of five fundamental datatypes:
    * 64-bit signed integer
    * 64-bit IEEE floating point number
    * string
    * BLOB
    * NULL

    These constants are codes for each of those types.
    """

    var value: Int32
    """Internal enum value."""
    comptime INTEGER = Self(1)
    """`SQLITE_INTEGER`: 64-bit signed integer."""
    comptime FLOAT = Self(2)
    """`SQLITE_FLOAT`: 64-bit IEEE floating point number."""
    comptime TEXT = Self(3)
    """`SQLITE_TEXT`: String."""
    comptime BLOB = Self(4)
    """`SQLITE_BLOB`: BLOB."""
    comptime NULL = Self(5)
    """`SQLITE_NULL`: NULL."""

    def __eq__(self, other: Self) -> Bool:
        """Checks if this value is equal to `other`.

        Args:
            other: The other `DataType` to compare against.

        Returns:
            True if both `DataType` instances have the same value, False otherwise.
        """
        return self.value == other.value

    def __eq__(self, other: Int32) -> Bool:
        """Checks if this value is equal to a raw integer value.

        Args:
            other: The raw integer value to compare against.

        Returns:
            True if the `DataType`'s value is equal to the raw integer value, False otherwise.
        """
        return self.value == other


@fieldwise_init
struct TextEncoding(Movable, TrivialRegisterPassable):
    """Text Encodings.

    These constant define integer codes that represent the various
    text encodings supported by SQLite.
    """

    var value: UInt8
    """Internal enum value."""
    comptime UTF8 = Self(1)
    """`SQLITE_UTF8`: UTF-8 encoding."""


struct sqlite3_connection(Movable):
    """Database Connection Handle.

    Each open SQLite database is represented by a pointer to an instance of
    the opaque structure named "sqlite3".  It is useful to think of an sqlite3
    pointer as an object.  The [sqlite3_open()], [sqlite3_open16()], and
    [sqlite3_open_v2()] interfaces are its constructors, and [sqlite3_close()]
    and [sqlite3_close_v2()] are its destructors.  There are many other
    interfaces (such as
    [sqlite3_prepare_v2()], [sqlite3_create_function()], and
    [sqlite3_busy_timeout()] to name but three) that are methods on an
    sqlite3 object."""

    pass


struct sqlite3_file(Movable):
    """OS Interface Open File Handle.

    An [sqlite3_file] object represents an open file in the
    [sqlite3_vfs | OS interface layer].  Individual OS interface
    implementations will
    want to subclass this object by appending additional fields
    for their own use.  The pMethods entry is a pointer to an
    [sqlite3_io_methods] object that defines methods for performing
    I/O operations on the open file.
    """

    pass


# ===----------------------------------------------------------------------=== #
# Callback Type Aliases
# ===----------------------------------------------------------------------=== #

comptime ScalarFnCallback = def(
    MutExternalPointer[sqlite3_context],
    c_int,
    MutExternalPointer[MutExternalPointer[sqlite3_value]],
) raises thin -> NoneType
"""Callback type for scalar SQL functions.

The callback receives:
- The SQL function context pointer.
- The number of arguments (argc).
- A pointer to the array of argument values (argv).

Use `Context` to conveniently access arguments and set results.
"""

comptime AggStepCallback = def(
    MutExternalPointer[sqlite3_context],
    c_int,
    MutExternalPointer[MutExternalPointer[sqlite3_value]],
) thin -> NoneType
"""Callback type for the step function of an aggregate SQL function.

Called once for each row in an aggregate group.
"""

comptime AggFinalCallback = def(MutExternalPointer[sqlite3_context]) thin -> NoneType
"""Callback type for the finalize function of an aggregate SQL function.

Called once after all rows have been processed to compute the final result.
"""

comptime WindowValueCallback = def(MutExternalPointer[sqlite3_context]) thin -> NoneType
"""Callback type for the value function of a window aggregate function.

Returns the current value of the aggregate without finalizing.
"""

comptime WindowInverseCallback = def(
    MutExternalPointer[sqlite3_context],
    c_int,
    MutExternalPointer[MutExternalPointer[sqlite3_value]],
) thin -> NoneType
"""Callback type for the inverse function of a window aggregate function.

Called when a row leaves the window frame.
"""

comptime ResultDestructorFn = def(MutExternalPointer[NoneType]) thin -> NoneType
"""Constants Defining Special Destructor Behavior.

These are special values for the destructor that is passed in as the
final argument to routines like `sqlite3_result_blob()`.

If the destructor argument is `SQLITE_STATIC`, it means that the content pointer is constant
and will never change. It does not need to be destroyed. The
`SQLITE_TRANSIENT` value means that the content will likely change in
the near future and that SQLite should make its own private copy of
the content before returning."""

comptime ExtensionEntrypointCallbackFn = def(
    MutExternalPointer[sqlite3_connection],
    MutExternalPointer[MutExternalPointer[c_char]],
    ImmutExternalPointer[sqlite3_api_routines],
) thin -> c_int
"""Callback type for registering SQLite extensions."""
comptime CancelExtensionCallbackFn = def() thin -> c_int
"""Callback type for canceling the loading of an SQLite extension."""

comptime TraceCallbackFn = def(MutExternalPointer[NoneType], ImmutExternalPointer[c_char]) thin -> NoneType
"""Callback type for SQLite trace callbacks."""
comptime TraceV2CallbackFn = def(c_uint, MutExternalPointer[NoneType], MutExternalPointer[NoneType], MutExternalPointer[NoneType]) thin -> c_int
"""Callback type for SQLite trace v2 callbacks."""
comptime ProfileCallbackFn = def(MutExternalPointer[NoneType], ImmutExternalPointer[c_char], UInt64) thin -> NoneType
"""Callback type for SQLite profile callbacks."""
comptime QueryProgressCallbackFn = def(MutExternalPointer[NoneType]) thin -> c_int
"""Callback type for SQLite query progress callbacks."""
comptime CollationCompareCallbackFn = def(
    MutExternalPointer[NoneType],
    c_int,
    ImmutExternalPointer[NoneType],
    c_int,
    ImmutExternalPointer[NoneType],
) thin -> c_int
"""Callback type for SQLite collation compare callbacks."""
comptime CollationNeededCallbackFn = def(
    MutExternalPointer[NoneType],
    MutExternalPointer[sqlite3_connection],
    c_int,
    ImmutExternalPointer[c_char],
) thin -> NoneType
"""Callback type for SQLite unknown collation needed callbacks."""
comptime UpdateHookCallbackFn = def(
    MutExternalPointer[NoneType],
    c_int,
    MutExternalPointer[c_char],
    MutExternalPointer[c_char],
    Int64,
) thin
"""Callback type for SQLite update hook callbacks."""
comptime CommitHookCallbackFn = def(MutExternalPointer[NoneType]) thin -> c_int
"""Callback type for SQLite commit hook callbacks."""
comptime RollbackHookCallbackFn = def(MutExternalPointer[NoneType]) thin -> NoneType
"""Callback type for SQLite rollback hook callbacks."""
comptime UnlockNotifyCallbackFn = def(MutExternalPointer[MutExternalPointer[NoneType]], c_int) thin -> NoneType
"""Callback type for SQLite unlock notify callbacks."""
comptime WALHookCallbackFn = def(
    MutExternalPointer[NoneType],
    MutExternalPointer[sqlite3_connection],
    MutExternalPointer[c_char],
    c_int,
) thin -> c_int
"""Callback type for SQLite WAL hook callbacks."""
comptime MemoryAlarmCallbackFn = def(MutExternalPointer[NoneType], Int64, c_int) thin -> NoneType
"""Callback type for SQLite memory alarm callbacks."""
comptime BusyHandlerFn = def (c_int) thin -> Bool
"""A busy handler callback function.

The argument is the number of times the busy handler has been invoked
previously for the same locking event. Return `True` to retry,
`False` to stop retrying (which causes `SQLITE_BUSY` to be returned).
"""

@fieldwise_init
struct DestructorHint(Movable, TrivialRegisterPassable):
    """If the destructor argument is `SQLITE_STATIC`, it means that the content pointer is constant
    and will never change. It does not need to be destroyed. The
    `SQLITE_TRANSIENT` value means that the content will likely change in
    the near future and that SQLite should make its own private copy of
    the content before returning.

    To use these as destructors for libsqlite3, first create a pointer to the value.
    Then bitcast it to `ResultDestructorFn`. Then when calling `sqlite3_bind_text` or
    `sqlite3_result_blob`, pass the dereferenced pointer as the destructor argument."""

    var value: Int
    """Internal enum value."""
    comptime STATIC = Self(0)
    """`SQLITE_STATIC`: The content pointer is constant and will never change."""
    comptime TRANSIENT = Self(-1)
    """`SQLITE_TRANSIENT`: The content will likely change in the near future and SQLite should make its own private copy of the content before returning."""

    # Why do I have to do this cursed conversion?
    @staticmethod
    def static_destructor() -> ResultDestructorFn:
        """Returns a function pointer representing the `SQLITE_STATIC` destructor.

        Returns:
            A function pointer representing the `SQLITE_STATIC` destructor.
        """
        return UnsafePointer(to=Self.STATIC.value).bitcast[ResultDestructorFn]()[]

    @staticmethod
    def transient_destructor() -> ResultDestructorFn:
        """Returns a function pointer representing the `SQLITE_TRANSIENT` destructor.

        Returns:
            A function pointer representing the `SQLITE_TRANSIENT` destructor.
        """
        return UnsafePointer(to=Self.TRANSIENT.value).bitcast[ResultDestructorFn]()[]


comptime ExecCallbackFn = def(
    data: MutExternalPointer[NoneType],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[c_char]],
    azColName: MutExternalPointer[MutExternalPointer[c_char]],
) thin -> c_int
"""Callback Function Type for `sqlite3_exec()`."""

comptime AuthCallbackFn = def(
    MutExternalPointer[NoneType],
    c_int,
    ImmutExternalPointer[c_char],
    ImmutExternalPointer[c_char],
    ImmutExternalPointer[c_char],
    ImmutExternalPointer[c_char],
) thin -> c_int
"""Callback Function Type for `sqlite3_set_authorizer()`."""

comptime BusyHandlerCallbackFn = def (MutExternalPointer[NoneType], c_int) thin -> c_int
"""A busy handler callback function.

The argument is the number of times the busy handler has been invoked
previously for the same locking event. Return `True` to retry,
`False` to stop retrying (which causes `SQLITE_BUSY` to be returned).
"""


struct sqlite3_api_routines(Movable):
    """SQLite API Routines.

    This struct contains function pointers for all the SQLite C API routines.
    It is used when registering extensions with `sqlite3_auto_extension()`.
    """

    pass



struct sqlite3_backup(Movable):
    """Online Backup Object.

    The sqlite3_backup object records state information about an ongoing
    online backup operation.

    The sqlite3_backup object is created by a call to `sqlite3_backup_init()` and is destroyed by a call to
    `sqlite3_backup_finish()`."""

    pass


struct sqlite3_snapshot(Movable):
    """Database Snapshot.

    An instance of the snapshot object records the state of a [WAL mode]
    database for some specific point in history.

    In [WAL mode], multiple [database connections] that are open on the
    same database file can each be reading a different historical version
    of the database file.  When a [database connection] begins a read
    transaction, that connection sees an unchanging copy of the database
    as it existed for the point in time when the transaction first started.
    Subsequent changes to the database from other connections are not seen
    by the reader until a new read transaction is started.

    The sqlite3_snapshot object records state information about an historical
    version of the database file so that it is possible to later open a new read
    transaction that sees that historical version of the database rather than
    the most recent version.
    """

    var hidden: StaticTuple[UInt8, 48]
    """Opaque data used internally by SQLite to represent the snapshot. The actual contents are not exposed."""


struct sqlite3_stmt(Movable):
    """Prepared Statement Object.

    An instance of this object represents a single SQL statement that
    has been compiled into binary form and is ready to be evaluated.
    Think of each SQL statement as a separate computer program.  The
    original SQL text is source code.  A prepared statement object
    is the compiled object code.  All SQL must be converted into a
    prepared statement before it can be run.
    The life-cycle of a prepared statement object usually goes like this:

    1. Create the prepared statement object using `sqlite3_prepare_v2()`.
    2. Bind values to `parameters` using the `sqlite3_bind_()` interfaces.
    3. Run the SQL by calling `sqlite3_step()` one or more times.
    4. Reset the prepared statement using `sqlite3_reset()` then go back
        to step 2.  Do this zero or more times.
    5. Destroy the object using `sqlite3_finalize()`.
    """

    pass


struct sqlite3_value(Movable):
    """Dynamically Typed Value Object.

    SQLite uses the `sqlite3_value` object to represent all values
    that can be stored in a database table. SQLite uses dynamic typing
    for the values it stores.

    Values stored in `sqlite3_value` objects
    can be integers, floating point values, strings, BLOBs, or NULL.
    An sqlite3_value object may be either "protected" or "unprotected".
    Some interfaces require a protected `sqlite3_value`. Other interfaces
    will accept either a protected or an unprotected `sqlite3_value`.
    Every interface that accepts `sqlite3_value` arguments specifies
    whether or not it requires a protected `sqlite3_value`.  The
    `sqlite3_value_dup()` interface can be used to construct a new
    protected `sqlite3_value` from an unprotected `sqlite3_value`.
    The terms "protected" and "unprotected" refer to whether or not
    a mutex is held.  An internal mutex is held for a protected
    `sqlite3_value` object but no mutex is held for an unprotected
    `sqlite3_value` object. If SQLite is compiled to be single-threaded
    (with `SQLITE_THREADSAFE=0` and with `sqlite3_threadsafe()` returning 0)
    or if SQLite is run in one of reduced mutex modes
    `SQLITE_CONFIG_SINGLETHREAD` or `SQLITE_CONFIG_MULTITHREAD`,
    then there is no distinction between protected and unprotected
    `sqlite3_value` objects and they can be used interchangeably.  However,
    for maximum code portability it is recommended that applications
    still make the distinction between protected and unprotected
    `sqlite3_value` objects even when not strictly required.

    The `sqlite3_value` objects that are passed as parameters into the
    implementation of `application-defined SQL functions` are protected.

    The `sqlite3_value` objects returned by `sqlite3_vtab_rhs_value()`
    are protected.

    The `sqlite3_value` object returned by
    `sqlite3_column_value()` is unprotected.
    Unprotected `sqlite3_value` objects may only be used as arguments
    to `sqlite3_result_value()`, `sqlite3_bind_value()`, and
    `sqlite3_value_dup()`.

    The `sqlite3_value_blob | sqlite3_value_type()` family of
    interfaces require protected `sqlite3_value` objects."""

    pass


struct sqlite3_context(Movable):
    """SQL Function Context Object.

    The context in which an SQL function executes is stored in an
    sqlite3_context object.  ^A pointer to an sqlite3_context object
    is always first parameter to `application-defined SQL functions`.
    The application-defined SQL function implementation will pass this
    pointer through into calls to `sqlite3_result_int | sqlite3_result()`,
    `sqlite3_aggregate_context()`, `sqlite3_user_data()`,
    `sqlite3_context_db_handle()`, `sqlite3_get_auxdata()`,
    and/or `sqlite3_set_auxdata()`."""

    pass


comptime VtabCreateCallbackFn = def (
    MutExternalPointer[sqlite3_connection],
    MutExternalPointer[NoneType],
    c_int,
    MutExternalPointer[MutExternalPointer[c_char]],
    MutExternalPointer[MutExternalPointer[sqlite3_vtab]],
    MutExternalPointer[MutExternalPointer[c_char]],
) thin -> c_int
"""Called to create a new virtual table. It should create a new instance of the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabConnectCallbackFn = def (
    MutExternalPointer[sqlite3_connection],
    MutExternalPointer[NoneType],
    c_int,
    MutExternalPointer[MutExternalPointer[c_char]],
    MutExternalPointer[MutExternalPointer[sqlite3_vtab]],
    MutExternalPointer[MutExternalPointer[c_char]],
) thin -> c_int
"""Called to connect to an existing virtual table. It should initialize a new instance of the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabBestIndexCallbackFn = def (MutExternalPointer[sqlite3_vtab], MutExternalPointer[sqlite3_index_info]) thin -> c_int
"""Called to determine the best way to access a virtual table. It should analyze the query constraints and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabDisconnectCallbackFn = def (MutExternalPointer[sqlite3_vtab]) thin -> c_int
"""Called to disconnect from a virtual table. It should clean up any resources associated with the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabDestroyCallbackFn = def (MutExternalPointer[sqlite3_vtab]) thin -> c_int
"""Called to destroy a virtual table. It should clean up any resources associated with the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabOpenCallbackFn = def (MutExternalPointer[sqlite3_vtab], MutExternalPointer[MutExternalPointer[sqlite3_vtab_cursor]]) thin -> c_int
"""Called to open a new cursor on a virtual table. It should create a new instance of the cursor and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabCloseCallbackFn = def (MutExternalPointer[sqlite3_vtab_cursor]) thin -> c_int
"""Called to close a cursor on a virtual table. It should clean up any resources associated with the cursor and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabFilterCallbackFn = def (MutExternalPointer[sqlite3_vtab], MutExternalPointer[MutExternalPointer[sqlite3_vtab_cursor]]) thin -> c_int
"""Called to begin a search of a virtual table. It should initialize the cursor to point to the first row of the result set and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabNextCallbackFn = def (MutExternalPointer[sqlite3_vtab_cursor]) thin -> c_int
"""Called to advance a cursor to the next row of the result set. It should move the cursor to the next row and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabEofCallbackFn = def (MutExternalPointer[sqlite3_vtab_cursor]) thin -> c_int
"""Called to determine if a cursor has reached the end of the result set. It should return 1 if the cursor is at the end of the result set and 0 otherwise."""
comptime VtabColumnCallbackFn = def (MutExternalPointer[sqlite3_vtab_cursor], MutExternalPointer[sqlite3_context], c_int) thin -> c_int
"""Called to retrieve a column value from the current row of the result set. It should use the sqlite3_result_*() interfaces to return the value of the specified column and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabRowidCallbackFn = def (MutExternalPointer[sqlite3_vtab_cursor], MutExternalPointer[Int64]) thin -> c_int
"""Called to retrieve the rowid of the current row of the result set. It should store the rowid in the provided pointer and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabUpdateCallbackFn = def (
    MutExternalPointer[sqlite3_vtab],
    c_int,
    MutExternalPointer[MutExternalPointer[sqlite3_value]],
    MutExternalPointer[Int64],
) thin -> c_int
"""Called to update the virtual table. It should perform the specified update operation (insert, update, or delete) and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabBeginCallbackFn = def (MutExternalPointer[sqlite3_vtab]) thin -> c_int
"""Called to begin a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabSyncCallbackFn = def (MutExternalPointer[sqlite3_vtab]) thin -> c_int
"""Called to sync the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabCommitCallbackFn = def (MutExternalPointer[sqlite3_vtab]) thin -> c_int
"""Called to commit a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabRollbackCallbackFn = def (MutExternalPointer[sqlite3_vtab]) thin -> c_int
"""Called to roll back a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabFindFunctionCallbackFn = def (
    MutExternalPointer[sqlite3_vtab],
    c_int,
    ImmutExternalPointer[c_char],
    def (
        MutExternalPointer[sqlite3_context], c_int, MutExternalPointer[MutExternalPointer[sqlite3_value]]
    ) thin -> MutExternalPointer[MutExternalPointer[NoneType]],
    MutExternalPointer[MutExternalPointer[NoneType]],
) thin -> c_int
"""Called to find an application-defined SQL function. It should search for the specified function and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabRenameCallbackFn = def (
    MutExternalPointer[sqlite3_vtab], MutExternalPointer[c_char]
) thin -> c_int
"""Called to rename a virtual table. It should rename the virtual table to the specified name and return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabSavepointCallbackFn = def (MutExternalPointer[sqlite3_vtab], c_int) thin -> c_int
"""Called to create a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabReleaseCallbackFn = def (MutExternalPointer[sqlite3_vtab], c_int) thin -> c_int
"""Called to release a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabRollbackToCallbackFn = def (MutExternalPointer[sqlite3_vtab], c_int) thin -> c_int
"""Called to roll back to a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabShadowNameCallbackFn = def (ImmutExternalPointer[c_char]) thin -> c_int
"""Called to retrieve the shadow name of a virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
comptime VtabIntegrityCallbackFn = def (
    MutExternalPointer[sqlite3_vtab],
    MutExternalPointer[MutExternalPointer[c_char]],
    MutExternalPointer[MutExternalPointer[c_char]],
) thin -> c_int
"""Called to check the integrity of a virtual table. It should perform the integrity check and return SQLITE_OK on success or an appropriate error code on failure."""

struct sqlite3_module(Movable):
    """Virtual Table Module."""
    var iVersion: c_int
    """The version number of the virtual table module. This should be set to 0 for the initial version of the module. Future versions may add new methods to the module, and the version number can be used to indicate which version of the module is being used."""
    var xCreate: VtabCreateCallbackFn
    """Called to create a new virtual table. It should create a new instance of the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xConnect: VtabConnectCallbackFn
    """Called to connect to an existing virtual table. It should initialize a new instance of the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xBestIndex: VtabBestIndexCallbackFn
    """Called to determine the best way to access a virtual table. It should analyze the query constraints and return SQLITE_OK on success or an appropriate error code on failure."""
    var xDisconnect: VtabDisconnectCallbackFn
    """Called to disconnect from a virtual table. It should clean up any resources associated with the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xDestroy: VtabDestroyCallbackFn
    """Called to destroy a virtual table. It should clean up any resources associated with the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xOpen: VtabOpenCallbackFn
    """Called to open a new cursor on a virtual table. It should create a new instance of the cursor and return SQLITE_OK on success or an appropriate error code on failure."""
    var xClose: VtabCloseCallbackFn
    """Called to close a cursor on a virtual table. It should clean up any resources associated with the cursor and return SQLITE_OK on success or an appropriate error code on failure."""
    var xFilter: VtabFilterCallbackFn
    """Called to begin a search of a virtual table. It should initialize the cursor to point to the first row of the result set and return SQLITE_OK on success or an appropriate error code on failure."""
    var xNext: VtabNextCallbackFn
    """Called to advance a cursor to the next row of the result set. It should move the cursor to the next row and return SQLITE_OK on success or an appropriate error code on failure."""
    var xEof: VtabEofCallbackFn
    """Called to determine if a cursor has reached the end of the result set. It should return 1 if the cursor is at the end of the result set and 0 otherwise."""
    var xColumn: VtabColumnCallbackFn
    """Called to retrieve a column value from the current row of the result set. It should use the sqlite3_result_*() interfaces to return the value of the specified column and return SQLITE_OK on success or an appropriate error code on failure."""
    var xRowid: VtabRowidCallbackFn
    """Called to retrieve the rowid of the current row of the result set. It should store the rowid in the provided pointer and return SQLITE_OK on success or an appropriate error code on failure."""
    var xUpdate: VtabUpdateCallbackFn
    """Called to update the virtual table. It should perform the specified update operation (insert, update, or delete) and return SQLITE_OK on success or an appropriate error code on failure."""
    var xBegin: VtabBeginCallbackFn
    """Called to begin a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xSync: VtabSyncCallbackFn
    """Called to sync the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xCommit: VtabCommitCallbackFn
    """Called to commit a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xRollback: VtabRollbackCallbackFn
    """Called to roll back a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xFindFunction: VtabFindFunctionCallbackFn
    """Called to find an application-defined SQL function. It should search for the specified function and return SQLITE_OK on success or an appropriate error code on failure."""
    var xRename: VtabRenameCallbackFn
    """Called to rename a virtual table. It should rename the virtual table to the specified name and return SQLITE_OK on success or an appropriate error code on failure."""
    var xSavepoint: VtabSavepointCallbackFn
    """Called to create a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xRelease: VtabReleaseCallbackFn
    """Called to release a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xRollbackTo: VtabRollbackToCallbackFn
    """Called to roll back to a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xShadowName: VtabShadowNameCallbackFn
    """Called to determine if a shadow table name is reserved. It should return 1 if the name is reserved and 0 otherwise."""
    var xIntegrity: VtabIntegrityCallbackFn
    """Called to perform an integrity check on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""


struct _sqlite3_index_info_sqlite3_index_constraint_usage(Movable):
    var argvIndex: c_int
    var omit: c_uchar


struct _sqlite3_index_info_sqlite3_index_orderby(Movable):
    var iColumn: c_int
    var desc: c_uchar


struct _sqlite3_index_info_sqlite3_index_constraint(Movable):
    var iColumn: c_int
    var op: c_uchar
    var usable: c_uchar
    var iTermOffset: c_int


struct sqlite3_index_info(Movable):
    """Information about query constraints passed to the xBestIndex method of a virtual table module."""

    var nConstraint: c_int
    """The number of entries in the aConstraint array."""
    var aConstraint: MutExternalPointer[_sqlite3_index_info_sqlite3_index_constraint]
    """The array of query constraints."""
    var nOrderBy: c_int
    """The number of entries in the aOrderBy array."""
    var aOrderBy: MutExternalPointer[_sqlite3_index_info_sqlite3_index_orderby]
    """The array of order by clauses."""
    var aConstraintUsage: MutExternalPointer[_sqlite3_index_info_sqlite3_index_constraint_usage]
    """The array of constraint usage information."""
    var idxNum: c_int
    """An integer that the xBestIndex method can use to pass information."""
    var idxStr: MutExternalPointer[c_char]
    """A string that the xBestIndex method can use to pass information to the xFilter method. The string is not interpreted by SQLite and is only used for communication between the xBestIndex and xFilter methods."""
    var needToFreeIdxStr: c_int
    """A flag that indicates whether the idxStr string needs to be freed by SQLite. If the xBestIndex method sets this flag to 1, then SQLite will free the idxStr string after it is used. If the flag is set to 0, then the xBestIndex method is responsible for managing the memory of the idxStr string."""
    var orderByConsumed: c_int
    """An integer that the xBestIndex method can set to indicate that the order by clauses are satisfied by an index. If this value is set to 1, then SQLite will not require the xFilter method to satisfy the order by clauses. If it is set to 0, then the xFilter method must satisfy the order by clauses."""
    var estimatedCost: Float64
    """An estimate of the cost of using the query plan. The xBestIndex method can set this value to indicate the estimated cost of using the query plan. SQLite uses this value to compare different query plans and choose the one with the lowest estimated cost. The cost is an arbitrary number that is only used for comparison purposes, so it does not have a specific unit or meaning outside of the context of comparing query plans."""
    var estimatedRows: Int64
    """An estimate of the number of rows returned by the query plan. The xBestIndex method can set this value to indicate the estimated number of rows that will be returned by the query plan. SQLite uses this value to compare different query plans and choose the one with the lowest estimated cost. The number of rows is an arbitrary number that is only used for comparison purposes, so it does not have a specific unit or meaning outside of the context of comparing query plans."""
    var idxFlags: c_int
    """An integer that the xBestIndex method can use to pass information to the xFilter method. The xBestIndex method can set this value to indicate certain properties of the query plan. For example, it can set the `SQLITE_INDEX_SCAN_UNIQUE` flag to indicate that the query plan will only return a single row. The xFilter method can then use this information to optimize the execution of the query."""
    var colUsed: UInt64
    """A bitmask that indicates which columns of the virtual table are used by the query. The xBestIndex method can set this value to indicate which columns of the virtual table are used by the query. Each bit in the bitmask corresponds to a column of the virtual table, with the least significant bit corresponding to the first column. If a bit is set to 1, it indicates that the corresponding column is used by the query. This information can be used by SQLite to optimize the execution of the query."""


struct sqlite3_vtab(Movable):
    """Structures used by the virtual table interface."""

    var pModule: MutExternalPointer[sqlite3_module]
    """A pointer to the module that implements the virtual table. This is set by the xCreate or xConnect method of the module and is used by SQLite to call the appropriate methods on the module when executing queries against the virtual table."""
    var nRef: c_int
    """The number of references to this virtual table. SQLite uses this value to manage the lifetime of the virtual table. When the reference count drops to zero, SQLite will call the xDisconnect or xDestroy method of the module to clean up the virtual table."""
    var zErrMsg: MutExternalPointer[c_char]
    """A pointer to an error message string. If an error occurs in the xCreate, xConnect, xBestIndex, xDisconnect, or xDestroy methods of the module, the module can set this pointer to point to a string that describes the error. SQLite will free the memory associated with this string when it is no longer needed."""


struct sqlite3_vtab_cursor(Movable):
    """Cursor Object for Virtual Tables."""

    var pVtab: MutExternalPointer[sqlite3_vtab]
    """A pointer to the virtual table that this cursor is associated with. This is set by the xOpen method of the module and is used by SQLite to call the appropriate methods on the module when executing queries against the virtual table."""


struct sqlite3_blob(Movable):
    """A Handle To An Open BLOB.

    An instance of this object represents an open BLOB on which
    `sqlite3_blob_open | incremental BLOB I/O` can be performed.

    * Objects of this type are created by `sqlite3_blob_open()`
    and destroyed by `sqlite3_blob_close()`.
    * The `sqlite3_blob_read()` and `sqlite3_blob_write()` interfaces
    can be used to read or write small subsections of the BLOB.
    * The `sqlite3_blob_bytes()` interface returns the size of the BLOB in bytes."""

    pass
