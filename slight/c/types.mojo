from std.memory import OpaquePointer
from std.utils import StaticTuple
from std.ffi import c_char, c_int

comptime ImmutExternalPointer = ImmutUnsafePointer[origin = ImmutExternalOrigin]
"""Immutable External Pointer.

Parameters:
    type: The type of the data the pointer points to.
"""
comptime ImmutExternalOpaquePointer = ImmutExternalPointer[NoneType]
"""Immutable External Opaque Pointer.

Parameters:
    type: The type of the data the pointer points to.
"""
comptime MutExternalPointer = MutUnsafePointer[origin = MutExternalOrigin]
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
struct DataType(Movable, Equatable, TrivialRegisterPassable):
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

    fn __eq__(self, other: Self) -> Bool:
        """Checks if this value is equal to `other`.

        Args:
            other: The other `DataType` to compare against.
        
        Returns:
            True if both `DataType` instances have the same value, False otherwise.
        """
        return self.value == other.value
    
    fn __eq__(self, other: Int32) -> Bool:
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


comptime ResultDestructorFn = fn (MutExternalPointer[NoneType]) -> NoneType
"""Constants Defining Special Destructor Behavior.

These are special values for the destructor that is passed in as the
final argument to routines like `sqlite3_result_blob()`.

If the destructor argument is `SQLITE_STATIC`, it means that the content pointer is constant
and will never change. It does not need to be destroyed. The
`SQLITE_TRANSIENT` value means that the content will likely change in
the near future and that SQLite should make its own private copy of
the content before returning."""


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
    fn static_destructor() -> ResultDestructorFn:
        """Returns a function pointer representing the `SQLITE_STATIC` destructor.
        
        Returns:
            A function pointer representing the `SQLITE_STATIC` destructor.
        """
        return UnsafePointer(to=Self.STATIC.value).bitcast[ResultDestructorFn]()[]
    
    @staticmethod
    fn transient_destructor() -> ResultDestructorFn:
        """Returns a function pointer representing the `SQLITE_TRANSIENT` destructor.
        
        Returns:
            A function pointer representing the `SQLITE_TRANSIENT` destructor.
        """
        return UnsafePointer(to=Self.TRANSIENT.value).bitcast[ResultDestructorFn]()[]


comptime ExecCallbackFn = fn[argv_origin: MutOrigin, col_name_origin: MutOrigin] (
    data: MutOpaquePointer,
    argc: Int32,
    argv: MutUnsafePointer[MutUnsafePointer[c_char, argv_origin]],
    azColName: MutUnsafePointer[MutUnsafePointer[c_char, col_name_origin]],
) -> c_int
"""Callback Function Type for `sqlite3_exec()`."""

comptime AuthCallbackFn = fn[
    origin: MutOrigin, origin2: ImmutOrigin, origin3: ImmutOrigin, origin4: ImmutOrigin, origin5: ImmutOrigin
] (
    MutOpaquePointer[origin],
    c_int,
    ImmutUnsafePointer[c_char, origin2],
    ImmutUnsafePointer[c_char, origin3],
    ImmutUnsafePointer[c_char, origin4],
    ImmutUnsafePointer[c_char, origin5],
) -> c_int
"""Callback Function Type for `sqlite3_set_authorizer()`."""

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


struct sqlite3_module(Movable):
    """Virtual Table Module."""
    var iVersion: Int32
    """The version number of the virtual table module. This should be set to 0 for the initial version of the module. Future versions may add new methods to the module, and the version number can be used to indicate which version of the module is being used."""
    var xCreate: fn (
        MutExternalPointer[sqlite3_connection],
        OpaquePointer,
        Int32,
        MutExternalPointer[MutExternalPointer[Int8]],
        MutExternalPointer[MutExternalPointer[sqlite3_vtab]],
        MutExternalPointer[MutExternalPointer[Int8]],
    ) -> Int32
    """Called to create a new virtual table. It should create a new instance of the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xConnect: fn (
        MutExternalPointer[sqlite3_connection],
        OpaquePointer,
        Int32,
        MutExternalPointer[MutExternalPointer[Int8]],
        MutExternalPointer[MutExternalPointer[sqlite3_vtab]],
        MutExternalPointer[MutExternalPointer[Int8]],
    ) -> Int32
    """Called to connect to an existing virtual table. It should initialize a new instance of the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xBestIndex: fn (MutExternalPointer[sqlite3_vtab], MutExternalPointer[sqlite3_index_info]) -> Int32
    """Called to determine the best way to access a virtual table. It should analyze the query constraints and return SQLITE_OK on success or an appropriate error code on failure."""
    var xDisconnect: fn (MutExternalPointer[sqlite3_vtab]) -> Int32
    """Called to disconnect from a virtual table. It should clean up any resources associated with the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xDestroy: fn (MutExternalPointer[sqlite3_vtab]) -> Int32
    """Called to destroy a virtual table. It should clean up any resources associated with the virtual table and return SQLITE_OK on success or an appropriate error code on failure."""
    var xOpen: fn (MutExternalPointer[sqlite3_vtab], MutExternalPointer[MutExternalPointer[sqlite3_vtab_cursor]]) -> Int32
    """Called to open a new cursor on a virtual table. It should create a new instance of the cursor and return SQLITE_OK on success or an appropriate error code on failure."""
    var xClose: fn (MutExternalPointer[sqlite3_vtab_cursor]) -> Int32
    """Called to close a cursor on a virtual table. It should clean up any resources associated with the cursor and return SQLITE_OK on success or an appropriate error code on failure."""
    var xFilter: fn (
        MutExternalPointer[sqlite3_vtab_cursor],
        Int32,
        MutExternalPointer[Int8],
        Int32,
        MutExternalPointer[MutExternalPointer[sqlite3_value]],
    ) -> Int32
    """Called to begin a search of a virtual table. It should initialize the cursor to point to the first row of the result set and return SQLITE_OK on success or an appropriate error code on failure."""
    var xNext: fn (MutExternalPointer[sqlite3_vtab_cursor]) -> Int32
    """Called to advance a cursor to the next row of the result set. It should move the cursor to the next row and return SQLITE_OK on success or an appropriate error code on failure."""
    var xEof: fn (MutExternalPointer[sqlite3_vtab_cursor]) -> Int32
    """Called to determine if a cursor has reached the end of the result set. It should return 1 if the cursor is at the end of the result set and 0 otherwise."""
    var xColumn: fn (MutExternalPointer[sqlite3_vtab_cursor], MutExternalPointer[sqlite3_context], Int32) -> Int32
    """Called to retrieve a column value from the current row of the result set. It should use the sqlite3_result_*() interfaces to return the value of the specified column and return SQLITE_OK on success or an appropriate error code on failure."""
    var xRowid: fn (MutExternalPointer[sqlite3_vtab_cursor], MutExternalPointer[Int64]) -> Int32
    """Called to retrieve the rowid of the current row of the result set. It should store the rowid in the provided pointer and return SQLITE_OK on success or an appropriate error code on failure."""
    var xUpdate: fn (
        MutExternalPointer[sqlite3_vtab],
        Int32,
        MutExternalPointer[MutExternalPointer[sqlite3_value]],
        MutExternalPointer[Int64],
    ) -> Int32
    """Called to update the virtual table. It should perform the specified update operation (insert, update, or delete) and return SQLITE_OK on success or an appropriate error code on failure."""
    var xBegin: fn (MutExternalPointer[sqlite3_vtab]) -> Int32
    """Called to begin a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xSync: fn (MutExternalPointer[sqlite3_vtab]) -> Int32
    """Called to sync the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xCommit: fn (MutExternalPointer[sqlite3_vtab]) -> Int32
    """Called to commit a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xRollback: fn (MutExternalPointer[sqlite3_vtab]) -> Int32
    """Called to roll back a transaction on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xFindFunction: fn (
        MutExternalPointer[sqlite3_vtab],
        Int32,
        ImmutExternalPointer[Int8],
        fn (
            MutExternalPointer[sqlite3_context], Int32, MutExternalPointer[MutExternalPointer[sqlite3_value]]
        ) -> MutExternalPointer[MutExternalPointer[NoneType]],
        MutExternalPointer[MutExternalPointer[NoneType]],
    ) -> Int32
    """Called to find an application-defined SQL function. It should search for the specified function and return SQLITE_OK on success or an appropriate error code on failure."""
    var xRename: fn (
        MutExternalPointer[sqlite3_vtab], MutExternalPointer[Int8]
    ) -> Int32
    """Called to rename a virtual table. It should rename the virtual table to the specified name and return SQLITE_OK on success or an appropriate error code on failure."""
    var xSavepoint: fn (MutExternalPointer[sqlite3_vtab], Int32) -> Int32
    """Called to create a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xRelease: fn (MutExternalPointer[sqlite3_vtab], Int32) -> Int32
    """Called to release a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xRollbackTo: fn (MutExternalPointer[sqlite3_vtab], Int32) -> Int32
    """Called to roll back to a savepoint on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""
    var xShadowName: fn (ImmutExternalPointer[Int8]) -> Int32
    """Called to determine if a shadow table name is reserved. It should return 1 if the name is reserved and 0 otherwise."""
    var xIntegrity: fn (
        MutExternalPointer[sqlite3_vtab],
        MutExternalPointer[Int8],
        MutExternalPointer[Int8],
        Int32,
        MutExternalPointer[MutExternalPointer[Int8]],
    ) -> Int32
    """Called to perform an integrity check on the virtual table. It should return SQLITE_OK on success or an appropriate error code on failure."""


struct _sqlite3_index_info_sqlite3_index_constraint_usage(Movable):
    var argvIndex: Int32
    var omit: UInt8


struct _sqlite3_index_info_sqlite3_index_orderby(Movable):
    var iColumn: Int32
    var desc: UInt8


struct _sqlite3_index_info_sqlite3_index_constraint(Movable):
    var iColumn: Int32
    var op: UInt8
    var usable: UInt8
    var iTermOffset: Int32


struct sqlite3_index_info(Movable):
    """Information about query constraints passed to the xBestIndex method of a virtual table module."""
    var nConstraint: Int32
    """The number of entries in the aConstraint array."""
    var aConstraint: MutExternalPointer[_sqlite3_index_info_sqlite3_index_constraint]
    """The array of query constraints."""
    var nOrderBy: Int32
    """The number of entries in the aOrderBy array."""
    var aOrderBy: MutExternalPointer[_sqlite3_index_info_sqlite3_index_orderby]
    """The array of order by clauses."""
    var aConstraintUsage: MutExternalPointer[_sqlite3_index_info_sqlite3_index_constraint_usage]
    """The array of constraint usage information."""
    var idxNum: Int32
    """An integer that the xBestIndex method can use to pass information."""
    var idxStr: MutExternalPointer[Int8]
    """A string that the xBestIndex method can use to pass information to the xFilter method. The string is not interpreted by SQLite and is only used for communication between the xBestIndex and xFilter methods."""
    var needToFreeIdxStr: Int32
    """A flag that indicates whether the idxStr string needs to be freed by SQLite. If the xBestIndex method sets this flag to 1, then SQLite will free the idxStr string after it is used. If the flag is set to 0, then the xBestIndex method is responsible for managing the memory of the idxStr string."""
    var orderByConsumed: Int32
    """An integer that the xBestIndex method can set to indicate that the order by clauses are satisfied by an index. If this value is set to 1, then SQLite will not require the xFilter method to satisfy the order by clauses. If it is set to 0, then the xFilter method must satisfy the order by clauses."""
    var estimatedCost: Float64
    """An estimate of the cost of using the query plan. The xBestIndex method can set this value to indicate the estimated cost of using the query plan. SQLite uses this value to compare different query plans and choose the one with the lowest estimated cost. The cost is an arbitrary number that is only used for comparison purposes, so it does not have a specific unit or meaning outside of the context of comparing query plans."""
    var estimatedRows: Int64
    """An estimate of the number of rows returned by the query plan. The xBestIndex method can set this value to indicate the estimated number of rows that will be returned by the query plan. SQLite uses this value to compare different query plans and choose the one with the lowest estimated cost. The number of rows is an arbitrary number that is only used for comparison purposes, so it does not have a specific unit or meaning outside of the context of comparing query plans."""
    var idxFlags: Int32
    """An integer that the xBestIndex method can use to pass information to the xFilter method. The xBestIndex method can set this value to indicate certain properties of the query plan. For example, it can set the `SQLITE_INDEX_SCAN_UNIQUE` flag to indicate that the query plan will only return a single row. The xFilter method can then use this information to optimize the execution of the query."""
    var colUsed: UInt64
    """A bitmask that indicates which columns of the virtual table are used by the query. The xBestIndex method can set this value to indicate which columns of the virtual table are used by the query. Each bit in the bitmask corresponds to a column of the virtual table, with the least significant bit corresponding to the first column. If a bit is set to 1, it indicates that the corresponding column is used by the query. This information can be used by SQLite to optimize the execution of the query."""


struct sqlite3_vtab(Movable):
    """Structures used by the virtual table interface."""

    var pModule: MutExternalPointer[sqlite3_module]
    """A pointer to the module that implements the virtual table. This is set by the xCreate or xConnect method of the module and is used by SQLite to call the appropriate methods on the module when executing queries against the virtual table."""
    var nRef: Int32
    """The number of references to this virtual table. SQLite uses this value to manage the lifetime of the virtual table. When the reference count drops to zero, SQLite will call the xDisconnect or xDestroy method of the module to clean up the virtual table."""
    var zErrMsg: MutExternalPointer[Int8]
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
