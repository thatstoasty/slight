from std import os
from slight.c.types import (
    AggFinalCallback,
    AggStepCallback,
    AuthCallbackFn,
    ImmutExternalPointer,
    MutExternalPointer,
    ResultDestructorFn,
    ScalarFnCallback,
    WindowInverseCallback,
    WindowValueCallback,
    ExtensionEntrypointCallbackFn,
    TraceCallbackFn,
    TraceV2CallbackFn,
    ProfileCallbackFn,
    QueryProgressCallbackFn,
    CollationCompareCallbackFn,
    CollationNeededCallbackFn,
    UpdateHookCallbackFn,
    CommitHookCallbackFn,
    RollbackHookCallbackFn,
    CancelExtensionCallbackFn,
    UnlockNotifyCallbackFn,
    WALHookCallbackFn,
    BusyHandlerCallbackFn,
    MemoryAlarmCallbackFn,
    sqlite3_backup,
    sqlite3_blob,
    sqlite3_connection,
    sqlite3_context,
    sqlite3_file,
    sqlite3_index_info,
    sqlite3_module,
    sqlite3_snapshot,
    sqlite3_stmt,
    sqlite3_value,
)
from std.ffi import RTLD, CompilationTarget, OwnedDLHandle, c_char, c_int, c_uchar, c_uint
from std.sys.defines import get_defined_string


comptime SQLITE_OPEN_READONLY: Int32 = 0x00000001  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Read Only."""
comptime SQLITE_OPEN_READWRITE: Int32 = 0x00000002  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Read Write."""
comptime SQLITE_OPEN_CREATE: Int32 = 0x00000004  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Create (if the database file does not exist)."""
comptime SQLITE_OPEN_DELETEONCLOSE: Int32 = 0x00000008  # VFS only
"""SQLITE Open Flag: Delete the database file when the connection is closed."""
comptime SQLITE_OPEN_EXCLUSIVE: Int32 = 0x00000010  # VFS only
"""SQLITE Open Flag: Fail if the database file already exists."""
comptime SQLITE_OPEN_AUTOPROXY: Int32 = 0x00000020  # VFS only
"""SQLITE Open Flag: Automatically use a proxy if the file is not accessible."""
comptime SQLITE_OPEN_URI: Int32 = 0x00000040  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Interpret the filename as a URI with query parameters."""
comptime SQLITE_OPEN_MEMORY: Int32 = 0x00000080  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Open an in-memory database."""
comptime SQLITE_OPEN_MAIN_DB: Int32 = 0x00000100  # VFS only
"""SQLITE Open Flag: Open the main database file."""
comptime SQLITE_OPEN_TEMP_DB: Int32 = 0x00000200  # VFS only
"""SQLITE Open Flag: Open the temporary database file."""
comptime SQLITE_OPEN_TRANSIENT_DB: Int32 = 0x00000400  # VFS only
"""SQLITE Open Flag: Open a transient database that is automatically deleted when the connection is closed."""
comptime SQLITE_OPEN_MAIN_JOURNAL: Int32 = 0x00000800  # VFS only
"""SQLITE Open Flag: Open the main journal file."""
comptime SQLITE_OPEN_TEMP_JOURNAL: Int32 = 0x00001000  # VFS only
"""SQLITE Open Flag: Open the temporary journal file."""
comptime SQLITE_OPEN_SUBJOURNAL: Int32 = 0x00002000  # VFS only
"""SQLITE Open Flag: Open the sub-journal file."""
comptime SQLITE_OPEN_SUPER_JOURNAL: Int32 = 0x00004000  # VFS only
"""SQLITE Open Flag: Open the super-journal file."""
comptime SQLITE_OPEN_NOMUTEX: Int32 = 0x00008000  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Do not use mutexes. The connection will be single-threaded."""
comptime SQLITE_OPEN_FULLMUTEX: Int32 = 0x00010000  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Use mutexes for serialized threading mode."""
comptime SQLITE_OPEN_SHAREDCACHE: Int32 = 0x00020000  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Enable shared cache mode for the connection."""
comptime SQLITE_OPEN_PRIVATECACHE: Int32 = 0x00040000  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Disable shared cache mode for the connection."""
comptime SQLITE_OPEN_WAL: Int32 = 0x00080000  # VFS only
"""SQLITE Open Flag: Open the database in WAL mode."""
comptime SQLITE_OPEN_NOFOLLOW: Int32 = 0x01000000  # Ok for sqlite3_open_v2()
"""SQLITE Open Flag: Do not follow symbolic links when opening the database file."""
comptime SQLITE_OPEN_EXRESCODE: Int32 = 0x02000000  # Extended result codes
"""SQLITE Open Flag: Return extended error codes from sqlite3_open_v2()."""

comptime SQLITE_OK: Int32 = 0
"""SQLITE Result Code: Successful result."""
comptime SQLITE_ERROR: Int32 = 1
"""SQLITE Result Code: SQL error or missing database."""
comptime SQLITE_INTERNAL: Int32 = 2
"""SQLITE Result Code: Internal logic error in SQLite."""
comptime SQLITE_PERM: Int32 = 3
"""SQLITE Result Code: Access permission denied."""
comptime SQLITE_ABORT: Int32 = 4
"""SQLITE Result Code: Callback routine requested an abort."""
comptime SQLITE_BUSY: Int32 = 5
"""SQLITE Result Code: The database file is locked."""
comptime SQLITE_LOCKED: Int32 = 6
"""SQLITE Result Code: A table in the database is locked."""
comptime SQLITE_NOMEM: Int32 = 7
"""SQLITE Result Code: A malloc() failed."""
comptime SQLITE_READONLY: Int32 = 8
"""SQLITE Result Code: Attempt to write a readonly database."""
comptime SQLITE_INTERRUPT: Int32 = 9
"""SQLITE Result Code: Operation terminated by sqlite3_interrupt()."""
comptime SQLITE_IOERR: Int32 = 10
"""SQLITE Result Code: Some kind of disk I/O error occurred."""
comptime SQLITE_CORRUPT: Int32 = 11
"""SQLITE Result Code: The database disk image is malformed."""
comptime SQLITE_NOTFOUND: Int32 = 12
"""SQLITE Result Code: The requested item could not be found."""
comptime SQLITE_FULL: Int32 = 13
"""SQLITE Result Code: The database is full."""
comptime SQLITE_CANTOPEN: Int32 = 14
"""SQLITE Result Code: The database file could not be opened."""
comptime SQLITE_PROTOCOL: Int32 = 15
"""SQLITE Result Code: A protocol error occurred."""
comptime SQLITE_EMPTY: Int32 = 16
"""SQLITE Result Code: The database is empty."""
comptime SQLITE_SCHEMA: Int32 = 17
"""SQLITE Result Code: The database schema has changed."""
comptime SQLITE_TOOBIG: Int32 = 18
"""SQLITE Result Code: The data is too large."""
comptime SQLITE_CONSTRAINT: Int32 = 19
"""SQLITE Result Code: A constraint violation occurred."""
comptime SQLITE_MISMATCH: Int32 = 20
"""SQLITE Result Code: Data type mismatch."""
comptime SQLITE_MISUSE: Int32 = 21
"""SQLITE Result Code: The library was used incorrectly."""
comptime SQLITE_NOLFS: Int32 = 22
"""SQLITE Result Code: The database is too large for the file system."""
comptime SQLITE_AUTH: Int32 = 23
"""SQLITE Result Code: Authorization denied."""
comptime SQLITE_FORMAT: Int32 = 24
"""SQLITE Result Code: Auxiliary database format error."""
comptime SQLITE_RANGE: Int32 = 25
"""SQLITE Result Code: 2nd parameter to sqlite3_bind out of range."""
comptime SQLITE_NOTADB: Int32 = 26
"""SQLITE Result Code: File opened that is not a database file."""
comptime SQLITE_NOTICE: Int32 = 27
"""SQLITE Result Code: Notifications from sqlite3_log()."""
comptime SQLITE_WARNING: Int32 = 28
"""SQLITE Result Code: Warnings from sqlite3_log()."""
comptime SQLITE_LOCKED_SHAREDCACHE: Int32 = 262
"""SQLITE Extended Result Code: SQLITE_LOCKED with shared cache."""
comptime SQLITE_ROW: Int32 = 100
"""SQLITE Result Code: sqlite3_step() has another row ready."""
comptime SQLITE_DONE: Int32 = 101
"""SQLITE Result Code: sqlite3_step() has finished executing."""


def _find_sqlite3_library() raises -> String:
    """Locate ``libsqlite3`` via ``$CONDA_PREFIX`` (pixi).

    Returns:
        Library path string for ``OwnedDLHandle``.
    
    Raises:
        Error: If the library path cannot be determined from either the environment variable or the conda prefix.
    """
    var path = os.getenv("SQLITE_LIB_PATH")
    if path != "":
        return path

    var prefix = os.getenv("CONDA_PREFIX", "")
    if prefix != "":
        comptime if CompilationTarget.is_macos():
            return String(t"{prefix}/lib/libsqlite3.dylib")
        else:
            return String(t"{prefix}/lib/libsqlite3.so")
    else:
        raise Error(
            "The path to the SQLite library is not set. Set the path as either a compilation variable with `-D"
            " SQLITE_LIB_PATH=/path/to/libsqlite3.dylib` or `-D SQLITE_LIB_PATH=/path/to/libsqlite3.so`."
            " Or set the `SQLITE_LIB_PATH` environment variable to the path to the sqlite3 library like"
            " `SQLITE_LIB_PATH=/path/to/libsqlite3.dylib` or `SQLITE_LIB_PATH=/path/to/libsqlite3.so`."
        )


comptime sqlite3_libversion_fn = def() abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_sourceid_fn = def() abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_libversion_number_fn = def() abi("C") thin -> c_int
comptime sqlite3_threadsafe_fn = def() abi("C") thin -> c_int
comptime sqlite3_close_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_config_fn = def(c_int) abi("C") thin -> c_int
comptime sqlite3_db_config_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> c_int
comptime sqlite3_extended_result_codes_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> c_int
comptime sqlite3_last_insert_rowid_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> Int64
comptime sqlite3_changes_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_changes64_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> Int64
comptime sqlite3_total_changes_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_total_changes64_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> Int64
comptime sqlite3_interrupt_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> NoneType
comptime sqlite3_is_interrupted_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_busy_handler_fn = def(MutExternalPointer[sqlite3_connection], BusyHandlerCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> c_int
comptime sqlite3_busy_timeout_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> c_int
comptime sqlite3_malloc64_fn = def(UInt64) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_free_fn = def(MutExternalPointer[NoneType]) abi("C") thin -> NoneType
comptime sqlite3_msize_fn = def(MutExternalPointer[NoneType]) abi("C") thin -> UInt64
comptime sqlite3_set_authorizer_fn = def(MutExternalPointer[sqlite3_connection], AuthCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> c_int
comptime sqlite3_trace_fn = def(MutExternalPointer[sqlite3_connection], TraceCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_profile_fn = def(MutExternalPointer[sqlite3_connection], ProfileCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_trace_v2_fn = def(MutExternalPointer[sqlite3_connection], c_uint, TraceV2CallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> c_int
comptime sqlite3_progress_handler_fn = def(MutExternalPointer[sqlite3_connection], c_int, QueryProgressCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> NoneType
comptime sqlite3_open_v2_fn = def(ImmutExternalPointer[c_char], MutExternalPointer[MutExternalPointer[sqlite3_connection]], c_int, ImmutExternalPointer[c_char]) abi("C") thin -> c_int
comptime sqlite3_errcode_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_extended_errcode_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_errmsg_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_errstr_fn = def(c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_error_offset_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_limit_fn = def(MutExternalPointer[sqlite3_connection], c_int, c_int) abi("C") thin -> c_int
comptime sqlite3_prepare_v2_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, MutExternalPointer[MutExternalPointer[sqlite3_stmt]], MutExternalPointer[ImmutExternalPointer[c_char]]) abi("C") thin -> c_int
comptime sqlite3_prepare_v3_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_uint, MutExternalPointer[MutExternalPointer[sqlite3_stmt]], MutExternalPointer[ImmutExternalPointer[c_char]]) abi("C") thin -> c_int
comptime sqlite3_sql_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_expanded_sql_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> MutExternalPointer[c_char]
comptime sqlite3_stmt_readonly_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_stmt_isexplain_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_stmt_busy_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_bind_blob64_fn = def(MutExternalPointer[sqlite3_stmt], c_int, ImmutExternalPointer[NoneType], UInt64, ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_bind_double_fn = def(MutExternalPointer[sqlite3_stmt], c_int, Float64) abi("C") thin -> c_int
comptime sqlite3_bind_int64_fn = def(MutExternalPointer[sqlite3_stmt], c_int, Int64) abi("C") thin -> c_int
comptime sqlite3_bind_null_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> c_int
comptime sqlite3_bind_text64_fn = def(MutExternalPointer[sqlite3_stmt], c_int, ImmutExternalPointer[c_char], UInt64, ResultDestructorFn, c_uchar) abi("C") thin -> c_int
comptime sqlite3_bind_pointer_fn = def(MutExternalPointer[sqlite3_stmt], c_int, MutExternalPointer[NoneType], ImmutExternalPointer[c_char], ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_bind_zeroblob_fn = def(MutExternalPointer[sqlite3_stmt], c_int, c_int) abi("C") thin -> c_int
comptime sqlite3_bind_parameter_count_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_bind_parameter_name_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_bind_parameter_index_fn = def(MutExternalPointer[sqlite3_stmt], ImmutExternalPointer[c_char]) abi("C") thin -> c_int
comptime sqlite3_clear_bindings_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_column_count_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_column_name_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_column_database_name_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_column_table_name_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_column_origin_name_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_column_decltype_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_step_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_column_blob_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[NoneType]
comptime sqlite3_column_double_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> Float64
comptime sqlite3_column_int64_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> Int64
comptime sqlite3_column_text_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> ImmutExternalPointer[c_uchar]
comptime sqlite3_column_value_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> MutExternalPointer[sqlite3_value]
comptime sqlite3_column_bytes_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> c_int
comptime sqlite3_column_type_fn = def(MutExternalPointer[sqlite3_stmt], c_int) abi("C") thin -> c_int
comptime sqlite3_finalize_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_reset_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_create_function_v2_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], ImmutExternalPointer[ScalarFnCallback], ImmutExternalPointer[AggStepCallback], ImmutExternalPointer[AggFinalCallback], ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_create_scalar_function_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], ScalarFnCallback, ImmutExternalPointer[AggStepCallback], ImmutExternalPointer[AggFinalCallback], ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_create_scalar_function_no_data_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], ScalarFnCallback, ImmutExternalPointer[AggStepCallback], ImmutExternalPointer[AggFinalCallback], ImmutExternalPointer[ResultDestructorFn]) abi("C") thin -> c_int
comptime sqlite3_create_aggregate_function_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], ImmutExternalPointer[ScalarFnCallback], AggStepCallback, AggFinalCallback, ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_create_aggregate_function_no_data_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], ImmutExternalPointer[ScalarFnCallback], AggStepCallback, AggFinalCallback, ImmutExternalPointer[ResultDestructorFn]) abi("C") thin -> c_int
comptime sqlite3_remove_function_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], ImmutExternalPointer[ScalarFnCallback], ImmutExternalPointer[AggStepCallback], ImmutExternalPointer[AggFinalCallback], ImmutExternalPointer[ResultDestructorFn]) abi("C") thin -> c_int
comptime sqlite3_create_window_function_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], AggStepCallback, AggFinalCallback, WindowValueCallback, WindowInverseCallback, ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_create_window_function_no_data_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, c_int, MutExternalPointer[NoneType], AggStepCallback, AggFinalCallback, WindowValueCallback, WindowInverseCallback, ImmutExternalPointer[ResultDestructorFn]) abi("C") thin -> c_int
comptime sqlite3_aggregate_count_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> c_int
comptime sqlite3_expired_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_transfer_bindings_fn = def(MutExternalPointer[sqlite3_stmt], MutExternalPointer[sqlite3_stmt]) abi("C") thin -> c_int
comptime sqlite3_global_recover_fn = def() abi("C") thin -> c_int
comptime sqlite3_thread_cleanup_fn = def() abi("C") thin -> NoneType
comptime sqlite3_memory_alarm_fn = def(MemoryAlarmCallbackFn, MutExternalPointer[NoneType], Int64) abi("C") thin -> c_int
comptime sqlite3_value_blob_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> ImmutExternalPointer[NoneType]
comptime sqlite3_value_double_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> Float64
comptime sqlite3_value_int64_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> Int64
comptime sqlite3_value_pointer_fn = def(MutExternalPointer[sqlite3_value], ImmutExternalPointer[c_char]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_value_text_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> ImmutExternalPointer[c_uchar]
comptime sqlite3_value_bytes_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> c_int
comptime sqlite3_value_type_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> c_int
comptime sqlite3_value_nochange_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> c_int
comptime sqlite3_value_subtype_fn = def(MutExternalPointer[sqlite3_value]) abi("C") thin -> c_uint
comptime sqlite3_aggregate_context_fn = def(MutExternalPointer[sqlite3_context], c_int) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_user_data_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_context_db_handle_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> MutExternalPointer[sqlite3_connection]
comptime sqlite3_get_auxdata_fn = def(MutExternalPointer[sqlite3_context], c_int) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_set_auxdata_fn = def(MutExternalPointer[sqlite3_context], c_int, MutExternalPointer[NoneType], ResultDestructorFn) abi("C") thin -> NoneType
comptime sqlite3_result_blob64_fn = def(MutExternalPointer[sqlite3_context], ImmutExternalPointer[NoneType], UInt64, ResultDestructorFn) abi("C") thin -> NoneType
comptime sqlite3_result_double_fn = def(MutExternalPointer[sqlite3_context], Float64) abi("C") thin -> NoneType
comptime sqlite3_result_error_fn = def(MutExternalPointer[sqlite3_context], ImmutExternalPointer[c_char], c_int) abi("C") thin -> NoneType
comptime sqlite3_result_error_toobig_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> NoneType
comptime sqlite3_result_error_nomem_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> NoneType
comptime sqlite3_result_error_code_fn = def(MutExternalPointer[sqlite3_context], c_int) abi("C") thin -> NoneType
comptime sqlite3_result_int64_fn = def(MutExternalPointer[sqlite3_context], Int64) abi("C") thin -> NoneType
comptime sqlite3_result_null_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> NoneType
comptime sqlite3_result_text64_fn = def(MutExternalPointer[sqlite3_context], ImmutExternalPointer[c_char], UInt64, ResultDestructorFn, c_uchar) abi("C") thin -> NoneType
comptime sqlite3_result_value_fn = def(MutExternalPointer[sqlite3_context], MutExternalPointer[sqlite3_value]) abi("C") thin -> NoneType
comptime sqlite3_result_pointer_fn = def(MutExternalPointer[sqlite3_context], MutExternalPointer[NoneType], ImmutExternalPointer[c_char], ResultDestructorFn) abi("C") thin -> NoneType
comptime sqlite3_result_zeroblob_fn = def(MutExternalPointer[sqlite3_context], c_int) abi("C") thin -> NoneType
comptime sqlite3_result_subtype_fn = def(MutExternalPointer[sqlite3_context], c_uint) abi("C") thin -> NoneType
comptime sqlite3_create_collation_v2_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, MutExternalPointer[NoneType], CollationCompareCallbackFn, ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_collation_needed_fn = def(MutExternalPointer[sqlite3_connection], MutExternalPointer[NoneType], CollationNeededCallbackFn) abi("C") thin -> c_int
comptime sqlite3_soft_heap_limit_fn = def(c_int) abi("C") thin -> c_int
comptime sqlite3_soft_heap_limit64_fn = def(Int64) abi("C") thin -> Int64
comptime sqlite3_stmt_status_fn = def(MutExternalPointer[sqlite3_stmt], c_int, c_int) abi("C") thin -> c_int
comptime sqlite3_table_column_metadata_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], ImmutExternalPointer[c_char], ImmutExternalPointer[c_char], MutExternalPointer[ImmutExternalPointer[c_char]], MutExternalPointer[ImmutExternalPointer[c_char]], MutExternalPointer[c_int], MutExternalPointer[c_int], MutExternalPointer[c_int]) abi("C") thin -> c_int
comptime sqlite3_load_extension_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], ImmutExternalPointer[c_char], MutExternalPointer[MutExternalPointer[c_char]]) abi("C") thin -> c_int
comptime sqlite3_enable_load_extension_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> c_int
comptime sqlite3_get_autocommit_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_db_handle_fn = def(MutExternalPointer[sqlite3_stmt]) abi("C") thin -> MutExternalPointer[sqlite3_connection]
comptime sqlite3_db_name_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_db_filename_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char]) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_db_readonly_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char]) abi("C") thin -> c_int
comptime sqlite3_txn_state_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char]) abi("C") thin -> c_int
comptime sqlite3_next_stmt_fn = def(MutExternalPointer[sqlite3_connection], MutExternalPointer[sqlite3_stmt]) abi("C") thin -> MutExternalPointer[sqlite3_stmt]
comptime sqlite3_update_hook_fn = def(MutExternalPointer[sqlite3_connection], MutExternalPointer[UpdateHookCallbackFn], MutExternalPointer[NoneType]) abi("C") thin -> NoneType
comptime sqlite3_commit_hook_fn = def(MutExternalPointer[sqlite3_connection], MutExternalPointer[CommitHookCallbackFn], MutExternalPointer[NoneType]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_rollback_hook_fn = def(MutExternalPointer[sqlite3_connection], MutExternalPointer[RollbackHookCallbackFn], MutExternalPointer[NoneType]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_auto_extension_fn = def(ExtensionEntrypointCallbackFn) abi("C") thin -> c_int
comptime sqlite3_db_release_memory_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_cancel_auto_extension_fn = def(MutExternalPointer[CancelExtensionCallbackFn]) abi("C") thin -> c_int
comptime sqlite3_reset_auto_extension_fn = def() abi("C") thin -> c_int
comptime sqlite3_create_module_v2_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], MutExternalPointer[sqlite3_module], MutExternalPointer[NoneType], ResultDestructorFn) abi("C") thin -> c_int
comptime sqlite3_blob_open_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], ImmutExternalPointer[c_char], ImmutExternalPointer[c_char], Int64, c_int, MutExternalPointer[MutExternalPointer[sqlite3_blob]]) abi("C") thin -> c_int
comptime sqlite3_blob_reopen_fn = def(MutExternalPointer[sqlite3_blob], Int64) abi("C") thin -> c_int
comptime sqlite3_blob_close_fn = def(MutExternalPointer[sqlite3_blob]) abi("C") thin -> c_int
comptime sqlite3_blob_bytes_fn = def(MutExternalPointer[sqlite3_blob]) abi("C") thin -> c_int
comptime sqlite3_blob_read_fn = def(MutExternalPointer[sqlite3_blob], MutExternalPointer[NoneType], c_int, c_int) abi("C") thin -> c_int
comptime sqlite3_blob_write_fn = def(MutExternalPointer[sqlite3_blob], MutExternalPointer[NoneType], c_int, c_int) abi("C") thin -> c_int
comptime sqlite3_file_control_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, MutExternalPointer[NoneType]) abi("C") thin -> c_int
comptime sqlite3_backup_init_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char]) abi("C") thin -> MutExternalPointer[sqlite3_backup]
comptime sqlite3_backup_step_fn = def(MutExternalPointer[sqlite3_backup], c_int) abi("C") thin -> c_int
comptime sqlite3_backup_finish_fn = def(MutExternalPointer[sqlite3_backup]) abi("C") thin -> c_int
comptime sqlite3_backup_remaining_fn = def(MutExternalPointer[sqlite3_backup]) abi("C") thin -> c_int
comptime sqlite3_backup_pagecount_fn = def(MutExternalPointer[sqlite3_backup]) abi("C") thin -> c_int
comptime sqlite3_unlock_notify_fn = def(MutExternalPointer[sqlite3_connection], UnlockNotifyCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> c_int
comptime sqlite3_log_fn = def(c_int, ImmutExternalPointer[c_char]) abi("C") thin -> NoneType
comptime sqlite3_wal_hook_fn = def(MutExternalPointer[sqlite3_connection], WALHookCallbackFn, MutExternalPointer[NoneType]) abi("C") thin -> MutExternalPointer[NoneType]
comptime sqlite3_wal_autocheckpoint_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> c_int
comptime sqlite3_wal_checkpoint_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char]) abi("C") thin -> c_int
comptime sqlite3_wal_checkpoint_v2_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], c_int, MutExternalPointer[c_int], MutExternalPointer[c_int]) abi("C") thin -> c_int
comptime sqlite3_vtab_config_fn = def(MutExternalPointer[sqlite3_connection], c_int) abi("C") thin -> c_int
comptime sqlite3_vtab_on_conflict_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_vtab_nochange_fn = def(MutExternalPointer[sqlite3_context]) abi("C") thin -> c_int
comptime sqlite3_vtab_collation_fn = def(MutExternalPointer[sqlite3_index_info], c_int) abi("C") thin -> ImmutExternalPointer[c_char]
comptime sqlite3_vtab_distinct_fn = def(MutExternalPointer[sqlite3_index_info]) abi("C") thin -> c_int
comptime sqlite3_db_cacheflush_fn = def(MutExternalPointer[sqlite3_connection]) abi("C") thin -> c_int
comptime sqlite3_serialize_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], MutExternalPointer[Int64], c_uint) abi("C") thin -> MutExternalPointer[c_uchar]
comptime sqlite3_deserialize_fn = def(MutExternalPointer[sqlite3_connection], ImmutExternalPointer[c_char], MutExternalPointer[c_uchar], Int64, Int64, c_uint) abi("C") thin -> c_int



@fieldwise_init
struct _sqlite3(Movable):
    """SQLite3 C API binding struct.

    This struct provides a high-level interface to the SQLite3 C library
    by dynamically loading the shared library and exposing the C functions
    as Mojo methods. It handles the FFI (Foreign Function Interface) calls
    to the underlying SQLite3 C implementation.
    """

    var lib: OwnedDLHandle
    """Handle to the dynamically loaded SQLite3 library."""
    var _fn_sqlite3_libversion: sqlite3_libversion_fn
    var _fn_sqlite3_sourceid: sqlite3_sourceid_fn
    var _fn_sqlite3_libversion_number: sqlite3_libversion_number_fn
    var _fn_sqlite3_threadsafe: sqlite3_threadsafe_fn
    var _fn_sqlite3_close: sqlite3_close_fn
    var _fn_sqlite3_config: sqlite3_config_fn
    var _fn_sqlite3_db_config: sqlite3_db_config_fn
    var _fn_sqlite3_extended_result_codes: sqlite3_extended_result_codes_fn
    var _fn_sqlite3_last_insert_rowid: sqlite3_last_insert_rowid_fn
    var _fn_sqlite3_changes: sqlite3_changes_fn
    var _fn_sqlite3_changes64: sqlite3_changes64_fn
    var _fn_sqlite3_total_changes: sqlite3_total_changes_fn
    var _fn_sqlite3_total_changes64: sqlite3_total_changes64_fn
    var _fn_sqlite3_interrupt: sqlite3_interrupt_fn
    var _fn_sqlite3_is_interrupted: sqlite3_is_interrupted_fn
    var _fn_sqlite3_busy_handler: sqlite3_busy_handler_fn
    var _fn_sqlite3_busy_timeout: sqlite3_busy_timeout_fn
    var _fn_sqlite3_malloc64: sqlite3_malloc64_fn
    var _fn_sqlite3_free: sqlite3_free_fn
    var _fn_sqlite3_msize: sqlite3_msize_fn
    var _fn_sqlite3_set_authorizer: sqlite3_set_authorizer_fn
    var _fn_sqlite3_trace: sqlite3_trace_fn
    var _fn_sqlite3_profile: sqlite3_profile_fn
    var _fn_sqlite3_trace_v2: sqlite3_trace_v2_fn
    var _fn_sqlite3_progress_handler: sqlite3_progress_handler_fn
    var _fn_sqlite3_open_v2: sqlite3_open_v2_fn
    var _fn_sqlite3_errcode: sqlite3_errcode_fn
    var _fn_sqlite3_extended_errcode: sqlite3_extended_errcode_fn
    var _fn_sqlite3_errmsg: sqlite3_errmsg_fn
    var _fn_sqlite3_errstr: sqlite3_errstr_fn
    var _fn_sqlite3_error_offset: sqlite3_error_offset_fn
    var _fn_sqlite3_limit: sqlite3_limit_fn
    var _fn_sqlite3_prepare_v2: sqlite3_prepare_v2_fn
    var _fn_sqlite3_prepare_v3: sqlite3_prepare_v3_fn
    var _fn_sqlite3_sql: sqlite3_sql_fn
    var _fn_sqlite3_expanded_sql: sqlite3_expanded_sql_fn
    var _fn_sqlite3_stmt_readonly: sqlite3_stmt_readonly_fn
    var _fn_sqlite3_stmt_isexplain: sqlite3_stmt_isexplain_fn
    var _fn_sqlite3_stmt_busy: sqlite3_stmt_busy_fn
    var _fn_sqlite3_bind_blob64: sqlite3_bind_blob64_fn
    var _fn_sqlite3_bind_double: sqlite3_bind_double_fn
    var _fn_sqlite3_bind_int64: sqlite3_bind_int64_fn
    var _fn_sqlite3_bind_null: sqlite3_bind_null_fn
    var _fn_sqlite3_bind_text64: sqlite3_bind_text64_fn
    var _fn_sqlite3_bind_pointer: sqlite3_bind_pointer_fn
    var _fn_sqlite3_bind_zeroblob: sqlite3_bind_zeroblob_fn
    var _fn_sqlite3_bind_parameter_count: sqlite3_bind_parameter_count_fn
    var _fn_sqlite3_bind_parameter_name: sqlite3_bind_parameter_name_fn
    var _fn_sqlite3_bind_parameter_index: sqlite3_bind_parameter_index_fn
    var _fn_sqlite3_clear_bindings: sqlite3_clear_bindings_fn
    var _fn_sqlite3_column_count: sqlite3_column_count_fn
    var _fn_sqlite3_column_name: sqlite3_column_name_fn
    var _fn_sqlite3_column_database_name: sqlite3_column_database_name_fn
    var _fn_sqlite3_column_table_name: sqlite3_column_table_name_fn
    var _fn_sqlite3_column_origin_name: sqlite3_column_origin_name_fn
    var _fn_sqlite3_column_decltype: sqlite3_column_decltype_fn
    var _fn_sqlite3_step: sqlite3_step_fn
    var _fn_sqlite3_column_blob: sqlite3_column_blob_fn
    var _fn_sqlite3_column_double: sqlite3_column_double_fn
    var _fn_sqlite3_column_int64: sqlite3_column_int64_fn
    var _fn_sqlite3_column_text: sqlite3_column_text_fn
    var _fn_sqlite3_column_value: sqlite3_column_value_fn
    var _fn_sqlite3_column_bytes: sqlite3_column_bytes_fn
    var _fn_sqlite3_column_type: sqlite3_column_type_fn
    var _fn_sqlite3_finalize: sqlite3_finalize_fn
    var _fn_sqlite3_reset: sqlite3_reset_fn
    var _fn_sqlite3_create_function_v2: sqlite3_create_function_v2_fn
    var _fn_sqlite3_create_scalar_function: sqlite3_create_scalar_function_fn
    var _fn_sqlite3_create_scalar_function_no_data: sqlite3_create_scalar_function_no_data_fn
    var _fn_sqlite3_create_aggregate_function: sqlite3_create_aggregate_function_fn
    var _fn_sqlite3_create_aggregate_function_no_data: sqlite3_create_aggregate_function_no_data_fn
    var _fn_sqlite3_remove_function: sqlite3_remove_function_fn
    var _fn_sqlite3_create_window_function: sqlite3_create_window_function_fn
    var _fn_sqlite3_create_window_function_no_data: sqlite3_create_window_function_no_data_fn
    var _fn_sqlite3_aggregate_count: sqlite3_aggregate_count_fn
    var _fn_sqlite3_expired: sqlite3_expired_fn
    var _fn_sqlite3_transfer_bindings: sqlite3_transfer_bindings_fn
    var _fn_sqlite3_global_recover: sqlite3_global_recover_fn
    var _fn_sqlite3_thread_cleanup: sqlite3_thread_cleanup_fn
    var _fn_sqlite3_memory_alarm: sqlite3_memory_alarm_fn
    var _fn_sqlite3_value_blob: sqlite3_value_blob_fn
    var _fn_sqlite3_value_double: sqlite3_value_double_fn
    var _fn_sqlite3_value_int64: sqlite3_value_int64_fn
    var _fn_sqlite3_value_pointer: sqlite3_value_pointer_fn
    var _fn_sqlite3_value_text: sqlite3_value_text_fn
    var _fn_sqlite3_value_bytes: sqlite3_value_bytes_fn
    var _fn_sqlite3_value_type: sqlite3_value_type_fn
    var _fn_sqlite3_value_nochange: sqlite3_value_nochange_fn
    var _fn_sqlite3_value_subtype: sqlite3_value_subtype_fn
    var _fn_sqlite3_aggregate_context: sqlite3_aggregate_context_fn
    var _fn_sqlite3_user_data: sqlite3_user_data_fn
    var _fn_sqlite3_context_db_handle: sqlite3_context_db_handle_fn
    var _fn_sqlite3_get_auxdata: sqlite3_get_auxdata_fn
    var _fn_sqlite3_set_auxdata: sqlite3_set_auxdata_fn
    var _fn_sqlite3_result_blob64: sqlite3_result_blob64_fn
    var _fn_sqlite3_result_double: sqlite3_result_double_fn
    var _fn_sqlite3_result_error: sqlite3_result_error_fn
    var _fn_sqlite3_result_error_toobig: sqlite3_result_error_toobig_fn
    var _fn_sqlite3_result_error_nomem: sqlite3_result_error_nomem_fn
    var _fn_sqlite3_result_error_code: sqlite3_result_error_code_fn
    var _fn_sqlite3_result_int64: sqlite3_result_int64_fn
    var _fn_sqlite3_result_null: sqlite3_result_null_fn
    var _fn_sqlite3_result_text64: sqlite3_result_text64_fn
    var _fn_sqlite3_result_value: sqlite3_result_value_fn
    var _fn_sqlite3_result_pointer: sqlite3_result_pointer_fn
    var _fn_sqlite3_result_zeroblob: sqlite3_result_zeroblob_fn
    var _fn_sqlite3_result_subtype: sqlite3_result_subtype_fn
    var _fn_sqlite3_create_collation_v2: sqlite3_create_collation_v2_fn
    var _fn_sqlite3_collation_needed: sqlite3_collation_needed_fn
    var _fn_sqlite3_soft_heap_limit: sqlite3_soft_heap_limit_fn
    var _fn_sqlite3_soft_heap_limit64: sqlite3_soft_heap_limit64_fn
    var _fn_sqlite3_stmt_status: sqlite3_stmt_status_fn
    var _fn_sqlite3_table_column_metadata: sqlite3_table_column_metadata_fn
    var _fn_sqlite3_load_extension: sqlite3_load_extension_fn
    var _fn_sqlite3_enable_load_extension: sqlite3_enable_load_extension_fn
    var _fn_sqlite3_get_autocommit: sqlite3_get_autocommit_fn
    var _fn_sqlite3_db_handle: sqlite3_db_handle_fn
    var _fn_sqlite3_db_name: sqlite3_db_name_fn
    var _fn_sqlite3_db_filename: sqlite3_db_filename_fn
    var _fn_sqlite3_db_readonly: sqlite3_db_readonly_fn
    var _fn_sqlite3_txn_state: sqlite3_txn_state_fn
    var _fn_sqlite3_next_stmt: sqlite3_next_stmt_fn
    var _fn_sqlite3_update_hook: sqlite3_update_hook_fn
    var _fn_sqlite3_commit_hook: sqlite3_commit_hook_fn
    var _fn_sqlite3_rollback_hook: sqlite3_rollback_hook_fn
    var _fn_sqlite3_auto_extension: sqlite3_auto_extension_fn
    var _fn_sqlite3_db_release_memory: sqlite3_db_release_memory_fn
    var _fn_sqlite3_cancel_auto_extension: sqlite3_cancel_auto_extension_fn
    var _fn_sqlite3_reset_auto_extension: sqlite3_reset_auto_extension_fn
    var _fn_sqlite3_create_module_v2: sqlite3_create_module_v2_fn
    var _fn_sqlite3_blob_open: sqlite3_blob_open_fn
    var _fn_sqlite3_blob_reopen: sqlite3_blob_reopen_fn
    var _fn_sqlite3_blob_close: sqlite3_blob_close_fn
    var _fn_sqlite3_blob_bytes: sqlite3_blob_bytes_fn
    var _fn_sqlite3_blob_read: sqlite3_blob_read_fn
    var _fn_sqlite3_blob_write: sqlite3_blob_write_fn
    var _fn_sqlite3_file_control: sqlite3_file_control_fn
    var _fn_sqlite3_backup_init: sqlite3_backup_init_fn
    var _fn_sqlite3_backup_step: sqlite3_backup_step_fn
    var _fn_sqlite3_backup_finish: sqlite3_backup_finish_fn
    var _fn_sqlite3_backup_remaining: sqlite3_backup_remaining_fn
    var _fn_sqlite3_backup_pagecount: sqlite3_backup_pagecount_fn
    var _fn_sqlite3_unlock_notify: sqlite3_unlock_notify_fn
    var _fn_sqlite3_log: sqlite3_log_fn
    var _fn_sqlite3_wal_hook: sqlite3_wal_hook_fn
    var _fn_sqlite3_wal_autocheckpoint: sqlite3_wal_autocheckpoint_fn
    var _fn_sqlite3_wal_checkpoint: sqlite3_wal_checkpoint_fn
    var _fn_sqlite3_wal_checkpoint_v2: sqlite3_wal_checkpoint_v2_fn
    var _fn_sqlite3_vtab_config: sqlite3_vtab_config_fn
    var _fn_sqlite3_vtab_on_conflict: sqlite3_vtab_on_conflict_fn
    var _fn_sqlite3_vtab_nochange: sqlite3_vtab_nochange_fn
    var _fn_sqlite3_vtab_collation: sqlite3_vtab_collation_fn
    var _fn_sqlite3_vtab_distinct: sqlite3_vtab_distinct_fn
    var _fn_sqlite3_db_cacheflush: sqlite3_db_cacheflush_fn
    var _fn_sqlite3_serialize: sqlite3_serialize_fn
    var _fn_sqlite3_deserialize: sqlite3_deserialize_fn


    def __init__(out self):
        """Initialize the SQLite3 binding by loading the dynamic library.

        This constructor attempts to load the SQLite3 shared library from
        the expected location. If loading fails, the program will abort.

        Aborts if the SQLite3 library cannot be loaded.
        """
        try:
            var defined_path = get_defined_string["SQLITE_LIB_PATH", ""]()
            if defined_path != "":
                self.lib = OwnedDLHandle(defined_path, RTLD.LAZY)
            else:
                self.lib = OwnedDLHandle(_find_sqlite3_library(), RTLD.LAZY)

            self._fn_sqlite3_libversion = self.lib.get_function[sqlite3_libversion_fn]("sqlite3_libversion")
            self._fn_sqlite3_sourceid = self.lib.get_function[sqlite3_sourceid_fn]("sqlite3_sourceid")
            self._fn_sqlite3_libversion_number = self.lib.get_function[sqlite3_libversion_number_fn]("sqlite3_libversion_number")
            self._fn_sqlite3_threadsafe = self.lib.get_function[sqlite3_threadsafe_fn]("sqlite3_threadsafe")
            self._fn_sqlite3_close = self.lib.get_function[sqlite3_close_fn]("sqlite3_close")
            self._fn_sqlite3_config = self.lib.get_function[sqlite3_config_fn]("sqlite3_config")
            self._fn_sqlite3_db_config = self.lib.get_function[sqlite3_db_config_fn]("sqlite3_db_config")
            self._fn_sqlite3_extended_result_codes = self.lib.get_function[sqlite3_extended_result_codes_fn]("sqlite3_extended_result_codes")
            self._fn_sqlite3_last_insert_rowid = self.lib.get_function[sqlite3_last_insert_rowid_fn]("sqlite3_last_insert_rowid")
            self._fn_sqlite3_changes = self.lib.get_function[sqlite3_changes_fn]("sqlite3_changes")
            self._fn_sqlite3_changes64 = self.lib.get_function[sqlite3_changes64_fn]("sqlite3_changes64")
            self._fn_sqlite3_total_changes = self.lib.get_function[sqlite3_total_changes_fn]("sqlite3_total_changes")
            self._fn_sqlite3_total_changes64 = self.lib.get_function[sqlite3_total_changes64_fn]("sqlite3_total_changes64")
            self._fn_sqlite3_interrupt = self.lib.get_function[sqlite3_interrupt_fn]("sqlite3_interrupt")
            self._fn_sqlite3_is_interrupted = self.lib.get_function[sqlite3_is_interrupted_fn]("sqlite3_is_interrupted")
            self._fn_sqlite3_busy_handler = self.lib.get_function[sqlite3_busy_handler_fn]("sqlite3_busy_handler")
            self._fn_sqlite3_busy_timeout = self.lib.get_function[sqlite3_busy_timeout_fn]("sqlite3_busy_timeout")
            self._fn_sqlite3_malloc64 = self.lib.get_function[sqlite3_malloc64_fn]("sqlite3_malloc64")
            self._fn_sqlite3_free = self.lib.get_function[sqlite3_free_fn]("sqlite3_free")
            self._fn_sqlite3_msize = self.lib.get_function[sqlite3_msize_fn]("sqlite3_msize")
            self._fn_sqlite3_set_authorizer = self.lib.get_function[sqlite3_set_authorizer_fn]("sqlite3_set_authorizer")
            self._fn_sqlite3_trace = self.lib.get_function[sqlite3_trace_fn]("sqlite3_trace")
            self._fn_sqlite3_profile = self.lib.get_function[sqlite3_profile_fn]("sqlite3_profile")
            self._fn_sqlite3_trace_v2 = self.lib.get_function[sqlite3_trace_v2_fn]("sqlite3_trace_v2")
            self._fn_sqlite3_progress_handler = self.lib.get_function[sqlite3_progress_handler_fn]("sqlite3_progress_handler")
            self._fn_sqlite3_open_v2 = self.lib.get_function[sqlite3_open_v2_fn]("sqlite3_open_v2")
            self._fn_sqlite3_errcode = self.lib.get_function[sqlite3_errcode_fn]("sqlite3_errcode")
            self._fn_sqlite3_extended_errcode = self.lib.get_function[sqlite3_extended_errcode_fn]("sqlite3_extended_errcode")
            self._fn_sqlite3_errmsg = self.lib.get_function[sqlite3_errmsg_fn]("sqlite3_errmsg")
            self._fn_sqlite3_errstr = self.lib.get_function[sqlite3_errstr_fn]("sqlite3_errstr")
            self._fn_sqlite3_error_offset = self.lib.get_function[sqlite3_error_offset_fn]("sqlite3_error_offset")
            self._fn_sqlite3_limit = self.lib.get_function[sqlite3_limit_fn]("sqlite3_limit")
            self._fn_sqlite3_prepare_v2 = self.lib.get_function[sqlite3_prepare_v2_fn]("sqlite3_prepare_v2")
            self._fn_sqlite3_prepare_v3 = self.lib.get_function[sqlite3_prepare_v3_fn]("sqlite3_prepare_v3")
            self._fn_sqlite3_sql = self.lib.get_function[sqlite3_sql_fn]("sqlite3_sql")
            self._fn_sqlite3_expanded_sql = self.lib.get_function[sqlite3_expanded_sql_fn]("sqlite3_expanded_sql")
            self._fn_sqlite3_stmt_readonly = self.lib.get_function[sqlite3_stmt_readonly_fn]("sqlite3_stmt_readonly")
            self._fn_sqlite3_stmt_isexplain = self.lib.get_function[sqlite3_stmt_isexplain_fn]("sqlite3_stmt_isexplain")
            self._fn_sqlite3_stmt_busy = self.lib.get_function[sqlite3_stmt_busy_fn]("sqlite3_stmt_busy")
            self._fn_sqlite3_bind_blob64 = self.lib.get_function[sqlite3_bind_blob64_fn]("sqlite3_bind_blob64")
            self._fn_sqlite3_bind_double = self.lib.get_function[sqlite3_bind_double_fn]("sqlite3_bind_double")
            self._fn_sqlite3_bind_int64 = self.lib.get_function[sqlite3_bind_int64_fn]("sqlite3_bind_int64")
            self._fn_sqlite3_bind_null = self.lib.get_function[sqlite3_bind_null_fn]("sqlite3_bind_null")
            self._fn_sqlite3_bind_text64 = self.lib.get_function[sqlite3_bind_text64_fn]("sqlite3_bind_text64")
            self._fn_sqlite3_bind_pointer = self.lib.get_function[sqlite3_bind_pointer_fn]("sqlite3_bind_pointer")
            self._fn_sqlite3_bind_zeroblob = self.lib.get_function[sqlite3_bind_zeroblob_fn]("sqlite3_bind_zeroblob")
            self._fn_sqlite3_bind_parameter_count = self.lib.get_function[sqlite3_bind_parameter_count_fn]("sqlite3_bind_parameter_count")
            self._fn_sqlite3_bind_parameter_name = self.lib.get_function[sqlite3_bind_parameter_name_fn]("sqlite3_bind_parameter_name")
            self._fn_sqlite3_bind_parameter_index = self.lib.get_function[sqlite3_bind_parameter_index_fn]("sqlite3_bind_parameter_index")
            self._fn_sqlite3_clear_bindings = self.lib.get_function[sqlite3_clear_bindings_fn]("sqlite3_clear_bindings")
            self._fn_sqlite3_column_count = self.lib.get_function[sqlite3_column_count_fn]("sqlite3_column_count")
            self._fn_sqlite3_column_name = self.lib.get_function[sqlite3_column_name_fn]("sqlite3_column_name")
            self._fn_sqlite3_column_database_name = self.lib.get_function[sqlite3_column_database_name_fn]("sqlite3_column_database_name")
            self._fn_sqlite3_column_table_name = self.lib.get_function[sqlite3_column_table_name_fn]("sqlite3_column_table_name")
            self._fn_sqlite3_column_origin_name = self.lib.get_function[sqlite3_column_origin_name_fn]("sqlite3_column_origin_name")
            self._fn_sqlite3_column_decltype = self.lib.get_function[sqlite3_column_decltype_fn]("sqlite3_column_decltype")
            self._fn_sqlite3_step = self.lib.get_function[sqlite3_step_fn]("sqlite3_step")
            self._fn_sqlite3_column_blob = self.lib.get_function[sqlite3_column_blob_fn]("sqlite3_column_blob")
            self._fn_sqlite3_column_double = self.lib.get_function[sqlite3_column_double_fn]("sqlite3_column_double")
            self._fn_sqlite3_column_int64 = self.lib.get_function[sqlite3_column_int64_fn]("sqlite3_column_int64")
            self._fn_sqlite3_column_text = self.lib.get_function[sqlite3_column_text_fn]("sqlite3_column_text")
            self._fn_sqlite3_column_value = self.lib.get_function[sqlite3_column_value_fn]("sqlite3_column_value")
            self._fn_sqlite3_column_bytes = self.lib.get_function[sqlite3_column_bytes_fn]("sqlite3_column_bytes")
            self._fn_sqlite3_column_type = self.lib.get_function[sqlite3_column_type_fn]("sqlite3_column_type")
            self._fn_sqlite3_finalize = self.lib.get_function[sqlite3_finalize_fn]("sqlite3_finalize")
            self._fn_sqlite3_reset = self.lib.get_function[sqlite3_reset_fn]("sqlite3_reset")
            self._fn_sqlite3_create_function_v2 = self.lib.get_function[sqlite3_create_function_v2_fn]("sqlite3_create_function_v2")
            self._fn_sqlite3_create_scalar_function = self.lib.get_function[sqlite3_create_scalar_function_fn]("sqlite3_create_function_v2")
            self._fn_sqlite3_create_scalar_function_no_data = self.lib.get_function[sqlite3_create_scalar_function_no_data_fn]("sqlite3_create_function_v2")
            self._fn_sqlite3_create_aggregate_function = self.lib.get_function[sqlite3_create_aggregate_function_fn]("sqlite3_create_function_v2")
            self._fn_sqlite3_create_aggregate_function_no_data = self.lib.get_function[sqlite3_create_aggregate_function_no_data_fn]("sqlite3_create_function_v2")
            self._fn_sqlite3_remove_function = self.lib.get_function[sqlite3_remove_function_fn]("sqlite3_create_function_v2")
            self._fn_sqlite3_create_window_function = self.lib.get_function[sqlite3_create_window_function_fn]("sqlite3_create_window_function")
            self._fn_sqlite3_create_window_function_no_data = self.lib.get_function[sqlite3_create_window_function_no_data_fn]("sqlite3_create_window_function")
            self._fn_sqlite3_aggregate_count = self.lib.get_function[sqlite3_aggregate_count_fn]("sqlite3_aggregate_count")
            self._fn_sqlite3_expired = self.lib.get_function[sqlite3_expired_fn]("sqlite3_expired")
            self._fn_sqlite3_transfer_bindings = self.lib.get_function[sqlite3_transfer_bindings_fn]("sqlite3_transfer_bindings")
            self._fn_sqlite3_global_recover = self.lib.get_function[sqlite3_global_recover_fn]("sqlite3_global_recover")
            self._fn_sqlite3_thread_cleanup = self.lib.get_function[sqlite3_thread_cleanup_fn]("sqlite3_thread_cleanup")
            self._fn_sqlite3_memory_alarm = self.lib.get_function[sqlite3_memory_alarm_fn]("sqlite3_memory_alarm")
            self._fn_sqlite3_value_blob = self.lib.get_function[sqlite3_value_blob_fn]("sqlite3_value_blob")
            self._fn_sqlite3_value_double = self.lib.get_function[sqlite3_value_double_fn]("sqlite3_value_double")
            self._fn_sqlite3_value_int64 = self.lib.get_function[sqlite3_value_int64_fn]("sqlite3_value_int64")
            self._fn_sqlite3_value_pointer = self.lib.get_function[sqlite3_value_pointer_fn]("sqlite3_value_pointer")
            self._fn_sqlite3_value_text = self.lib.get_function[sqlite3_value_text_fn]("sqlite3_value_text")
            self._fn_sqlite3_value_bytes = self.lib.get_function[sqlite3_value_bytes_fn]("sqlite3_value_bytes")
            self._fn_sqlite3_value_type = self.lib.get_function[sqlite3_value_type_fn]("sqlite3_value_type")
            self._fn_sqlite3_value_nochange = self.lib.get_function[sqlite3_value_nochange_fn]("sqlite3_value_nochange")
            self._fn_sqlite3_value_subtype = self.lib.get_function[sqlite3_value_subtype_fn]("sqlite3_value_subtype")
            self._fn_sqlite3_aggregate_context = self.lib.get_function[sqlite3_aggregate_context_fn]("sqlite3_aggregate_context")
            self._fn_sqlite3_user_data = self.lib.get_function[sqlite3_user_data_fn]("sqlite3_user_data")
            self._fn_sqlite3_context_db_handle = self.lib.get_function[sqlite3_context_db_handle_fn]("sqlite3_context_db_handle")
            self._fn_sqlite3_get_auxdata = self.lib.get_function[sqlite3_get_auxdata_fn]("sqlite3_get_auxdata")
            self._fn_sqlite3_set_auxdata = self.lib.get_function[sqlite3_set_auxdata_fn]("sqlite3_set_auxdata")
            self._fn_sqlite3_result_blob64 = self.lib.get_function[sqlite3_result_blob64_fn]("sqlite3_result_blob64")
            self._fn_sqlite3_result_double = self.lib.get_function[sqlite3_result_double_fn]("sqlite3_result_double")
            self._fn_sqlite3_result_error = self.lib.get_function[sqlite3_result_error_fn]("sqlite3_result_error")
            self._fn_sqlite3_result_error_toobig = self.lib.get_function[sqlite3_result_error_toobig_fn]("sqlite3_result_error_toobig")
            self._fn_sqlite3_result_error_nomem = self.lib.get_function[sqlite3_result_error_nomem_fn]("sqlite3_result_error_nomem")
            self._fn_sqlite3_result_error_code = self.lib.get_function[sqlite3_result_error_code_fn]("sqlite3_result_error_code")
            self._fn_sqlite3_result_int64 = self.lib.get_function[sqlite3_result_int64_fn]("sqlite3_result_int64")
            self._fn_sqlite3_result_null = self.lib.get_function[sqlite3_result_null_fn]("sqlite3_result_null")
            self._fn_sqlite3_result_text64 = self.lib.get_function[sqlite3_result_text64_fn]("sqlite3_result_text64")
            self._fn_sqlite3_result_value = self.lib.get_function[sqlite3_result_value_fn]("sqlite3_result_value")
            self._fn_sqlite3_result_pointer = self.lib.get_function[sqlite3_result_pointer_fn]("sqlite3_result_pointer")
            self._fn_sqlite3_result_zeroblob = self.lib.get_function[sqlite3_result_zeroblob_fn]("sqlite3_result_zeroblob")
            self._fn_sqlite3_result_subtype = self.lib.get_function[sqlite3_result_subtype_fn]("sqlite3_result_subtype")
            self._fn_sqlite3_create_collation_v2 = self.lib.get_function[sqlite3_create_collation_v2_fn]("sqlite3_create_collation_v2")
            self._fn_sqlite3_collation_needed = self.lib.get_function[sqlite3_collation_needed_fn]("sqlite3_collation_needed")
            self._fn_sqlite3_soft_heap_limit = self.lib.get_function[sqlite3_soft_heap_limit_fn]("sqlite3_soft_heap_limit")
            self._fn_sqlite3_soft_heap_limit64 = self.lib.get_function[sqlite3_soft_heap_limit64_fn]("sqlite3_soft_heap_limit64")
            self._fn_sqlite3_stmt_status = self.lib.get_function[sqlite3_stmt_status_fn]("sqlite3_stmt_status")
            self._fn_sqlite3_table_column_metadata = self.lib.get_function[sqlite3_table_column_metadata_fn]("sqlite3_table_column_metadata")
            self._fn_sqlite3_load_extension = self.lib.get_function[sqlite3_load_extension_fn]("sqlite3_load_extension")
            self._fn_sqlite3_enable_load_extension = self.lib.get_function[sqlite3_enable_load_extension_fn]("sqlite3_enable_load_extension")
            self._fn_sqlite3_get_autocommit = self.lib.get_function[sqlite3_get_autocommit_fn]("sqlite3_get_autocommit")
            self._fn_sqlite3_db_handle = self.lib.get_function[sqlite3_db_handle_fn]("sqlite3_db_handle")
            self._fn_sqlite3_db_name = self.lib.get_function[sqlite3_db_name_fn]("sqlite3_db_name")
            self._fn_sqlite3_db_filename = self.lib.get_function[sqlite3_db_filename_fn]("sqlite3_db_filename")
            self._fn_sqlite3_db_readonly = self.lib.get_function[sqlite3_db_readonly_fn]("sqlite3_db_readonly")
            self._fn_sqlite3_txn_state = self.lib.get_function[sqlite3_txn_state_fn]("sqlite3_txn_state")
            self._fn_sqlite3_next_stmt = self.lib.get_function[sqlite3_next_stmt_fn]("sqlite3_next_stmt")
            self._fn_sqlite3_update_hook = self.lib.get_function[sqlite3_update_hook_fn]("sqlite3_update_hook")
            self._fn_sqlite3_commit_hook = self.lib.get_function[sqlite3_commit_hook_fn]("sqlite3_commit_hook")
            self._fn_sqlite3_rollback_hook = self.lib.get_function[sqlite3_rollback_hook_fn]("sqlite3_rollback_hook")
            self._fn_sqlite3_auto_extension = self.lib.get_function[sqlite3_auto_extension_fn]("sqlite3_auto_extension")
            self._fn_sqlite3_db_release_memory = self.lib.get_function[sqlite3_db_release_memory_fn]("sqlite3_db_release_memory")
            self._fn_sqlite3_cancel_auto_extension = self.lib.get_function[sqlite3_cancel_auto_extension_fn]("sqlite3_cancel_auto_extension")
            self._fn_sqlite3_reset_auto_extension = self.lib.get_function[sqlite3_reset_auto_extension_fn]("sqlite3_reset_auto_extension")
            self._fn_sqlite3_create_module_v2 = self.lib.get_function[sqlite3_create_module_v2_fn]("sqlite3_create_module_v2")
            self._fn_sqlite3_blob_open = self.lib.get_function[sqlite3_blob_open_fn]("sqlite3_blob_open")
            self._fn_sqlite3_blob_reopen = self.lib.get_function[sqlite3_blob_reopen_fn]("sqlite3_blob_reopen")
            self._fn_sqlite3_blob_close = self.lib.get_function[sqlite3_blob_close_fn]("sqlite3_blob_close")
            self._fn_sqlite3_blob_bytes = self.lib.get_function[sqlite3_blob_bytes_fn]("sqlite3_blob_bytes")
            self._fn_sqlite3_blob_read = self.lib.get_function[sqlite3_blob_read_fn]("sqlite3_blob_read")
            self._fn_sqlite3_blob_write = self.lib.get_function[sqlite3_blob_write_fn]("sqlite3_blob_write")
            self._fn_sqlite3_file_control = self.lib.get_function[sqlite3_file_control_fn]("sqlite3_file_control")
            self._fn_sqlite3_backup_init = self.lib.get_function[sqlite3_backup_init_fn]("sqlite3_backup_init")
            self._fn_sqlite3_backup_step = self.lib.get_function[sqlite3_backup_step_fn]("sqlite3_backup_step")
            self._fn_sqlite3_backup_finish = self.lib.get_function[sqlite3_backup_finish_fn]("sqlite3_backup_finish")
            self._fn_sqlite3_backup_remaining = self.lib.get_function[sqlite3_backup_remaining_fn]("sqlite3_backup_remaining")
            self._fn_sqlite3_backup_pagecount = self.lib.get_function[sqlite3_backup_pagecount_fn]("sqlite3_backup_pagecount")
            self._fn_sqlite3_unlock_notify = self.lib.get_function[sqlite3_unlock_notify_fn]("sqlite3_unlock_notify")
            self._fn_sqlite3_log = self.lib.get_function[sqlite3_log_fn]("sqlite3_log")
            self._fn_sqlite3_wal_hook = self.lib.get_function[sqlite3_wal_hook_fn]("sqlite3_wal_hook")
            self._fn_sqlite3_wal_autocheckpoint = self.lib.get_function[sqlite3_wal_autocheckpoint_fn]("sqlite3_wal_autocheckpoint")
            self._fn_sqlite3_wal_checkpoint = self.lib.get_function[sqlite3_wal_checkpoint_fn]("sqlite3_wal_checkpoint")
            self._fn_sqlite3_wal_checkpoint_v2 = self.lib.get_function[sqlite3_wal_checkpoint_v2_fn]("sqlite3_wal_checkpoint_v2")
            self._fn_sqlite3_vtab_config = self.lib.get_function[sqlite3_vtab_config_fn]("sqlite3_vtab_config")
            self._fn_sqlite3_vtab_on_conflict = self.lib.get_function[sqlite3_vtab_on_conflict_fn]("sqlite3_vtab_on_conflict")
            self._fn_sqlite3_vtab_nochange = self.lib.get_function[sqlite3_vtab_nochange_fn]("sqlite3_vtab_nochange")
            self._fn_sqlite3_vtab_collation = self.lib.get_function[sqlite3_vtab_collation_fn]("sqlite3_vtab_collation")
            self._fn_sqlite3_vtab_distinct = self.lib.get_function[sqlite3_vtab_distinct_fn]("sqlite3_vtab_distinct")
            self._fn_sqlite3_db_cacheflush = self.lib.get_function[sqlite3_db_cacheflush_fn]("sqlite3_db_cacheflush")
            self._fn_sqlite3_serialize = self.lib.get_function[sqlite3_serialize_fn]("sqlite3_serialize")
            self._fn_sqlite3_deserialize = self.lib.get_function[sqlite3_deserialize_fn]("sqlite3_deserialize")
        except e:
            os.abort(String(t"Failed to load the SQLite library: {e}"))

    def sqlite3_libversion(self) -> ImmutExternalPointer[c_char]:
        """Get the SQLite library version string.

        Returns a pointer to a string containing the version of the SQLite
        library that is running. This corresponds to the SQLITE_VERSION
        string.

        Returns:
            Pointer to a null-terminated string containing the SQLite version.
        """
        return self._fn_sqlite3_libversion()

    def sqlite3_sourceid(self) -> ImmutExternalPointer[c_char]:
        """Get the SQLite source ID.

        Returns a pointer to a string containing the date and time of
        the check-in (UTC) and a SHA1 hash of the entire source tree.

        Returns:
            Pointer to a string containing the SQLite source identifier.
        """
        return self._fn_sqlite3_sourceid()

    def sqlite3_libversion_number(self) -> c_int:
        """Get the SQLite library version number.

        Returns an integer equal to SQLITE_VERSION_NUMBER. The version
        number is in the format (X*1000000 + Y*1000 + Z) where X, Y, and Z
        are the major, minor, and release numbers respectively.

        Returns:
            The SQLite library version as an integer.
        """
        return self._fn_sqlite3_libversion_number()

    def sqlite3_threadsafe(self) -> c_int:
        """Test if the library is threadsafe.

        Returns zero if and only if SQLite was compiled with mutexing code
        omitted due to the SQLITE_THREADSAFE compile-time option being set to 0.

        Returns:
            Non-zero if SQLite is threadsafe, 0 if not threadsafe.
        """
        return self._fn_sqlite3_threadsafe()

    def sqlite3_close(self, connection: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Closing A Database Connection.

        ^The `sqlite3_close()` and `sqlite3_close_v2()` routines are destructors
        for the [sqlite3] object.
        ^Calls to `sqlite3_close()` and `sqlite3_close_v2()` return [SQLITE_OK] if
        the [sqlite3] object is successfully destroyed and all associated
        resources are deallocated.

        Ideally, applications should [sqlite3_finalize | finalize] all
        [prepared statements], [sqlite3_blob_close | close] all [BLOB handles], and
        [sqlite3_backup_finish | finish] all [sqlite3_backup] objects associated
        with the [sqlite3] object prior to attempting to close the object.
        ^If the database connection is associated with unfinalized prepared
        statements, BLOB handlers, and/or unfinished sqlite3_backup objects then
        `sqlite3_close()` will leave the database connection open and return
        [SQLITE_BUSY]. ^If `sqlite3_close_v2()` is called with unfinalized prepared
        statements, unclosed BLOB handlers, and/or unfinished sqlite3_backups,
        it returns [SQLITE_OK] regardless, but instead of deallocating the database
        connection immediately, it marks the database connection as an unusable
        "zombie" and makes arrangements to automatically deallocate the database
        connection after all prepared statements are finalized, all BLOB handles
        are closed, and all backups have finished. The `sqlite3_close_v2()` interface
        is intended for use with host languages that are garbage collected, and
        where the order in which destructors are called is arbitrary.

        ^If an [sqlite3] object is destroyed while a transaction is open,
        the transaction is automatically rolled back.

        The C parameter to [sqlite3_close(C)] and [sqlite3_close_v2(C)]
        must be either a NULL
        pointer or an [sqlite3] object pointer obtained
        from [sqlite3_open()], or
        [sqlite3_open_v2()], and not previously closed.
        ^Calling `sqlite3_close()` or `sqlite3_close_v2()` with a NULL pointer
        argument is a harmless no-op.
        """
        return self._fn_sqlite3_close(connection)

    def sqlite3_config(self, op: c_int) -> c_int:
        """Configure The SQLite Library.

        The sqlite3_config() interface is used to make global configuration
        changes to SQLite in order to tune SQLite to the specific needs of
        the application. The default configuration is recommended for most
        applications, but advanced applications may wish to fine-tune SQLite.

        The sqlite3_config() interface is not threadsafe. The application
        must ensure that no other SQLite interfaces are invoked by other
        threads while sqlite3_config() is running. Furthermore, sqlite3_config()
        may only be invoked prior to library initialization using
        sqlite3_initialize() or after shutdown by sqlite3_shutdown().

        Args:
            op: Configuration option to set (e.g., SQLITE_CONFIG_SINGLETHREAD).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_config(op)

    def sqlite3_db_config(self, db: MutExternalPointer[sqlite3_connection], op: c_int) -> c_int:
        """Configure Database Connection Options.

        The sqlite3_db_config() interface is used to make configuration
        changes to a database connection. The interface is similar to
        sqlite3_config() except that the changes apply to a single database
        connection specified in the first argument.

        The sqlite3_db_config() interface should only be used immediately
        after creating the database connection using sqlite3_open() or its
        variants, and before the database connection is used to prepare
        and execute SQL statements.

        Args:
            db: Database connection handle.
            op: Configuration option to set (e.g., SQLITE_DBCONFIG_ENABLE_FKEY).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_db_config(db, op)

    def sqlite3_extended_result_codes(self, db: MutExternalPointer[sqlite3_connection], onoff: c_int) -> c_int:
        """Enable Or Disable Extended Result Codes.

        The sqlite3_extended_result_codes() routine enables or disables the
        extended result codes feature of SQLite. The extended result codes
        are disabled by default for historical compatibility reasons.

        When extended result codes are enabled, SQLite will return more
        specific error codes that provide additional information about
        the nature of an error. For example, instead of just returning
        SQLITE_IOERR, SQLite might return SQLITE_IOERR_READ, SQLITE_IOERR_WRITE,
        SQLITE_IOERR_FSYNC, etc.

        Args:
            db: Database connection handle.
            onoff: Enable extended codes if non-zero, disable if zero.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_extended_result_codes(db, onoff)

    def sqlite3_last_insert_rowid(self, db: MutExternalPointer[sqlite3_connection]) -> Int64:
        """Last Insert Rowid.

        Each entry in most SQLite tables has a unique 64-bit signed integer key
        called the "rowid". This function returns the rowid of the most recent
        successful INSERT into the database from the database connection shown
        in the first argument.

        Args:
            db: Database connection handle.

        Returns:
            The rowid of the most recent INSERT, or 0 if no INSERTs have been performed.
        """
        return self._fn_sqlite3_last_insert_rowid(db)

    def sqlite3_changes(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Count The Number of Rows Modified.

        This function returns the number of rows modified, inserted or deleted
        by the most recently completed INSERT, UPDATE, or DELETE statement on
        the database connection specified in the first argument.

        Args:
            db: Database connection handle.

        Returns:
            Number of rows changed by the most recent INSERT, UPDATE, or DELETE.
        """
        return self._fn_sqlite3_changes(db)

    def sqlite3_changes64(self, db: MutExternalPointer[sqlite3_connection]) -> Int64:
        """Count The Number of Rows Modified (64-bit).

        This function works the same as sqlite3_changes() except that it
        returns the count as a 64-bit signed integer. This routine can
        return accurate change counts even when more than 2 billion rows
        are modified.

        The sqlite3_changes64() function returns the number of rows modified,
        inserted or deleted by the most recently completed INSERT, UPDATE,
        or DELETE statement on the database connection specified in the
        first argument.

        Args:
            db: Database connection handle.

        Returns:
            Number of rows changed by the most recent INSERT, UPDATE, or DELETE
            as a 64-bit signed integer.
        """
        return self._fn_sqlite3_changes64(db)

    def sqlite3_total_changes(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Count The Total Number of Rows Modified.

        This function returns the total number of rows inserted, modified or
        deleted by all INSERT, UPDATE or DELETE statements completed since
        the database connection was opened, including those executed as part
        of trigger programs.

        Changes made as part of foreign key actions are not counted separately,
        nor are changes made by executing individual SQL statements within
        a trigger program.

        Args:
            db: Database connection handle.

        Returns:
            Total number of rows changed since the database connection was opened.
        """
        return self._fn_sqlite3_total_changes(db)

    def sqlite3_total_changes64(self, db: MutExternalPointer[sqlite3_connection]) -> Int64:
        """Count The Total Number of Rows Modified (64-bit).

        This function works the same as sqlite3_total_changes() except that it
        returns the count as a 64-bit signed integer. This routine can return
        accurate change counts even when more than 2 billion rows have been
        modified in total.

        This function returns the total number of rows inserted, modified or
        deleted by all INSERT, UPDATE or DELETE statements completed since
        the database connection was opened, including those executed as part
        of trigger programs.

        Args:
            db: Database connection handle.

        Returns:
            Total number of rows changed since the database connection was opened
            as a 64-bit signed integer.
        """
        return self._fn_sqlite3_total_changes64(db)

    def sqlite3_interrupt(self, db: MutExternalPointer[sqlite3_connection]):
        """Interrupt A Long-Running Query.

        This routine causes any pending database operation to abort and
        return at its earliest opportunity. This routine is typically
        called in response to a user action such as pressing "Cancel"
        or Ctrl+C where the user wants a long query operation to halt
        immediately.

        It is safe to call this routine from a thread different from the
        thread that is currently running the database operation. But it
        is not safe to call this routine with a database connection that
        is closed or might close before sqlite3_interrupt() returns.

        Args:
            db: Database connection handle.
        """
        self._fn_sqlite3_interrupt(db)

    def sqlite3_is_interrupted(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Test To See If An Interrupt Is Pending.

        This routine returns 1 if sqlite3_interrupt() has been called
        on the database connection and the interrupt is still pending,
        or 0 otherwise. This routine does not clear the interrupt flag.

        This routine is intended to be called from within SQL functions
        or virtual table methods to check whether the current SQL statement
        should be interrupted.

        Args:
            db: Database connection handle.

        Returns:
            1 if an interrupt is pending, 0 otherwise.
        """
        return self._fn_sqlite3_is_interrupted(db)

    def sqlite3_busy_handler[
        arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        callback: BusyHandlerCallbackFn,
        arg: MutOpaquePointer[arg_origin],
    ) -> c_int:
        """Register A Callback To Handle SQLITE_BUSY Errors.

        This routine sets a callback function that might be invoked with the
        user data pointer, any time a table in a database is busy. The callback
        function can sleep, or take other action, to wait for the table to become
        available. If the busy callback returns 0, then no additional attempts
        are made to access the database and SQLITE_BUSY is returned.

        Parameters:
            arg_origin: The origin of the user data pointer passed to the callback.

        Args:
            db: Database connection handle.
            callback: Function to call when a table is busy.
            arg: User data pointer passed to callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_busy_handler(db, callback, arg.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_busy_timeout(self, db: MutExternalPointer[sqlite3_connection], ms: c_int) -> c_int:
        """Set A Busy Timeout.

        This routine sets a busy handler that sleeps for a specified amount of
        time when a table is locked. The handler will sleep multiple times until
        at least "ms" milliseconds of sleeping have accumulated. After at least
        "ms" milliseconds of sleeping, the handler returns 0 which causes
        sqlite3_step() to return SQLITE_BUSY.

        Calling this routine with an argument less than or equal to zero turns
        off all busy handlers.

        Args:
            db: Database connection handle.
            ms: Maximum time to wait in milliseconds.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_busy_timeout(db, ms)

    def sqlite3_malloc64(self, size: UInt64) -> MutExternalPointer[NoneType]:
        """Memory Allocation Subsystem - 64-bit.

        This routine is like sqlite3_malloc() except that it allocates memory
        with a 64-bit size argument. This routine is intended for use with
        large allocations that may exceed the 32-bit limit.

        Args:
            size: Number of bytes to allocate.

        Returns:
            Pointer to allocated memory, or NULL if allocation fails.
        """
        return self._fn_sqlite3_malloc64(size)

    def sqlite3_free(self, ptr: MutExternalPointer[NoneType]):
        """Memory Deallocation.

        This routine releases memory previously returned by sqlite3_malloc(),
        sqlite3_malloc64(), sqlite3_realloc(), or sqlite3_realloc64().
        Passing a NULL pointer to sqlite3_free() is a harmless no-op.

        Args:
            ptr: Pointer to memory to free.
        """
        self._fn_sqlite3_free(ptr)

    def sqlite3_msize(self, ptr: MutExternalPointer[NoneType]) -> UInt64:
        """Memory Size Of Allocation.

        This routine returns the number of bytes of memory that were allocated
        by sqlite3_malloc(), sqlite3_malloc64(), sqlite3_realloc(), or
        sqlite3_realloc64(). The size returned is always at least as large
        as the requested size but may be larger.

        Args:
            ptr: Pointer to allocated memory.

        Returns:
            Size of the allocation in bytes.
        """
        return self._fn_sqlite3_msize(ptr)

    def sqlite3_set_authorizer[
        userdata_origin: MutOrigin, //,
        auth_callback: AuthCallbackFn,
    ](self, db: MutExternalPointer[sqlite3_connection], pUserData: MutOpaquePointer[userdata_origin]) -> c_int:
        """Compile-Time Authorization Callbacks.

        This routine registers an authorizer callback with a particular database
        connection. The authorizer callback is invoked as SQL statements are being
        compiled by sqlite3_prepare() or its variants. At various points during
        the compilation process, the authorizer callback is invoked to see if the
        action being coded is allowed. The authorizer callback should return
        SQLITE_OK to allow the action, SQLITE_IGNORE to cause the entire SQL
        statement to be silently ignored, or SQLITE_DENY to cause the entire
        SQL statement to fail with an error.

        Params:
            auth_callback: Authorizer callback function.

        Args:
            db: Database connection handle.
            pUserData: User data pointer passed to callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_set_authorizer(db, auth_callback, pUserData.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_trace[arg_origin: MutOrigin](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xTrace: TraceCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Deprecated SQL Trace Hook.

        This routine registers a callback function that is invoked at various
        times when an SQL statement is being run by sqlite3_step(). The callback
        is passed a UTF-8 rendering of the SQL statement text as the statement
        first begins executing. This interface is deprecated; use sqlite3_trace_v2()
        instead.

        Args:
            db: Database connection handle.
            xTrace: Trace callback function.
            pArg: User data pointer passed to callback.

        Returns:
            Previously registered user data pointer.
        """
        return self._fn_sqlite3_trace(db, xTrace, pArg.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_profile[
        arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xProfile: ProfileCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Deprecated SQL Profile Hook.

        This routine registers a callback function that is invoked as each SQL
        statement finishes. The profile callback contains the original SQL text
        and an estimate of wall-clock time of how long that statement took to run.
        This interface is deprecated; use sqlite3_trace_v2() instead.

        Args:
            db: Database connection handle.
            xProfile: Profile callback function.
            pArg: User data pointer passed to callback.

        Returns:
            Previously registered user data pointer.
        """
        return self._fn_sqlite3_profile(db, xProfile, pArg.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_trace_v2[
        ctx_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        uMask: c_uint,
        xCallback: TraceV2CallbackFn,
        pCtx: MutOpaquePointer[ctx_origin],
    ) -> c_int:
        """SQL Trace Event Callbacks.

        This interface registers a callback function that is invoked to provide
        tracing and/or profiling information about the execution of SQL statements.
        The callback can be selectively enabled for different trace event types
        using the uMask parameter. This is the preferred interface for tracing
        and profiling, superseding sqlite3_trace() and sqlite3_profile().

        Args:
            db: Database connection handle.
            uMask: Bitmask of trace event types to monitor.
            xCallback: Trace callback function.
            pCtx: User data pointer passed to callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_trace_v2(db, uMask, xCallback, pCtx.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_progress_handler[
        arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        nOps: c_int,
        xProgress: QueryProgressCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ):
        """Query Progress Callbacks.

        This routine registers a callback function that is invoked periodically
        during long running calls to sqlite3_step() for a statement on the
        database connection identified by the first argument. The progress
        callback is invoked once for every N virtual machine opcodes, where N
        is the second argument to this function. If the progress callback returns
        non-zero, the operation is interrupted.

        Args:
            db: Database connection handle.
            nOps: Invoke callback after this many virtual machine operations.
            xProgress: Progress callback function.
            pArg: User data pointer passed to callback.
        """
        self._fn_sqlite3_progress_handler(db, nOps, xProgress, pArg.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_open_v2[
        filename_origin: ImmutOrigin,
        db_origin: MutOrigin,
        vfs_origin: ImmutOrigin,
    ](
        self,
        filename: ImmutUnsafePointer[c_char, filename_origin],
        ppDb: MutUnsafePointer[MutExternalPointer[sqlite3_connection], db_origin],
        flags: c_int,
        zVfs: ImmutUnsafePointer[c_char, vfs_origin],
    ) -> c_int:
        """Open A Database Connection with specified flags and VFS.

        This routine opens a connection to an SQLite database file and returns
        a database connection object. This is the preferred method for opening
        database connections as it allows specification of behavior flags and
        a custom VFS module.

        The flags parameter controls various aspects of database connection:
        - SQLITE_OPEN_READONLY: open read-only
        - SQLITE_OPEN_READWRITE: open for reading and writing
        - SQLITE_OPEN_CREATE: create database if it doesn't exist
        - SQLITE_OPEN_URI: interpret filename as URI
        - SQLITE_OPEN_MEMORY: open as in-memory database
        - SQLITE_OPEN_NOMUTEX: disable connection mutexing
        - SQLITE_OPEN_FULLMUTEX: enable connection mutexing
        - SQLITE_OPEN_SHAREDCACHE: enable shared cache mode
        - SQLITE_OPEN_PRIVATECACHE: disable shared cache mode

        Args:
            filename: Database filename (UTF-8 encoded).
            ppDb: OUT: SQLite db handle.
            flags: Behavior control flags.
            zVfs: Name of VFS module to use (NULL for default).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_open_v2(
            filename.unsafe_origin_cast[MutExternalOrigin](),
            ppDb.unsafe_origin_cast[MutExternalOrigin](),
            flags,
            zVfs.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_errcode(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Retrieve the most recent error code for a database connection.

        This function returns the numeric result code or extended result code
        for the most recent failed SQLite call associated with a database connection.
        If a prior API call failed but the most recent API call succeeded, this
        function returns SQLITE_OK.

        Args:
            db: Database connection handle.

        Returns:
            Most recent error code (SQLITE_OK if no error).
        """
        return self._fn_sqlite3_errcode(db)

    def sqlite3_extended_errcode(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Retrieve the most recent extended error code for a database connection.

        This function returns the extended result code for the most recent
        failed SQLite call associated with a database connection. Extended
        result codes provide additional information about error conditions
        beyond the basic result codes.

        Args:
            db: Database connection handle.

        Returns:
            Most recent extended error code.
        """
        return self._fn_sqlite3_extended_errcode(db)

    def sqlite3_errmsg(self, db: MutExternalPointer[sqlite3_connection]) -> ImmutExternalPointer[c_char]:
        """Retrieve the English-language error message for the most recent error.

        This function returns a pointer to a UTF-8 encoded error message
        describing the most recent failed SQLite call associated with a
        database connection. The error string persists until the next
        SQLite call, at which point it may be overwritten.

        Args:
            db: Database connection handle.

        Returns:
            Pointer to UTF-8 encoded error message string.
        """
        return self._fn_sqlite3_errmsg(db)

    def sqlite3_errstr(self, e: c_int) -> ImmutExternalPointer[c_char]:
        """Retrieve the English-language text for a result code.

        This function returns a pointer to a UTF-8 encoded string that
        describes the result code value passed in the argument. Unlike
        sqlite3_errmsg(), this function returns a generic description
        of the error code rather than information about a specific error
        that occurred in a database connection.

        Args:
            e: Result code value.

        Returns:
            Pointer to UTF-8 encoded descriptive text for the result code.
        """
        return self._fn_sqlite3_errstr(e)

    def sqlite3_error_offset(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Get byte offset of SQL error.

        This function returns the byte offset into the SQL text of the most
        recent SQL statement that resulted in an error. The byte offset is
        measured from the beginning of the SQL statement and is zero-based.
        If there is no error, or if the error is not associated with a
        particular offset in the SQL text, this function returns -1.

        Args:
            db: Database connection handle.

        Returns:
            Byte offset of error in SQL text, or -1 if not applicable.
        """
        return self._fn_sqlite3_error_offset(db)

    def sqlite3_limit(self, db: MutExternalPointer[sqlite3_connection], id: c_int, newVal: c_int) -> c_int:
        """Set or retrieve run-time limits on database connection.

        This function allows applications to impose limits on various
        operations that can consume significant memory, time, or other
        resources. It can both set new limits and query current limits.

        Common limit categories include:
        - SQLITE_LIMIT_LENGTH: maximum length of strings or BLOB
        - SQLITE_LIMIT_SQL_LENGTH: maximum length of SQL statements
        - SQLITE_LIMIT_COLUMN: maximum number of columns in a table
        - SQLITE_LIMIT_EXPR_DEPTH: maximum depth of expression tree
        - SQLITE_LIMIT_COMPOUND_SELECT: maximum terms in compound SELECT
        - SQLITE_LIMIT_VDBE_OP: maximum number of VDBE opcodes
        - SQLITE_LIMIT_FUNCTION_ARG: maximum number of function arguments
        - SQLITE_LIMIT_ATTACHED: maximum number of attached databases
        - SQLITE_LIMIT_LIKE_PATTERN_LENGTH: maximum length of LIKE pattern
        - SQLITE_LIMIT_VARIABLE_NUMBER: maximum parameter index
        - SQLITE_LIMIT_TRIGGER_DEPTH: maximum trigger recursion depth
        - SQLITE_LIMIT_WORKER_THREADS: maximum number of worker threads

        Args:
            db: Database connection handle.
            id: Limit category identifier.
            newVal: New limit value (-1 to query current value without changing).

        Returns:
            Previous limit value.
        """
        return self._fn_sqlite3_limit(db, id, newVal)

    def sqlite3_prepare_v2[
        sql_origin: ImmutOrigin, stmt_origin: MutOrigin, tail_origin1: ImmutOrigin, tail_origin2: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSql: ImmutUnsafePointer[c_char, sql_origin],
        nByte: c_int,
        ppStmt: MutUnsafePointer[MutExternalPointer[sqlite3_stmt], stmt_origin],
        pzTail: MutUnsafePointer[ImmutUnsafePointer[c_char, tail_origin1], tail_origin2],
    ) -> c_int:
        """Compile an SQL statement into a prepared statement object (Version 2).

        This function compiles SQL text into a prepared statement object that
        can be executed using sqlite3_step() and other prepared statement APIs.
        This is the recommended version for most applications, as it provides
        better error handling and performance compared to the original
        sqlite3_prepare() function.

        Args:
            db: Database connection handle.
            zSql: UTF-8 encoded SQL statement text.
            nByte: Maximum length of zSql in bytes (or -1 for null-terminated).
            ppStmt: OUT: Compiled prepared statement object.
            pzTail: OUT: Pointer to unused portion of zSql (or NULL).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # var temp_tail = pzTail[].unsafe_origin_cast[ImmutExternalOrigin]()
        # return self._fn_sqlite3_prepare_v2(
        #     db,
        #     zSql.unsafe_origin_cast[MutExternalOrigin](),
        #     nByte,
        #     ppStmt.unsafe_origin_cast[MutExternalOrigin](),
        #     UnsafePointer(to=temp_tail).unsafe_origin_cast[MutExternalOrigin]()
        # )
        return self.lib.get_function[
            def(
                type_of(db),
                type_of(zSql),
                type_of(nByte),
                type_of(ppStmt),
                type_of(pzTail),
            ) abi("C") thin -> c_int
        ]("sqlite3_prepare_v2")(db, zSql, nByte, ppStmt, pzTail)

    def sqlite3_prepare_v3[
        sql_origin: ImmutOrigin, stmt_origin: MutOrigin, tail_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSql: ImmutUnsafePointer[c_char, sql_origin],
        nByte: c_int,
        prepFlags: c_uint,
        ppStmt: MutUnsafePointer[MutExternalPointer[sqlite3_stmt], stmt_origin],
        pzTail: MutUnsafePointer[ImmutUnsafePointer[c_char, sql_origin], tail_origin],
    ) -> c_int:
        """Compile an SQL statement into a prepared statement object (Version 3).

        This function is similar to sqlite3_prepare_v2() but adds a prepFlags
        parameter that provides additional control over the prepared statement.
        Flags can be used to enable or disable certain optimizations or behaviors.

        Common flags include:
        - SQLITE_PREPARE_PERSISTENT: Prepared statement is likely to be retained
          for a long time and should be optimized accordingly.
        - SQLITE_PREPARE_NORMALIZE: Return normalized SQL text.
        - SQLITE_PREPARE_NO_VTAB: Do not invoke virtual table xConnect methods.

        Args:
            db: Database connection handle.
            zSql: UTF-8 encoded SQL statement text.
            nByte: Maximum length of zSql in bytes (or -1 for null-terminated).
            prepFlags: Flags controlling statement preparation.
            ppStmt: OUT: Compiled prepared statement object.
            pzTail: OUT: Pointer to unused portion of zSql (or NULL).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # var temp_tail = pzTail[].unsafe_origin_cast[ImmutExternalOrigin]()
        # return self._fn_sqlite3_prepare_v3(
        #     db,
        #     zSql.unsafe_origin_cast[MutExternalOrigin](),
        #     nByte,
        #     prepFlags,
        #     ppStmt.unsafe_origin_cast[MutExternalOrigin](),
        #     UnsafePointer(to=temp_tail).unsafe_origin_cast[MutExternalOrigin]()
        #     # pzTail.unsafe_origin_cast[MutExternalOrigin]()
        # )
        return self.lib.get_function[
            def(
                type_of(db),
                type_of(zSql),
                type_of(nByte),
                type_of(prepFlags),
                type_of(ppStmt),
                type_of(pzTail),
            ) abi("C") thin -> c_int
        ]("sqlite3_prepare_v3")(db, zSql, nByte, prepFlags, ppStmt, pzTail)

    def sqlite3_sql(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> ImmutExternalPointer[c_char]:
        """Retrieve the SQL text of a prepared statement.

        Returns a pointer to a copy of the UTF-8 SQL text used to create the
        prepared statement if that statement was compiled using sqlite3_prepare_v2()
        or its variants.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Pointer to the SQL text used to create the statement.
        """
        return self._fn_sqlite3_sql(pStmt)

    def sqlite3_expanded_sql(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> MutExternalPointer[c_char]:
        """Retrieve SQL with bound parameters expanded.

        Returns a pointer to a UTF-8 string containing the SQL text of the
        prepared statement with bound parameters expanded inline. This is useful
        for debugging and logging purposes.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Pointer to the expanded SQL text, or NULL if out of memory.
        """
        return self._fn_sqlite3_expanded_sql(pStmt)

    def sqlite3_stmt_readonly(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Determine if a prepared statement is read-only.

        Returns true (non-zero) if and only if the prepared statement makes
        no direct changes to the content of the database file. Note that
        application-defined SQL functions or virtual tables might change
        the database indirectly as a side effect.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Non-zero if the statement is read-only, zero if it writes.
        """
        return self._fn_sqlite3_stmt_readonly(pStmt)

    def sqlite3_stmt_isexplain(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Query The EXPLAIN Setting For A Prepared Statement.

        This routine returns 0 if the prepared statement is a normal statement,
        1 if it is an EXPLAIN statement, or 2 if it is an EXPLAIN QUERY PLAN
        statement. This information can be useful for logging and debugging purposes.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            0 for normal statement, 1 for EXPLAIN, 2 for EXPLAIN QUERY PLAN.
        """
        return self._fn_sqlite3_stmt_isexplain(pStmt)

    def sqlite3_stmt_busy(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Determine If A Prepared Statement Has Been Reset.

        This interface returns true (non-zero) if the prepared statement has
        been stepped at least once using sqlite3_step() but has neither run
        to completion (returned SQLITE_DONE from sqlite3_step()) nor been
        reset using sqlite3_reset(). Returns false (zero) otherwise.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Non-zero if the statement is busy, zero otherwise.
        """
        return self._fn_sqlite3_stmt_busy(pStmt)

    def sqlite3_bind_blob64[
        value_origin: ImmutOrigin, //
    ](
        self,
        pStmt: MutExternalPointer[sqlite3_stmt],
        idx: c_int,
        value: ImmutOpaquePointer[value_origin],
        n: UInt64,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Binding Values To Prepared Statements - BLOB (64-bit).

        This routine binds a BLOB value to a parameter in a prepared statement.
        The BLOB size is specified as a 64-bit value, allowing for very large
        BLOBs. The destructor_callback callback is invoked to dispose of the BLOB after
        SQLite is done with it.


        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: Pointer to BLOB data.
            n: Size of BLOB in bytes (64-bit).
            destructor_callback: Function to call when SQLite is done with the BLOB.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_blob64(pStmt, idx, value.unsafe_origin_cast[MutExternalOrigin](), n, destructor_callback)

    def sqlite3_bind_double(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int, value: Float64) -> c_int:
        """Binding Values To Prepared Statements - REAL.

        This routine binds a floating point value to a parameter in a prepared statement.
        The parameter is identified by its index (1-based).

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: The floating point value to bind.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_double(pStmt, idx, value)

    def sqlite3_bind_int64(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int, value: Int64) -> c_int:
        """Binding Values To Prepared Statements - INTEGER (64-bit).

        This routine binds a 64-bit signed integer value to a parameter in a
        prepared statement. The parameter is identified by its index (1-based).

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: The 64-bit integer value to bind.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_int64(pStmt, idx, value)

    def sqlite3_bind_null(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int) -> c_int:
        """Binding Values To Prepared Statements - NULL.

        This routine binds a NULL value to a parameter in a prepared statement.
        The parameter is identified by its index (1-based).

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_null(pStmt, idx)

    def sqlite3_bind_text64[
        value_origin: ImmutOrigin, //
    ](
        self,
        pStmt: MutExternalPointer[sqlite3_stmt],
        idx: c_int,
        value: ImmutUnsafePointer[c_char, value_origin],
        n: UInt64,
        encoding: c_uchar,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Binding Values To Prepared Statements - TEXT (64-bit).

        This routine binds a text value to a parameter in a prepared statement.
        The text size is specified as a 64-bit value, allowing for very large
        text strings. The encoding parameter specifies the text encoding (UTF-8
        or UTF-16). The destructor_callback callback is invoked to dispose of the text
        after SQLite is done with it.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: Pointer to text data.
            n: Length of text in bytes (64-bit).
            encoding: Text encoding (SQLITE_UTF8 or SQLITE_UTF16).
            destructor_callback: Function to call when SQLite is done with the text.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_text64(pStmt, idx, value.unsafe_origin_cast[MutExternalOrigin](), n, destructor_callback, encoding)

    def sqlite3_bind_pointer[
        value_origin: MutOrigin,
        type_origin: ImmutOrigin,
        //
    ](
        self,
        pStmt: MutExternalPointer[sqlite3_stmt],
        idx: c_int,
        value: MutOpaquePointer[value_origin],
        typeStr: ImmutUnsafePointer[c_char, type_origin],
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Binding Values To Prepared Statements - Pointer.

        This routine binds a pointer value to a parameter in a prepared statement.
        The pointer is tagged with a type string for type safety. The destructor_callback
        callback is invoked to dispose of the pointer after SQLite is done with it.
        This is useful for passing application-specific data structures through
        SQL functions.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: Pointer value to bind.
            typeStr: Type identifier string for type safety.
            destructor_callback: Function to call when SQLite is done with the pointer.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_pointer(pStmt, idx, value.unsafe_origin_cast[MutExternalOrigin](), typeStr.unsafe_origin_cast[MutExternalOrigin](), destructor_callback)

    def sqlite3_bind_zeroblob(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int, n: c_int) -> c_int:
        """Binding Values To Prepared Statements - Zeroblob.

        This routine binds a BLOB filled with zeros to a parameter in a prepared
        statement. The BLOB can later be opened and written to using the
        incremental BLOB I/O routines. This is more efficient than binding a
        zero-filled BLOB directly.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            n: Size of the zeroblob in bytes.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_bind_zeroblob(pStmt, idx, n)

    def sqlite3_bind_parameter_count(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Return the number of parameters in a prepared statement.

        This function returns the number of SQL parameters in the prepared
        statement. SQL parameters are tokens such as "?" or ":name" or "$var"
        that are used to substitute values at runtime.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            The number of SQL parameters in the prepared statement.
        """
        return self._fn_sqlite3_bind_parameter_count(pStmt)

    def sqlite3_bind_parameter_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Name Of A Host Parameter.

        This routine returns a pointer to the name of the N-th SQL parameter
        in the prepared statement. SQL parameters of the form "?NNN" or ":AAA"
        or "@AAA" or "$AAA" have a name which is the string "?NNN" or ":AAA"
        or "@AAA" or "$AAA" respectively. Parameters of the form "?" without
        a following integer have no name and this routine returns NULL.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the parameter (1-based).

        Returns:
            Pointer to parameter name, or NULL if no name or invalid index.
        """
        return self._fn_sqlite3_bind_parameter_name(pStmt, idx)

    def sqlite3_bind_parameter_index[origin: ImmutOrigin, //](
        self, pStmt: MutExternalPointer[sqlite3_stmt], zName: ImmutUnsafePointer[c_char, origin]
    ) -> c_int:
        """Index Of A Parameter With A Given Name.

        This routine returns the index of an SQL parameter given its name.
        The index value returned is suitable for use as the second argument
        to sqlite3_bind_*(). A zero is returned if no matching parameter is found.

        Args:
            pStmt: Pointer to the prepared statement.
            zName: Name of the parameter to find.

        Returns:
            Index of the parameter (1-based), or 0 if not found.
        """
        return self._fn_sqlite3_bind_parameter_index(pStmt, zName.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_clear_bindings(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Reset All Bindings On A Prepared Statement.

        Contrary to the intuition of many, sqlite3_reset() does not reset
        the bindings on a prepared statement. This routine resets all
        parameters to NULL.

        Args:
            pStmt: Prepared statement.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_clear_bindings(pStmt)

    def sqlite3_column_count(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Return the number of columns in a result set.

        This function returns the number of columns in the result set returned
        by the prepared statement. This value does not change from one execution
        of the prepared statement to the next.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            The number of columns in the result set.
        """
        return self._fn_sqlite3_column_count(pStmt)

    def sqlite3_column_name(self, pStmt: MutExternalPointer[sqlite3_stmt], N: c_int) -> ImmutExternalPointer[c_char]:
        """Column Names In A Result Set.

        This routine returns the name assigned to a particular column in the
        result set of a SELECT statement. The name of a column is either the
        value assigned by the "AS" clause, or the name of the column in the
        table if no AS clause is used.

        Args:
            pStmt: Pointer to the prepared statement.
            N: Index of the column (0-based).

        Returns:
            Pointer to the column name.
        """
        return self._fn_sqlite3_column_name(pStmt, N)

    def sqlite3_column_database_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Source Of Data In A Query Result.

        This routine returns the name of the database that is the origin of a
        particular result column in a SELECT statement. This routine requires
        that SQLite be compiled with the SQLITE_ENABLE_COLUMN_METADATA
        preprocessor symbol.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the database name.
        """
        return self._fn_sqlite3_column_database_name(pStmt, idx)

    def sqlite3_column_table_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Source Of Data In A Query Result.

        This routine returns the name of the table that is the origin of a
        particular result column in a SELECT statement. This routine requires
        that SQLite be compiled with the SQLITE_ENABLE_COLUMN_METADATA
        preprocessor symbol.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the table name.
        """
        return self._fn_sqlite3_column_table_name(pStmt, idx)

    def sqlite3_column_origin_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Source Of Data In A Query Result.

        This routine returns the name of the table column that is the origin
        of a particular result column in a SELECT statement. This routine
        requires that SQLite be compiled with the SQLITE_ENABLE_COLUMN_METADATA
        preprocessor symbol.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the origin column name.
        """
        return self._fn_sqlite3_column_origin_name(pStmt, idx)

    def sqlite3_column_decltype(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Declared Datatype Of A Query Result.

        This routine returns the declared datatype of a result column. The
        returned string is UTF-8 encoded and is the datatype declaration as
        it appears in the CREATE TABLE statement. For example, in the database
        schema "CREATE TABLE t1(c1 VARIANT)", the declared type of column c1
        is "VARIANT".

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the declared datatype string.
        """
        return self._fn_sqlite3_column_decltype(pStmt, idx)

    def sqlite3_step(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Execute a prepared statement.

        This function is used to evaluate a prepared statement that has been
        previously prepared with sqlite3_prepare_v2() or one of its variants.

        The statement is executed until a row of data is ready, a call to
        sqlite3_finalize() is made, or an error occurs. When a row is ready,
        this function returns SQLITE_ROW. When the statement has been completely
        executed or an error occurs, it returns SQLITE_DONE or an error code.

        Args:
            pStmt: Pointer to the prepared statement to execute.

        Returns:
            SQLITE_ROW if a row is ready, SQLITE_DONE if execution is complete,
            or an error code if an error occurred.
        """
        return self._fn_sqlite3_step(pStmt)

    def sqlite3_column_blob(
        self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int
    ) -> ImmutExternalPointer[NoneType]:
        """Result Values From A Query - BLOB.

        These routines return information about a single column of the current
        result row of a query. This routine returns the value of the specified
        column as a BLOB (Binary Large OBject).

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Pointer to the BLOB data, or NULL if the column is NULL.
        """
        return self._fn_sqlite3_column_blob(pStmt, iCol)

    def sqlite3_column_double(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> Float64:
        """Result Values From A Query - REAL.

        This routine returns the value of the specified column as a floating
        point number (double precision). If the column contains a NULL value
        or cannot be converted to a floating point number, it returns 0.0.

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            The column value as a double precision floating point number.
        """
        return self._fn_sqlite3_column_double(pStmt, iCol)

    def sqlite3_column_int64(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> Int64:
        """Result Values From A Query - INTEGER (64-bit).

        This routine returns the value of the specified column as a 64-bit
        signed integer. If the column contains a NULL value or cannot be
        converted to an integer, it returns 0.

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            The column value as a 64-bit signed integer.
        """
        return self._fn_sqlite3_column_int64(pStmt, iCol)

    def sqlite3_column_text(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> ImmutExternalPointer[c_uchar]:
        """Retrieve column data as UTF-8 text.

        This function returns the value of the specified column as a UTF-8
        encoded string. The column is specified by its index (0-based) in
        the result set.

        Args:
            pStmt: Pointer to the prepared statement.
            iCol: Index of the column (0-based).

        Returns:
            Pointer to the UTF-8 encoded text value of the column.
        """
        return self._fn_sqlite3_column_text(pStmt, iCol)

    def sqlite3_column_value(
        self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int
    ) -> MutExternalPointer[sqlite3_value]:
        """Result Values From A Query - Unprotected sqlite3_value.

        This routine returns the sqlite3_value object for the specified column.
        The returned value is unprotected, meaning it is only valid until the
        next call to sqlite3_step() or sqlite3_reset(). Use sqlite3_value_*()
        functions to extract information from the returned value.

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Pointer to the sqlite3_value object for the column.
        """
        return self._fn_sqlite3_column_value(pStmt, iCol)

    def sqlite3_column_bytes(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> c_int:
        """Size Of A BLOB Or TEXT Result In Bytes.

        This routine returns the number of bytes in a BLOB or TEXT result.
        For BLOBs, this is the exact size. For TEXT, this is the number of
        bytes in the UTF-8 encoding. This routine must be called after
        sqlite3_column_blob() or sqlite3_column_text().

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Number of bytes in the BLOB or TEXT value.
        """
        return self._fn_sqlite3_column_bytes(pStmt, iCol)

    def sqlite3_column_type(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> c_int:
        """Datatype Code For The Initial Data Type Of A Result Column.

        This routine returns one of SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT,
        SQLITE_BLOB, or SQLITE_NULL, indicating the datatype of the result
        column. The return value is only meaningful if no automatic type
        conversions have been performed.

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Datatype code (SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, or SQLITE_NULL).
        """
        return self._fn_sqlite3_column_type(pStmt, iCol)

    def sqlite3_finalize(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Finalize a prepared statement.

        This function is used to delete a prepared statement. If the most recent
        evaluation of the statement was successful, then sqlite3_finalize() returns
        SQLITE_OK. If the most recent evaluation failed, then sqlite3_finalize()
        returns the appropriate error code.

        Args:
            pStmt: Pointer to the prepared statement to finalize.

        Returns:
            SQLITE_OK on success, or an error code if the statement failed.
        """
        return self._fn_sqlite3_finalize(pStmt)

    def sqlite3_reset(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Reset a prepared statement.

        This function resets a prepared statement back to its initial state,
        ready to be re-executed. Any SQL statement variables that had values
        bound to them using the sqlite3_bind_*() functions retain their values.
        Use sqlite3_clear_bindings() to reset the bindings.

        Args:
            pStmt: Pointer to the prepared statement to reset.

        Returns:
            SQLITE_OK on success, or an error code if an error occurred during
            the most recent evaluation of the statement.
        """
        return self._fn_sqlite3_reset(pStmt)

    def sqlite3_remove_function[
        fn_name_origin: ImmutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var eTextRep = c_int(0)
        var pApp = UnsafePointer[NoneType, origin=MutAnyOrigin]()
        var xFunc = UnsafePointer[ScalarFnCallback, origin=MutAnyOrigin]()
        var xStep = UnsafePointer[AggStepCallback, origin=MutAnyOrigin]()
        var xFinal = UnsafePointer[AggFinalCallback, origin=MutAnyOrigin]()
        var xDestroy = UnsafePointer[ResultDestructorFn, origin=MutAnyOrigin]()
        return self._fn_sqlite3_remove_function(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp.unsafe_origin_cast[MutExternalOrigin](),
            xFunc.unsafe_origin_cast[MutExternalOrigin](),
            xStep.unsafe_origin_cast[MutExternalOrigin](),
            xFinal.unsafe_origin_cast[MutExternalOrigin](),
            xDestroy.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_create_scalar_function[
        fn_name_origin: ImmutOrigin,
        app_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xFunc: ScalarFnCallback,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            pApp: User data pointer passed to function callbacks.
            xFunc: Scalar function implementation (NULL for aggregates).
            destructor_callback: Destructor for pApp when function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var xStep = UnsafePointer[AggStepCallback, origin=MutAnyOrigin]()
        var xFinal = UnsafePointer[AggFinalCallback, origin=MutAnyOrigin]()
        return self._fn_sqlite3_create_scalar_function(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp.unsafe_origin_cast[MutExternalOrigin](),
            xFunc,
            xStep.unsafe_origin_cast[MutExternalOrigin](),
            xFinal.unsafe_origin_cast[MutExternalOrigin](),
            destructor_callback
        )

    def sqlite3_create_scalar_function[
        fn_name_origin: ImmutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        xFunc: ScalarFnCallback,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            xFunc: Scalar function implementation (NULL for aggregates).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var pApp = UnsafePointer[NoneType, origin=MutAnyOrigin]()
        var xStep = UnsafePointer[AggStepCallback, origin=MutAnyOrigin]()
        var xFinal = UnsafePointer[AggFinalCallback, origin=MutAnyOrigin]()
        var xDestroy = UnsafePointer[ResultDestructorFn, origin=MutAnyOrigin]()
        return self._fn_sqlite3_create_scalar_function_no_data(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp.unsafe_origin_cast[MutExternalOrigin](),
            xFunc,
            xStep.unsafe_origin_cast[MutExternalOrigin](),
            xFinal.unsafe_origin_cast[MutExternalOrigin](),
            xDestroy.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_create_aggregate_function[
        fn_name_origin: ImmutOrigin,
        app_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            pApp: User data pointer passed to function callbacks.
            xStep: Aggregate step function (NULL for scalar functions).
            xFinal: Aggregate finalization function (NULL for scalar functions).
            destructor_callback: Destructor for pApp when function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var xFunc = UnsafePointer[ScalarFnCallback, origin=MutAnyOrigin]()
        return self._fn_sqlite3_create_aggregate_function(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp.unsafe_origin_cast[MutExternalOrigin](),
            xFunc.unsafe_origin_cast[MutExternalOrigin](),
            xStep,
            xFinal,
            destructor_callback
        )

    def sqlite3_create_aggregate_function[
        fn_name_origin: ImmutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            xStep: Aggregate step function (NULL for scalar functions).
            xFinal: Aggregate finalization function (NULL for scalar functions).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var pApp = UnsafePointer[NoneType, origin=MutAnyOrigin]()
        var xFunc = UnsafePointer[ScalarFnCallback, origin=MutAnyOrigin]()
        var xDestroy = UnsafePointer[ResultDestructorFn, origin=MutAnyOrigin]()
        return self._fn_sqlite3_create_aggregate_function_no_data(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp.unsafe_origin_cast[MutExternalOrigin](),
            xFunc.unsafe_origin_cast[MutExternalOrigin](),
            xStep,
            xFinal,
            xDestroy.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_create_window_function[
        fn_name_origin: ImmutOrigin,
        app_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
        xValue: WindowValueCallback,
        xInverse: WindowInverseCallback,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            pApp: User data pointer passed to function callbacks.
            xStep: Aggregate step function (NULL for scalar functions).
            xFinal: Aggregate finalization function (NULL for scalar functions).
            xValue: Window function value callback.
            xInverse: Window function inverse callback.
            destructor_callback: Destructor for pApp when function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_create_window_function(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp.unsafe_origin_cast[MutExternalOrigin](),
            xStep,
            xFinal,
            xValue,
            xInverse,
            destructor_callback
        )

    def sqlite3_create_window_function[
        fn_name_origin: ImmutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmutUnsafePointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
        xValue: WindowValueCallback,
        xInverse: WindowInverseCallback,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        For scalar functions, only xFunc should be non-NULL. For aggregate
        functions, xStep and xFinal should be non-NULL and xFunc should be NULL.
        The destructor_callback callback is invoked when the function is deleted, typically
        when the database connection is closed.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            xStep: Aggregate step function (NULL for scalar functions).
            xFinal: Aggregate finalization function (NULL for scalar functions).
            xValue: Window function value callback.
            xInverse: Window function inverse callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var pApp = UnsafePointer[NoneType, origin=MutExternalOrigin]()
        var xDestroy = UnsafePointer[ResultDestructorFn, origin=MutExternalOrigin]()
        return self._fn_sqlite3_create_window_function_no_data(
            db,
            zFunctionName.unsafe_origin_cast[MutExternalOrigin](),
            nArg,
            eTextRep,
            pApp,
            xStep,
            xFinal,
            xValue,
            xInverse,
            xDestroy
        )

    def sqlite3_aggregate_count(self, ctx: MutExternalPointer[sqlite3_context]) -> c_int:
        """Number Of Rows In An Aggregate Context (Deprecated).

        This function returns the number of times that the step function of
        an aggregate has been called. This function is deprecated and may
        be removed in a future release of SQLite.

        Args:
            ctx: SQL function context.

        Returns:
            Number of times the aggregate step function has been called.
        """
        return self._fn_sqlite3_aggregate_count(ctx)

    def sqlite3_expired(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Determine If A Prepared Statement Is Expired (Deprecated).

        This function was used to determine if a prepared statement had been
        expired and needed to be reprepared. It is deprecated and always
        returns 0.

        Args:
            pStmt: Prepared statement handle.

        Returns:
            Always returns 0.
        """
        return self._fn_sqlite3_expired(pStmt)

    def sqlite3_transfer_bindings(
        self, fromStmt: MutExternalPointer[sqlite3_stmt], toStmt: MutExternalPointer[sqlite3_stmt]
    ) -> c_int:
        """Transfer Bindings From One Statement To Another (Deprecated).

        This function was used to transfer bindings from one prepared statement
        to another. It is deprecated and may be removed in a future release.

        Args:
            fromStmt: Source statement handle.
            toStmt: Destination statement handle.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_transfer_bindings(fromStmt, toStmt)

    def sqlite3_global_recover(self) -> c_int:
        """Attempt To Free Heap Memory (Deprecated).

        This function was used to attempt to recover from allocation failures.
        It is deprecated and may be removed in a future release. It always
        returns SQLITE_OK and does nothing.

        Returns:
            Always returns SQLITE_OK.
        """
        return self._fn_sqlite3_global_recover()

    def sqlite3_thread_cleanup(self):
        """Clean Up Thread-Local Storage (Deprecated).

        This function was used to clean up thread-local storage for SQLite.
        It is deprecated and does nothing in modern versions of SQLite.
        """
        self._fn_sqlite3_thread_cleanup()

    def sqlite3_memory_alarm[
        origin: MutOrigin, //
    ](
        self,
        callback: MemoryAlarmCallbackFn,
        arg: MutUnsafePointer[NoneType, origin],
        n: Int64,
    ) -> c_int:
        """Register A Callback For Memory Allocation Events (Deprecated).

        This function was used to register a callback that would be invoked
        when memory usage exceeded a threshold. It is deprecated and may be
        removed in a future release.

        Args:
            callback: Callback function to invoke.
            arg: User data pointer passed to callback.
            n: Memory threshold in bytes.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_memory_alarm(callback, arg.unsafe_origin_cast[MutExternalOrigin](), n)

    def sqlite3_value_blob(self, value: MutExternalPointer[sqlite3_value]) -> ImmutExternalPointer[NoneType]:
        """Obtaining SQL Values - BLOB.

        This routine extracts a BLOB value from an sqlite3_value object.
        These routines are used to extract type, size, and content information
        from sqlite3_value objects that are passed as parameters to
        application-defined SQL functions.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Pointer to the BLOB data.
        """
        return self._fn_sqlite3_value_blob(value)

    def sqlite3_value_double(self, value: MutExternalPointer[sqlite3_value]) -> Float64:
        """Obtaining SQL Values - REAL.

        This routine extracts a floating point value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a double precision floating point number.
        """
        return self._fn_sqlite3_value_double(value)

    def sqlite3_value_int64(self, value: MutExternalPointer[sqlite3_value]) -> Int64:
        """Obtaining SQL Values - INTEGER (64-bit).

        This routine extracts a 64-bit signed integer value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a 64-bit signed integer.
        """
        return self._fn_sqlite3_value_int64(value)

    def sqlite3_value_pointer[
        origin: ImmutOrigin, //
    ](
        self, value: MutExternalPointer[sqlite3_value], typeStr: ImmutUnsafePointer[c_char, origin]
    ) -> MutExternalPointer[NoneType]:
        """Obtaining SQL Values - Pointer.

        This routine extracts a pointer value from an sqlite3_value object.
        The pointer is type-checked using the provided type string. Returns
        NULL if the value is not a pointer or if the type string doesn't match.

        Args:
            value: Pointer to the sqlite3_value object.
            typeStr: Type identifier string for type safety.

        Returns:
            The pointer value, or NULL if not a matching pointer type.
        """
        return self._fn_sqlite3_value_pointer(value, typeStr.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_value_text(self, value: MutExternalPointer[sqlite3_value]) -> ImmutExternalPointer[c_uchar]:
        """Obtaining SQL Values - TEXT.

        This routine extracts a UTF-8 text value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Pointer to the UTF-8 encoded text.
        """
        return self._fn_sqlite3_value_text(value)

    def sqlite3_value_bytes(self, value: MutExternalPointer[sqlite3_value]) -> c_int:
        """Size Of A BLOB Or TEXT Value In Bytes.

        This routine returns the number of bytes in a BLOB or TEXT value.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Number of bytes in the value.
        """
        return self._fn_sqlite3_value_bytes(value)

    def sqlite3_value_type(self, value: MutExternalPointer[sqlite3_value]) -> c_int:
        """Datatype Code For An sqlite3_value.

        This routine returns one of SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT,
        SQLITE_BLOB, or SQLITE_NULL, indicating the datatype of the value.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Datatype code.
        """
        return self._fn_sqlite3_value_type(value)

    def sqlite3_value_nochange(self, value: MutExternalPointer[sqlite3_value]) -> c_int:
        """Detect Unchanged Columns In An UPDATE.

        This routine returns true if and only if the column corresponding to
        the sqlite3_value is unchanged in an UPDATE operation. This is used
        within update hooks to determine which columns were actually modified.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Non-zero if the column is unchanged, zero otherwise.
        """
        return self._fn_sqlite3_value_nochange(value)

    def sqlite3_value_subtype(self, value: MutExternalPointer[sqlite3_value]) -> c_uint:
        """Finding The Subtype Of SQL Values.

        This routine returns the subtype for an application-defined SQL function
        argument. The subtype information can be used to pass a limited amount
        of context from one SQL function to another.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The subtype value, or 0 if no subtype is set.
        """
        return self._fn_sqlite3_value_subtype(value)

    def sqlite3_aggregate_context(
        self, ctx: MutExternalPointer[sqlite3_context], nBytes: c_int
    ) -> MutExternalPointer[NoneType]:
        """Aggregate Function Context.

        This routine returns a pointer to memory that is unique to the aggregate
        SQL function currently being executed. On the first call, SQLite allocates
        nBytes of memory, zeroes it out, and returns a pointer to it. On subsequent
        calls, the same pointer is returned. This memory is automatically freed
        when the aggregate function finishes.

        This routine is used by aggregate functions to maintain state information
        across multiple invocations of the step function.

        Args:
            ctx: SQL function context pointer.
            nBytes: Number of bytes of memory to allocate on first call.

        Returns:
            Pointer to aggregate context memory.
        """
        return self._fn_sqlite3_aggregate_context(ctx, nBytes)

    def sqlite3_user_data(self, ctx: MutExternalPointer[sqlite3_context]) -> MutExternalPointer[NoneType]:
        """User Data For Functions.

        This routine returns a copy of the pointer that was the pUserData parameter
        (the 5th parameter) of the sqlite3_create_function() or
        sqlite3_create_function16() routine that originally registered the
        application defined function.

        This routine can be used to retrieve user-specific data that was passed
        when the SQL function was created.

        Args:
            ctx: SQL function context pointer.

        Returns:
            User data pointer that was passed during function creation.
        """
        return self._fn_sqlite3_user_data(ctx)

    def sqlite3_context_db_handle(
        self, ctx: MutExternalPointer[sqlite3_context]
    ) -> MutExternalPointer[sqlite3_connection]:
        """Database Connection For Functions.

        This routine returns a copy of the pointer to the database connection
        (the 1st parameter) of the sqlite3_create_function() or
        sqlite3_create_function16() routine that originally registered the
        application defined function.

        Args:
            ctx: SQL function context pointer.

        Returns:
            Database connection handle.
        """
        return self._fn_sqlite3_context_db_handle(ctx)

    def sqlite3_get_auxdata(self, ctx: MutExternalPointer[sqlite3_context], N: c_int) -> MutExternalPointer[NoneType]:
        """Function Auxiliary Data.

        This routine returns a pointer to metadata that was previously saved
        by sqlite3_set_auxdata() for the N-th argument of the function. If no
        metadata has been set for that argument, this routine returns NULL.

        Auxiliary data is useful for caching information between multiple
        invocations of the same SQL function within a single statement.

        Args:
            ctx: SQL function context pointer.
            N: Argument index (0-based).

        Returns:
            Auxiliary data pointer, or NULL if none was set.
        """
        return self._fn_sqlite3_get_auxdata(ctx, N)

    def sqlite3_set_auxdata[
        data_origin: MutOrigin, //
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        N: c_int,
        data: MutOpaquePointer[data_origin],
        destructor_callback: ResultDestructorFn,
    ):
        """Function Auxiliary Data.

        This routine saves metadata (auxiliary data) for the N-th argument of
        the SQL function. The metadata can be retrieved later using
        sqlite3_get_auxdata(). The destructor_callback callback is invoked when the
        metadata is no longer needed.

        This is useful for caching expensive computations or parsed data
        structures that can be reused across multiple function calls.

        Args:
            ctx: SQL function context pointer.
            N: Argument index (0-based).
            data: Pointer to auxiliary data to save.
            destructor_callback: Function to call when data should be freed.
        """
        self._fn_sqlite3_set_auxdata(ctx, N, data.unsafe_origin_cast[MutExternalOrigin](), destructor_callback)

    def sqlite3_result_blob64[
        origin: ImmutOrigin, //
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        value: ImmutOpaquePointer[origin],
        n: UInt64,
        destructor_callback: ResultDestructorFn,
    ):
        """Setting The Result Of An SQL Function - BLOB (64-bit).

        This routine sets the result of an application-defined SQL function to
        be a BLOB value. The size is specified as a 64-bit value, allowing for
        very large BLOBs. The destructor_callback callback is invoked to dispose of the
        BLOB after SQLite is done with it.

        Args:
            ctx: SQL function context pointer.
            value: Pointer to BLOB data.
            n: Size of BLOB in bytes (64-bit).
            destructor_callback: Function to call when SQLite is done with the BLOB.
        """
        self._fn_sqlite3_result_blob64(ctx, value.unsafe_origin_cast[MutExternalOrigin](), n, destructor_callback)

    def sqlite3_result_double(self, ctx: MutExternalPointer[sqlite3_context], value: Float64):
        """Setting The Result Of An SQL Function - REAL.

        This routine sets the result of an application-defined SQL function to
        be a floating point value.

        Args:
            ctx: SQL function context pointer.
            value: The floating point value to return.
        """
        self._fn_sqlite3_result_double(ctx, value)

    def sqlite3_result_error[
        origin: ImmutOrigin, //
    ](self, ctx: MutExternalPointer[sqlite3_context], msg: ImmutUnsafePointer[c_char, origin], n: c_int):
        """Setting The Result Of An SQL Function - Error.

        This routine causes the SQL function to terminate with an error. The
        error message is copied into memory obtained from sqlite3_malloc() so
        the original error message string can be deallocated after this routine
        returns.

        Args:
            ctx: SQL function context pointer.
            msg: Error message text (UTF-8).
            n: Length of error message in bytes, or -1 for null-terminated.
        """
        self._fn_sqlite3_result_error(ctx, msg.unsafe_origin_cast[MutExternalOrigin](), n)

    def sqlite3_result_error_toobig(self, ctx: MutExternalPointer[sqlite3_context]):
        """Setting The Result Of An SQL Function - SQLITE_TOOBIG Error.

        This routine causes the SQL function to terminate with the error code
        SQLITE_TOOBIG, indicating that a string or BLOB is too large.

        Args:
            ctx: SQL function context pointer.
        """
        self._fn_sqlite3_result_error_toobig(ctx)

    def sqlite3_result_error_nomem(self, ctx: MutExternalPointer[sqlite3_context]):
        """Setting The Result Of An SQL Function - SQLITE_NOMEM Error.

        This routine causes the SQL function to terminate with the error code
        SQLITE_NOMEM, indicating an out-of-memory condition.

        Args:
            ctx: SQL function context pointer.
        """
        self._fn_sqlite3_result_error_nomem(ctx)

    def sqlite3_result_error_code(self, ctx: MutExternalPointer[sqlite3_context], code: c_int):
        """Setting The Result Of An SQL Function - Error Code.

        This routine changes the error code returned by the SQL function. By
        default, functions return SQLITE_ERROR, but this can be changed to any
        valid error code using this function.

        Args:
            ctx: SQL function context pointer.
            code: Error code to return (e.g., SQLITE_CONSTRAINT, SQLITE_BUSY).
        """
        self._fn_sqlite3_result_error_code(ctx, code)

    def sqlite3_result_int64(self, ctx: MutExternalPointer[sqlite3_context], value: Int64):
        """Setting The Result Of An SQL Function - INTEGER (64-bit).

        This routine sets the result of an application-defined SQL function to
        be a 64-bit signed integer value.

        Args:
            ctx: SQL function context pointer.
            value: The 64-bit integer value to return.
        """
        self._fn_sqlite3_result_int64(ctx, value)

    def sqlite3_result_null(self, ctx: MutExternalPointer[sqlite3_context]):
        """Setting The Result Of An SQL Function - NULL.

        This routine sets the result of an application-defined SQL function to
        be NULL.

        Args:
            ctx: SQL function context pointer.
        """
        self._fn_sqlite3_result_null(ctx)

    def sqlite3_result_text64[
        value_origin: ImmutOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        value: ImmutUnsafePointer[c_char, value_origin],
        n: UInt64,
        encoding: c_uchar,
        destructor_callback: ResultDestructorFn,
    ):
        """Setting The Result Of An SQL Function - TEXT (64-bit).

        This routine sets the result of an application-defined SQL function to
        be a text value. The text size is specified as a 64-bit value, allowing
        for very large text strings. The encoding parameter specifies the text
        encoding (UTF-8 or UTF-16). The destructor_callback callback is invoked to
        dispose of the text after SQLite is done with it.

        Params:
            destructor_callback: Function to call when SQLite is done with the text.

        Args:
            ctx: SQL function context pointer.
            value: Pointer to text data.
            n: Length of text in bytes (64-bit).
            encoding: Text encoding (SQLITE_UTF8 or SQLITE_UTF16).
            destructor_callback: Function to call when SQLite is done with the text.
        """
        self._fn_sqlite3_result_text64(ctx, value.unsafe_origin_cast[MutExternalOrigin](), n, destructor_callback, encoding)

    def sqlite3_result_value(
        self, ctx: MutExternalPointer[sqlite3_context], value: MutExternalPointer[sqlite3_value]
    ):
        """Setting The Result Of An SQL Function - Value Copy.

        This routine sets the result of an application-defined SQL function to
        be a copy of the value object passed as the second argument. This is
        useful for passing through values from arguments to results without
        type conversion.

        Args:
            ctx: SQL function context pointer.
            value: Value object to copy as the result.
        """
        self._fn_sqlite3_result_value(ctx, value)

    def sqlite3_result_pointer[
        ptr_origin: MutOrigin,
        type_origin: ImmutOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        ptr: MutOpaquePointer[ptr_origin],
        typeStr: ImmutUnsafePointer[c_char, type_origin],
        destructor_callback: ResultDestructorFn,
    ):
        """Setting The Result Of An SQL Function - Pointer.

        This routine sets the result of an application-defined SQL function to
        be a pointer value. The pointer is tagged with a type string for type
        safety. The destructor_callback callback is invoked to dispose of the pointer
        after SQLite is done with it.

        Args:
            ctx: SQL function context pointer.
            ptr: Pointer value to return.
            typeStr: Type identifier string for type safety.
            destructor_callback: Function to call when SQLite is done with the pointer.
        """
        self._fn_sqlite3_result_pointer(ctx, ptr.unsafe_origin_cast[MutExternalOrigin](), typeStr.unsafe_origin_cast[MutExternalOrigin](), destructor_callback)

    def sqlite3_result_zeroblob(self, ctx: MutExternalPointer[sqlite3_context], n: c_int):
        """Setting The Result Of An SQL Function - Zeroblob.

        This routine sets the result of an application-defined SQL function to
        be a BLOB filled with zeros. The BLOB can later be opened and written
        to using the incremental BLOB I/O routines.

        Args:
            ctx: SQL function context pointer.
            n: Size of the zeroblob in bytes.
        """
        self._fn_sqlite3_result_zeroblob(ctx, n)

    def sqlite3_result_subtype(self, ctx: MutExternalPointer[sqlite3_context], subtype: c_uint):
        """Setting The Subtype Of An SQL Function Result.

        This routine sets the subtype of the result value of an application-defined
        SQL function. The subtype information can be used to pass a limited amount
        of context from one SQL function to another.

        Args:
            ctx: SQL function context pointer.
            subtype: Subtype value to set (application-defined).
        """
        self._fn_sqlite3_result_subtype(ctx, subtype)

    def sqlite3_create_collation_v2[
        name_origin: ImmutOrigin,
        arg_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zName: ImmutUnsafePointer[c_char, name_origin],
        eTextRep: c_int,
        pArg: MutOpaquePointer[arg_origin],
        xCompare: CollationCompareCallbackFn,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Define New Collating Sequences.

        This routine adds, removes, or modifies a collating sequence. The
        collating sequence is named by zName and must be specified using UTF-8,
        UTF-16LE, or UTF-16BE encoding. The eTextRep parameter specifies the
        encoding and determines which strings the comparison function will receive.

        The xCompare callback performs the actual comparison. The destructor_callback callback
        is invoked when the collating sequence is deleted, allowing cleanup of
        any resources.

        Args:
            db: Database connection handle.
            zName: Name of the collating sequence.
            eTextRep: Text encoding (SQLITE_UTF8, SQLITE_UTF16LE, or SQLITE_UTF16BE).
            pArg: User data pointer passed to xCompare callback.
            xCompare: Comparison function callback.
            destructor_callback: Destructor for pArg when collation is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_create_collation_v2(
            db,
            zName.unsafe_origin_cast[MutExternalOrigin](),
            eTextRep,
            pArg.unsafe_origin_cast[MutExternalOrigin](),
            xCompare,
            destructor_callback
        )

    def sqlite3_collation_needed[
        arg_origin: MutOrigin, //,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        pArg: MutOpaquePointer[arg_origin],
        callback: CollationNeededCallbackFn,
    ) -> c_int:
        """Collation Needed Callbacks.

        This routine registers a callback function that is invoked whenever an
        unknown collating sequence is encountered. The callback can then create
        the required collating sequence using sqlite3_create_collation(). This
        allows applications to provide collating sequences on demand rather than
        pre-registering all possible collations.

        Args:
            db: Database connection handle.
            pArg: User data pointer passed to callback.
            callback: Function to call when an unknown collation is needed.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_collation_needed(db, pArg.unsafe_origin_cast[MutExternalOrigin](), callback)

    def sqlite3_soft_heap_limit(self, n: c_int) -> c_int:
        """Deprecated Soft Heap Limit.

        This routine is deprecated. Use sqlite3_soft_heap_limit64() instead.
        This routine sets a soft limit on the amount of heap memory that may
        be allocated by SQLite.

        Args:
            n: Soft heap limit in bytes.

        Returns:
            Previous soft heap limit.
        """
        return self._fn_sqlite3_soft_heap_limit(n)

    def sqlite3_soft_heap_limit64(self, n: Int64) -> Int64:
        """Impose A Limit On Heap Size.

        This routine sets and/or queries the soft limit on the amount of heap
        memory that may be allocated by SQLite. SQLite strives to keep heap
        memory below the soft limit by reducing the number of pages held in
        the page cache. If n is negative, then the soft heap limit is disabled.

        Args:
            n: New soft heap limit in bytes (-1 to disable, 0 to query only).

        Returns:
            Previous soft heap limit.
        """
        return self._fn_sqlite3_soft_heap_limit64(n)

    def sqlite3_stmt_status(self, pStmt: MutExternalPointer[sqlite3_stmt], op: c_int, resetFlg: c_int) -> c_int:
        """Prepared Statement Status.

        This routine is used to retrieve runtime status information about a
        prepared statement. The op parameter determines which status counter to
        retrieve. Common counters include:
        - SQLITE_STMTSTATUS_FULLSCAN_STEP: Number of fullscan steps
        - SQLITE_STMTSTATUS_SORT: Number of sort operations
        - SQLITE_STMTSTATUS_AUTOINDEX: Number of automatic indexes created
        - SQLITE_STMTSTATUS_VM_STEP: Number of virtual machine steps

        Args:
            pStmt: Pointer to the prepared statement.
            op: Status counter to retrieve.
            resetFlg: If non-zero, reset the counter after reading.

        Returns:
            Current value of the requested status counter.
        """
        return self._fn_sqlite3_stmt_status(pStmt, op, resetFlg)

    def sqlite3_table_column_metadata[
        db_name_origin: ImmutOrigin,
        table_name_origin: ImmutOrigin,
        column_name_origin: ImmutOrigin,
        dt_origin: ImmutOrigin,
        dt_origin2: MutOrigin,
        cs_origin: ImmutOrigin,
        cs_origin2: MutOrigin,
        null_origin: MutOrigin,
        pk_origin: MutOrigin,
        ai_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDbName: ImmutUnsafePointer[c_char, db_name_origin],
        zTableName: ImmutUnsafePointer[c_char, table_name_origin],
        zColumnName: ImmutUnsafePointer[c_char, column_name_origin],
        pzDataType: MutUnsafePointer[ImmutUnsafePointer[c_char, dt_origin], dt_origin2],
        pzCollSeq: MutUnsafePointer[ImmutUnsafePointer[c_char, cs_origin], cs_origin2],
        pNotNull: MutUnsafePointer[c_int, null_origin],
        pPrimaryKey: MutUnsafePointer[c_int, pk_origin],
        pAutoinc: MutUnsafePointer[c_int, ai_origin],
    ) -> c_int:
        """Extract Metadata About A Column Of A Table.

        This routine returns metadata about a specific column of a specific table
        in a database. The returned information includes the data type, collating
        sequence, whether the column can be NULL, whether it is part of the primary
        key, and whether it is autoincrement.

        This routine requires that SQLite be compiled with the
        SQLITE_ENABLE_COLUMN_METADATA preprocessor symbol.

        Args:
            db: Database connection handle.
            zDbName: Database name (e.g., "main", "temp").
            zTableName: Table name.
            zColumnName: Column name.
            pzDataType: OUT: Data type name.
            pzCollSeq: OUT: Collation sequence name.
            pNotNull: OUT: True if column has NOT NULL constraint.
            pPrimaryKey: OUT: True if column is part of primary key.
            pAutoinc: OUT: True if column is AUTOINCREMENT.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # return self._fn_sqlite3_table_column_metadata(
        #     db,
        #     zDbName.unsafe_origin_cast[MutExternalOrigin](),
        #     zTableName.unsafe_origin_cast[MutExternalOrigin](),
        #     zColumnName.unsafe_origin_cast[MutExternalOrigin](),
        #     pzDataType.unsafe_origin_cast[MutExternalOrigin](),
        #     pzCollSeq.unsafe_origin_cast[MutExternalOrigin](),
        #     pNotNull.unsafe_origin_cast[MutExternalOrigin](),
        #     pPrimaryKey.unsafe_origin_cast[MutExternalOrigin](),
        #     pAutoinc.unsafe_origin_cast[MutExternalOrigin]()
        # )
        return self.lib.get_function[
            def(
                type_of(db),
                type_of(zDbName),
                type_of(zTableName),
                type_of(zColumnName),
                type_of(pzDataType),
                type_of(pzCollSeq),
                type_of(pNotNull),
                type_of(pPrimaryKey),
                type_of(pAutoinc),
            ) abi("C") thin -> c_int
        ]("sqlite3_table_column_metadata")(
            db, zDbName, zTableName, zColumnName, pzDataType, pzCollSeq, pNotNull, pPrimaryKey, pAutoinc
        )

    def sqlite3_load_extension[
        file_origin: ImmutOrigin,
        proc_origin: ImmutOrigin,
        err_msg_origin: MutOrigin,
        err_msg_origin2: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFile: ImmutUnsafePointer[c_char, file_origin],
        zProc: ImmutUnsafePointer[c_char, proc_origin],
        pzErrMsg: MutUnsafePointer[MutUnsafePointer[c_char, err_msg_origin], err_msg_origin2],
    ) -> c_int:
        """Load An Extension.

        This routine attempts to load an SQLite extension library from the file
        named by zFile. If zProc is not NULL, it is the name of the entry point
        to use for loading the extension. If zProc is NULL, SQLite uses a default
        entry point name. If an error occurs, an error message is returned via
        pzErrMsg (which must be freed using sqlite3_free()).

        Extension loading must be enabled using sqlite3_enable_load_extension()
        before this function can be called.

        Args:
            db: Database connection handle.
            zFile: Path to the extension library file.
            zProc: Entry point name (NULL for default).
            pzErrMsg: OUT: Error message pointer (must be freed with sqlite3_free).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # return self._fn_sqlite3_load_extension(db, zFile.unsafe_origin_cast[MutExternalOrigin](), zProc.unsafe_origin_cast[MutExternalOrigin](), pzErrMsg.unsafe_origin_cast[MutExternalOrigin]())
        return self.lib.get_function[def(type_of(db), type_of(zFile), type_of(zProc), type_of(pzErrMsg)) abi("C") thin -> c_int](
            "sqlite3_load_extension"
        )(db, zFile, zProc, pzErrMsg)

    def sqlite3_enable_load_extension(self, db: MutExternalPointer[sqlite3_connection], onoff: c_int) -> c_int:
        """Enable Or Disable Extension Loading.

        This routine enables or disables the sqlite3_load_extension() interface.
        Extension loading is off by default for security reasons. An application
        must explicitly enable extension loading before extensions can be loaded.

        Args:
            db: Database connection handle.
            onoff: 1 to enable extension loading, 0 to disable.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_enable_load_extension(db, onoff)

    def sqlite3_get_autocommit(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Test For Auto-Commit Mode.

        This routine returns non-zero if the database connection is in
        autocommit mode. Autocommit mode is on by default. Autocommit mode
        is disabled by a BEGIN statement and re-enabled by a COMMIT or ROLLBACK.

        Args:
            db: Database connection handle.

        Returns:
            Non-zero if in autocommit mode, zero otherwise.
        """
        return self._fn_sqlite3_get_autocommit(db)

    def sqlite3_db_handle(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> MutExternalPointer[sqlite3_connection]:
        """Find The Database Handle Of A Prepared Statement.

        This routine returns the database connection pointer that was used to
        create the prepared statement using sqlite3_prepare_v2() or its variants.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Database connection handle that owns the statement.
        """
        return self._fn_sqlite3_db_handle(pStmt)

    def sqlite3_db_name(self, db: MutExternalPointer[sqlite3_connection], N: c_int) -> ImmutExternalPointer[c_char]:
        """Return The Schema Name For A Database.

        This routine returns the schema name for the N-th database on the
        database connection. The main database file has index 0, the temp
        database has index 1. Additional databases (attached via ATTACH)
        have indices starting at 2.

        Args:
            db: Database connection handle.
            N: Database index (0 for main, 1 for temp, 2+ for attached).

        Returns:
            Pointer to the schema name, or NULL if N is out of range.
        """
        return self._fn_sqlite3_db_name(db, N)

    def sqlite3_db_filename[
        origin: ImmutOrigin, //
    ](
        self, db: MutExternalPointer[sqlite3_connection], zDbName: ImmutUnsafePointer[c_char, origin]
    ) -> ImmutExternalPointer[c_char]:
        """Return The Filename For A Database.

        This routine returns the filename for the database schema specified
        by zDbName. The filename is returned as UTF-8. If the schema does
        not exist or if it is an in-memory or temporary database, this
        routine returns NULL.

        Args:
            db: Database connection handle.
            zDbName: Name of the database schema.

        Returns:
            Pointer to the filename, or NULL if not found.
        """
        return self._fn_sqlite3_db_filename(db, zDbName.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_db_readonly[
        origin: ImmutOrigin, //
    ](self, db: MutExternalPointer[sqlite3_connection], zDbName: ImmutUnsafePointer[c_char, origin]) -> c_int:
        """Determine If A Database Is Read-Only.

        This routine returns 1 if the database is read-only, 0 if it is
        read-write, or -1 if the zDbName is not the name of a database on
        connection db.

        Args:
            db: Database connection handle.
            zDbName: Name of the database schema to check.

        Returns:
            1 if read-only, 0 if read-write, -1 if not found.
        """
        return self._fn_sqlite3_db_readonly(db, zDbName.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_txn_state[
        origin: ImmutOrigin, //
    ](self, db: MutExternalPointer[sqlite3_connection], zSchema: ImmutUnsafePointer[c_char, origin]) -> c_int:
        """Determine The Transaction State Of A Database.

        This routine returns the current transaction state of schema zSchema
        in database connection db. The return value is one of:
        - SQLITE_TXN_NONE: No transaction is currently active
        - SQLITE_TXN_READ: A read transaction is active
        - SQLITE_TXN_WRITE: A write transaction is active

        Args:
            db: Database connection handle.
            zSchema: Name of the schema to query (NULL for main database).

        Returns:
            The transaction state code.
        """
        return self._fn_sqlite3_txn_state(db, zSchema.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_next_stmt(
        self, pDb: MutExternalPointer[sqlite3_connection], pStmt: MutExternalPointer[sqlite3_stmt]
    ) -> MutExternalPointer[sqlite3_stmt]:
        """Find The Next Prepared Statement.

        This interface returns a pointer to the next prepared statement after
        pStmt associated with database connection pDb. If pStmt is NULL then
        this interface returns a pointer to the first prepared statement
        associated with the database connection. Returns NULL if there are
        no (more) prepared statements.

        Args:
            pDb: Database connection handle.
            pStmt: Current statement pointer (NULL to get first statement).

        Returns:
            Pointer to next prepared statement, or NULL if none.
        """
        return self._fn_sqlite3_next_stmt(pDb, pStmt)

    def sqlite3_update_hook[
        cb_origin: MutOrigin,
        arg_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: MutUnsafePointer[UpdateHookCallbackFn, cb_origin],
        pArg: MutOpaquePointer[arg_origin],
    ) -> None:
        """Data Change Notification Callbacks.

        This routine registers a callback function with the database connection
        that is invoked whenever a row is updated, inserted, or deleted in a
        rowid table. The callback is invoked before the change is committed.
        The callback receives the operation type (INSERT, UPDATE, or DELETE),
        database name, table name, and rowid of the affected row.

        Args:
            db: Database connection handle.
            xCallback: Callback function to invoke on data changes.
            pArg: User data pointer passed to callback.
        """
        self._fn_sqlite3_update_hook(
            db,
            xCallback.unsafe_origin_cast[MutExternalOrigin](),
            pArg.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_commit_hook[
        cb_origin: MutOrigin,
        arg_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: MutUnsafePointer[CommitHookCallbackFn, cb_origin],
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Commit And Rollback Notification Callbacks.

        This routine registers a callback function to be invoked whenever a
        transaction is committed. The callback can return non-zero to convert
        the commit into a rollback. This is useful for implementing custom
        constraints or synchronization logic.

        Args:
            db: Database connection handle.
            xCallback: Callback function invoked before commit.
            pArg: User data pointer passed to callback.

        Returns:
            Previously registered user data pointer.
        """
        return self._fn_sqlite3_commit_hook(
            db,
            xCallback.unsafe_origin_cast[MutExternalOrigin](),
            pArg.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_rollback_hook[
        cb_origin: MutOrigin,
        arg_origin: MutOrigin,
        //,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: MutUnsafePointer[RollbackHookCallbackFn, cb_origin],
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Commit And Rollback Notification Callbacks.

        This routine registers a callback function to be invoked whenever a
        transaction is rolled back. The callback is invoked after the rollback
        has completed. This is useful for cleanup or logging purposes.

        Parameters:
            cb_origin: Origin of the callback function pointer.
            arg_origin: Origin of the user data pointer.

        Args:
            db: Database connection handle.
            xCallback: Callback function invoked after rollback.
            pArg: User data pointer passed to callback.

        Returns:
            Previously registered user data pointer.
        """
        return self._fn_sqlite3_rollback_hook(
            db,
            xCallback.unsafe_origin_cast[MutExternalOrigin](),
            pArg.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_auto_extension(self, xEntryPoint: ExtensionEntrypointCallbackFn) -> c_int:
        """Register An Auto-Extension.

        This routine registers an extension entry point that is automatically
        invoked whenever a new database connection is created. The extension
        is loaded into each database connection that is created after the
        auto-extension is registered.

        Args:
            xEntryPoint: Extension initialization function.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_auto_extension(xEntryPoint)

    def sqlite3_db_release_memory(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Release Memory Used By A Database Connection.

        This routine attempts to free as much heap memory as possible from
        database connection db. This is useful when the application needs to
        reduce memory usage temporarily without closing the database connection.

        Args:
            db: Database connection handle.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_db_release_memory(db)

    def sqlite3_cancel_auto_extension[
        origin: MutOrigin, //
    ](self, xEntryPoint: MutUnsafePointer[CancelExtensionCallbackFn, origin]) -> c_int:
        """Cancel An Auto-Extension.

        This routine unregisters an extension entry point that was previously
        registered using sqlite3_auto_extension(). The extension will no longer
        be automatically loaded into new database connections.

        Args:
            xEntryPoint: Extension initialization function to unregister.

        Returns:
            1 if the extension was found and canceled, 0 otherwise.
        """
        return self._fn_sqlite3_cancel_auto_extension(
            xEntryPoint.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_reset_auto_extension(self) -> c_int:
        """Reset The Automatic Extension Loading.

        This routine disables all automatic extensions previously registered
        using sqlite3_auto_extension(). This is useful when shutting down
        the application or when you want to start fresh with a new set of
        auto-extensions.

        Returns:
            Always returns SQLITE_OK.
        """
        return self._fn_sqlite3_reset_auto_extension()

    def sqlite3_create_module_v2[
        name_origin: ImmutOrigin,
        client_data_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zName: ImmutUnsafePointer[c_char, name_origin],
        p: MutExternalPointer[sqlite3_module],
        pClientData: MutOpaquePointer[client_data_origin],
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Register A Virtual Table Implementation.

        This routine is used to register a new virtual table module with a
        database connection. Virtual tables allow applications to publish
        application data as SQL tables. The module implementation is provided
        via the sqlite3_module structure. The destructor_callback callback is invoked
        when the module is unregistered.

        Args:
            db: Database connection handle.
            zName: Name of the virtual table module.
            p: Pointer to the module implementation structure.
            pClientData: User data pointer passed to module methods.
            destructor_callback: Destructor for pClientData.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_create_module_v2(
            db,
            zName.unsafe_origin_cast[MutExternalOrigin](),
            p,
            pClientData.unsafe_origin_cast[MutExternalOrigin](),
            destructor_callback
        )

    def sqlite3_blob_open[
        db_origin: ImmutOrigin, table_origin: ImmutOrigin, column_origin: ImmutOrigin, blob_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDb: ImmutUnsafePointer[c_char, db_origin],
        zTable: ImmutUnsafePointer[c_char, table_origin],
        zColumn: ImmutUnsafePointer[c_char, column_origin],
        iRow: Int64,
        flags: c_int,
        ppBlob: MutUnsafePointer[MutExternalPointer[sqlite3_blob], blob_origin],
    ) -> c_int:
        """Open A BLOB For Incremental I/O.

        This routine opens a handle to a BLOB located in row iRow, column
        zColumn, table zTable in database zDb. The BLOB can then be read
        or written using the incremental I/O routines. This is more efficient
        than loading the entire BLOB into memory at once.

        The flags parameter can be SQLITE_OPEN_READONLY to open the BLOB for
        reading only, or SQLITE_OPEN_READWRITE to open it for reading and writing.

        Args:
            db: Database connection handle.
            zDb: Name of the database containing the BLOB.
            zTable: Name of the table containing the BLOB.
            zColumn: Name of the column containing the BLOB.
            iRow: Row ID of the row containing the BLOB.
            flags: Open flags (SQLITE_OPEN_READONLY or SQLITE_OPEN_READWRITE).
            ppBlob: OUT: BLOB handle.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_blob_open(db, zDb.unsafe_origin_cast[MutExternalOrigin](), zTable.unsafe_origin_cast[MutExternalOrigin](), zColumn.unsafe_origin_cast[MutExternalOrigin](), iRow, flags, ppBlob.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_blob_reopen(self, pBlob: MutExternalPointer[sqlite3_blob], iRow: Int64) -> c_int:
        """Move A BLOB Handle To A New Row.

        This routine moves an existing BLOB handle so that it points to a
        different row of the same database table. This is faster than closing
        and reopening the BLOB handle. The new row must contain a BLOB or
        TEXT value in the same column.

        Args:
            pBlob: BLOB handle to reposition.
            iRow: Row ID of the new row.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_blob_reopen(pBlob, iRow)

    def sqlite3_blob_close(self, pBlob: MutExternalPointer[sqlite3_blob]) -> c_int:
        """Close A BLOB Handle.

        This routine closes a BLOB handle that was previously opened by
        sqlite3_blob_open(). Closing a BLOB handle commits any changes that
        were made to the BLOB using sqlite3_blob_write().

        Args:
            pBlob: BLOB handle to close.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_blob_close(pBlob)

    def sqlite3_blob_bytes(self, pBlob: MutExternalPointer[sqlite3_blob]) -> c_int:
        """Return The Size Of An Open BLOB.

        This routine returns the size in bytes of the BLOB accessible via
        the successfully opened BLOB handle. The size of the BLOB cannot
        change as long as the BLOB handle remains open.

        Args:
            pBlob: BLOB handle.

        Returns:
            Size of the BLOB in bytes.
        """
        return self._fn_sqlite3_blob_bytes(pBlob)

    def sqlite3_blob_read[
        origin: MutOrigin, //
    ](self, pBlob: MutExternalPointer[sqlite3_blob], Z: MutOpaquePointer[origin], N: c_int, iOffset: c_int) -> c_int:
        """Read Data From A BLOB Incrementally.

        This routine reads N bytes of data from the BLOB into buffer Z,
        starting at offset iOffset within the BLOB. This is useful for
        reading large BLOBs in chunks rather than loading the entire BLOB
        into memory.

        Args:
            pBlob: BLOB handle.
            Z: Buffer to read data into.
            N: Number of bytes to read.
            iOffset: Offset within the BLOB to start reading.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_blob_read(pBlob, Z.unsafe_origin_cast[MutExternalOrigin](), N, iOffset)

    def sqlite3_blob_write[
        origin: MutOrigin, //
    ](self, pBlob: MutExternalPointer[sqlite3_blob], z: MutOpaquePointer[origin], n: c_int, iOffset: c_int) -> c_int:
        """Write Data Into A BLOB Incrementally.

        This routine writes n bytes of data from buffer z into the BLOB,
        starting at offset iOffset within the BLOB. This is useful for
        writing large BLOBs in chunks. The BLOB handle must have been opened
        with the SQLITE_OPEN_READWRITE flag.

        Args:
            pBlob: BLOB handle.
            z: Buffer containing data to write.
            n: Number of bytes to write.
            iOffset: Offset within the BLOB to start writing.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_blob_write(pBlob, z.unsafe_origin_cast[MutExternalOrigin](), n, iOffset)

    def sqlite3_file_control[
        db_name_origin: ImmutOrigin,
        arg_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDbName: ImmutUnsafePointer[c_char, db_name_origin],
        op: c_int,
        pArg: MutOpaquePointer[arg_origin],
    ) -> c_int:
        """Low-Level Control Of Database Files.

        This routine provides a low-level interface to the VFS layer for
        performing file control operations. The op parameter specifies which
        operation to perform, and pArg is a pointer to operation-specific data.
        Common operations include SQLITE_FCNTL_LOCKSTATE, SQLITE_FCNTL_PERSIST_WAL,
        and SQLITE_FCNTL_CHUNK_SIZE.

        Args:
            db: Database connection handle.
            zDbName: Name of the database schema.
            op: Operation code.
            pArg: Operation-specific data pointer.

        Returns:
            SQLITE_OK on success, SQLITE_NOTFOUND if unknown op, or error code.
        """
        return self._fn_sqlite3_file_control(db, zDbName.unsafe_origin_cast[MutExternalOrigin](), op, pArg.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_backup_init[
        dest_name_origin: ImmutOrigin,
        source_name_origin: ImmutOrigin,
        //
    ](
        self,
        pDest: MutExternalPointer[sqlite3_connection],
        zDestName: ImmutUnsafePointer[c_char, dest_name_origin],
        pSource: MutExternalPointer[sqlite3_connection],
        zSourceName: ImmutUnsafePointer[c_char, source_name_origin],
    ) -> MutExternalPointer[sqlite3_backup]:
        """Initialize A Backup Operation.

        This routine initializes a backup operation to copy the contents of
        one database into another. The backup can proceed incrementally using
        sqlite3_backup_step(). This is useful for creating backups without
        blocking the database for extended periods.

        Args:
            pDest: Destination database connection.
            zDestName: Name of destination database schema (e.g., "main").
            pSource: Source database connection.
            zSourceName: Name of source database schema.

        Returns:
            Backup handle, or NULL on error.
        """
        return self._fn_sqlite3_backup_init(pDest, zDestName.unsafe_origin_cast[MutExternalOrigin](), pSource, zSourceName.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_backup_step(self, p: MutExternalPointer[sqlite3_backup], nPage: c_int) -> c_int:
        """Copy Up To nPage Pages.

        This routine copies up to nPage pages from the source database to the
        destination database. If nPage is negative, all remaining pages are
        copied. This routine can be called repeatedly to perform the backup
        incrementally.

        Args:
            p: Backup handle.
            nPage: Number of pages to copy (negative for all remaining).

        Returns:
            SQLITE_OK if complete, SQLITE_DONE if more to do, or error code.
        """
        return self._fn_sqlite3_backup_step(p, nPage)

    def sqlite3_backup_finish(self, p: MutExternalPointer[sqlite3_backup]) -> c_int:
        """Finish A Backup Operation.

        This routine finishes a backup operation and releases all resources
        associated with the backup handle. This routine should be called even
        if the backup fails.

        Args:
            p: Backup handle.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_backup_finish(p)

    def sqlite3_backup_remaining(self, p: MutExternalPointer[sqlite3_backup]) -> c_int:
        """Get Number Of Remaining Pages.

        This routine returns the number of pages still to be backed up at the
        conclusion of the most recent sqlite3_backup_step(). This can be used
        to track backup progress.

        Args:
            p: Backup handle.

        Returns:
            Number of pages remaining to backup.
        """
        return self._fn_sqlite3_backup_remaining(p)

    def sqlite3_backup_pagecount(self, p: MutExternalPointer[sqlite3_backup]) -> c_int:
        """Get Total Number Of Pages.

        This routine returns the total number of pages in the source database
        at the conclusion of the most recent sqlite3_backup_step(). This can
        be used together with sqlite3_backup_remaining() to calculate backup
        progress.

        Args:
            p: Backup handle.

        Returns:
            Total number of pages in source database.
        """
        return self._fn_sqlite3_backup_pagecount(p)

    def sqlite3_unlock_notify[
        arg_origin: MutOrigin, //
    ](
        self,
        pBlocked: MutExternalPointer[sqlite3_connection],
        xNotify: UnlockNotifyCallbackFn,
        pNotifyArg: MutOpaquePointer[arg_origin],
    ) -> c_int:
        """Unlock Notification.

        This routine registers a callback function that is invoked when a
        database connection that is currently blocked waiting for a lock
        becomes unblocked. This is useful for implementing custom deadlock
        detection and resolution strategies in multi-threaded applications.

        This interface is only available if SQLite is compiled with the
        SQLITE_ENABLE_UNLOCK_NOTIFY preprocessor symbol defined.

        Args:
            pBlocked: Database connection that may be blocked.
            xNotify: Callback function to invoke when unblocked.
            pNotifyArg: User data pointer passed to callback.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_unlock_notify(
            pBlocked,
            xNotify,
            pNotifyArg.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_log[origin: ImmutOrigin, //](self, iErrCode: c_int, zFormat: ImmutUnsafePointer[c_char, origin]) -> NoneType:
        """Error Logging Interface.

        This routine is used by SQLite internally to log error and warning
        messages. Applications can also use this interface to write messages
        to the SQLite error log. The format string and arguments follow
        printf conventions.

        Args:
            iErrCode: Error code associated with the message.
            zFormat: Printf-style format string.
        """
        return self._fn_sqlite3_log(iErrCode, zFormat.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_wal_hook[
        arg_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: WALHookCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Write-Ahead Log Commit Hook.

        This routine registers a callback function that is invoked each time
        data is committed to a write-ahead log (WAL). The callback can be
        used to trigger checkpoints or other actions when the WAL reaches
        a certain size.

        Args:
            db: Database connection handle.
            xCallback: Callback function invoked on WAL commits.
            pArg: User data pointer passed to callback.

        Returns:
            Previously registered user data pointer.
        """
        return self._fn_sqlite3_wal_hook(
            db,
            xCallback,
            pArg.unsafe_origin_cast[MutExternalOrigin]()
        )

    def sqlite3_wal_autocheckpoint(self, db: MutExternalPointer[sqlite3_connection], N: c_int) -> c_int:
        """Configure Automatic Checkpointing.

        This routine configures automatic checkpointing of the write-ahead log.
        A checkpoint is automatically invoked after N frames have been written
        to the WAL. Setting N to 0 or a negative value disables automatic
        checkpointing.

        Args:
            db: Database connection handle.
            N: Number of WAL frames before automatic checkpoint (0 to disable).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_wal_autocheckpoint(db, N)

    def sqlite3_wal_checkpoint[
        origin: ImmutOrigin, //
    ](self, db: MutExternalPointer[sqlite3_connection], zDb: ImmutUnsafePointer[c_char, origin]) -> c_int:
        """Checkpoint A Database.

        This routine runs a checkpoint operation on database zDb. A checkpoint
        transfers data from the write-ahead log back into the main database
        file. This is equivalent to calling sqlite3_wal_checkpoint_v2() with
        SQLITE_CHECKPOINT_PASSIVE mode.

        Args:
            db: Database connection handle.
            zDb: Name of the database schema to checkpoint (NULL for all).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_wal_checkpoint(db, zDb.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_wal_checkpoint_v2[db_origin: ImmutOrigin, log_origin: MutOrigin, checkpoint_origin: MutOrigin, //](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDb: ImmutUnsafePointer[c_char, db_origin],
        eMode: c_int,
        pnLog: MutUnsafePointer[c_int, log_origin],
        pnCkpt: MutUnsafePointer[c_int, checkpoint_origin],
    ) -> c_int:
        """Checkpoint A Database (Version 2).

        This routine runs a checkpoint operation on database zDb with more
        control over the checkpoint behavior. The eMode parameter specifies
        the checkpoint mode:
        - SQLITE_CHECKPOINT_PASSIVE: Do as much as possible without blocking
        - SQLITE_CHECKPOINT_FULL: Block until checkpoint is complete
        - SQLITE_CHECKPOINT_RESTART: Like FULL, also reset the WAL
        - SQLITE_CHECKPOINT_TRUNCATE: Like RESTART, also truncate the WAL

        The pnLog and pnCkpt parameters receive the total number of frames
        in the WAL and the number of frames checkpointed, respectively.

        Args:
            db: Database connection handle.
            zDb: Name of the database schema to checkpoint (NULL for all).
            eMode: Checkpoint mode (PASSIVE, FULL, RESTART, or TRUNCATE).
            pnLog: OUT: Total frames in WAL after checkpoint (or NULL).
            pnCkpt: OUT: Frames checkpointed (or NULL).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_wal_checkpoint_v2(db, zDb.unsafe_origin_cast[MutExternalOrigin](), eMode, pnLog.unsafe_origin_cast[MutExternalOrigin](), pnCkpt.unsafe_origin_cast[MutExternalOrigin]())

    def sqlite3_vtab_config(self, db: MutExternalPointer[sqlite3_connection], op: c_int) -> c_int:
        """Configure Virtual Table Behavior.

        This interface is used to configure virtual table implementations.
        The first argument is the database connection the virtual table is
        being created within. The second argument is a configuration option.
        Valid values for op include SQLITE_VTAB_CONSTRAINT_SUPPORT and
        SQLITE_VTAB_INNOCUOUS.

        Args:
            db: Database connection handle.
            op: Configuration option identifier.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_vtab_config(db, op)

    def sqlite3_vtab_on_conflict(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Determine The Virtual Table Conflict Policy.

        This function may only be called from within a call to the xUpdate
        method of a virtual table implementation for an INSERT or UPDATE
        operation. The value returned is one of SQLITE_ROLLBACK, SQLITE_IGNORE,
        SQLITE_FAIL, SQLITE_ABORT, or SQLITE_REPLACE, according to the ON
        CONFLICT mode of the SQL statement that triggered the call to xUpdate.

        Args:
            db: Database connection handle.

        Returns:
            The ON CONFLICT mode (ROLLBACK, IGNORE, FAIL, ABORT, or REPLACE).
        """
        return self._fn_sqlite3_vtab_on_conflict(db)

    def sqlite3_vtab_nochange(self, ctx: MutExternalPointer[sqlite3_context]) -> c_int:
        """Detect No-Op Column Updates.

        This function is used within virtual table UPDATE methods to determine
        if a column value is actually being changed. It returns non-zero if
        the column is not being changed, which can allow virtual table
        implementations to optimize UPDATE operations.

        Args:
            ctx: SQL function context.

        Returns:
            Non-zero if the column is unchanged, zero if it is being updated.
        """
        return self._fn_sqlite3_vtab_nochange(ctx)

    def sqlite3_vtab_collation(
        self, pIdxInfo: MutExternalPointer[sqlite3_index_info], iCons: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get Collation For A Virtual Table Constraint.

        This function is used within the xBestIndex method of a virtual table
        implementation to determine the collation sequence for a constraint.
        The function returns the name of the collation sequence or NULL if
        the constraint has no explicit collation.

        Args:
            pIdxInfo: Virtual table index information structure.
            iCons: Index of the constraint in the aConstraint array.

        Returns:
            Name of the collation sequence, or NULL.
        """
        return self._fn_sqlite3_vtab_collation(pIdxInfo, iCons)

    def sqlite3_vtab_distinct(self, pIdxInfo: MutExternalPointer[sqlite3_index_info]) -> c_int:
        """Determine If A Virtual Table Query Is DISTINCT.

        This function is used within the xBestIndex method of a virtual table
        implementation to determine if the query will apply a DISTINCT operator.
        Returns 1 if DISTINCT, 2 if UNIQUE, or 0 otherwise. This information
        can help virtual tables optimize query execution.

        Args:
            pIdxInfo: Virtual table index information structure.

        Returns:
            1 for DISTINCT, 2 for UNIQUE, 0 for neither.
        """
        return self._fn_sqlite3_vtab_distinct(pIdxInfo)

    def sqlite3_db_cacheflush(self, db: MutExternalPointer[sqlite3_connection]) -> c_int:
        """Flush Cached Database Pages.

        This routine attempts to flush any dirty pages in the database cache
        to disk. This is similar to what happens during a checkpoint, but
        it does not truncate or reset the write-ahead log. This routine is
        useful for ensuring data is written to disk before doing operations
        that require a consistent on-disk state.

        Args:
            db: Database connection handle.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_db_cacheflush(db)

    def sqlite3_serialize[
        schema_origin: ImmutOrigin,
        size_origin: MutOrigin,
        //,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSchema: ImmutUnsafePointer[c_char, schema_origin],
        piSize: MutUnsafePointer[Int64, size_origin],
        mFlags: c_uint,
    ) -> MutExternalPointer[c_uchar]:
        """Serialize A Database.

        This routine returns a pointer to memory that is a serialization of
        the database. The serialization is a copy of the database in the
        standard SQLite file format. The size of the serialization is written
        to *piSize. The caller is responsible for freeing the memory using
        sqlite3_free().

        This interface is only available if SQLite is compiled with the
        SQLITE_ENABLE_DESERIALIZE preprocessor symbol defined.

        Args:
            db: Database connection handle.
            zSchema: Name of database schema to serialize (e.g., "main").
            piSize: OUT: Size of the serialization in bytes.
            mFlags: Flags controlling serialization behavior.

        Returns:
            Pointer to serialized database, or NULL on error.
        """
        return self._fn_sqlite3_serialize(db, zSchema.unsafe_origin_cast[MutExternalOrigin](), piSize.unsafe_origin_cast[MutExternalOrigin](), mFlags)

    def sqlite3_deserialize[
        schema_origin: ImmutOrigin,
        data_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSchema: ImmutUnsafePointer[c_char, schema_origin],
        pData: MutUnsafePointer[c_uchar, data_origin],
        szDb: Int64,
        szBuf: Int64,
        mFlags: c_uint,
    ) -> c_int:
        """Deserialize A Database.

        This routine causes a database connection to disconnect from database
        zSchema and then reopen zSchema as an in-memory database based on the
        serialization contained in pData. The serialization must be in the
        standard SQLite database file format.

        This interface is only available if SQLite is compiled with the
        SQLITE_ENABLE_DESERIALIZE preprocessor symbol defined.

        Args:
            db: Database connection handle.
            zSchema: Name of database schema to deserialize (e.g., "main").
            pData: Pointer to serialized database data.
            szDb: Size of the database in bytes.
            szBuf: Size of the buffer in bytes (>= szDb).
            mFlags: Flags controlling deserialization behavior.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self._fn_sqlite3_deserialize(
            db,
            zSchema.unsafe_origin_cast[MutExternalOrigin](),
            pData.unsafe_origin_cast[MutExternalOrigin](),
            szDb,
            szBuf,
            mFlags
        )
