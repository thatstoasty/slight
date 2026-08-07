from std import os
from slight.c.types import (
    ImmExternalPointer,
    MutExternalPointer,
    AggFinalCallback,
    AggStepCallback,
    AuthCallbackFn,
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

            # Validate that every C symbol used by this binding actually exists in
            # the loaded library, so call sites below can assume the lookup always succeeds.
            if not self.lib.check_symbol("sqlite3_libversion"): raise Error("Missing required SQLite symbol: sqlite3_libversion")
            if not self.lib.check_symbol("sqlite3_sourceid"): raise Error("Missing required SQLite symbol: sqlite3_sourceid")
            if not self.lib.check_symbol("sqlite3_libversion_number"): raise Error("Missing required SQLite symbol: sqlite3_libversion_number")
            if not self.lib.check_symbol("sqlite3_threadsafe"): raise Error("Missing required SQLite symbol: sqlite3_threadsafe")
            if not self.lib.check_symbol("sqlite3_close"): raise Error("Missing required SQLite symbol: sqlite3_close")
            if not self.lib.check_symbol("sqlite3_config"): raise Error("Missing required SQLite symbol: sqlite3_config")
            if not self.lib.check_symbol("sqlite3_db_config"): raise Error("Missing required SQLite symbol: sqlite3_db_config")
            if not self.lib.check_symbol("sqlite3_extended_result_codes"): raise Error("Missing required SQLite symbol: sqlite3_extended_result_codes")
            if not self.lib.check_symbol("sqlite3_last_insert_rowid"): raise Error("Missing required SQLite symbol: sqlite3_last_insert_rowid")
            if not self.lib.check_symbol("sqlite3_changes"): raise Error("Missing required SQLite symbol: sqlite3_changes")
            if not self.lib.check_symbol("sqlite3_changes64"): raise Error("Missing required SQLite symbol: sqlite3_changes64")
            if not self.lib.check_symbol("sqlite3_total_changes"): raise Error("Missing required SQLite symbol: sqlite3_total_changes")
            if not self.lib.check_symbol("sqlite3_total_changes64"): raise Error("Missing required SQLite symbol: sqlite3_total_changes64")
            if not self.lib.check_symbol("sqlite3_interrupt"): raise Error("Missing required SQLite symbol: sqlite3_interrupt")
            if not self.lib.check_symbol("sqlite3_is_interrupted"): raise Error("Missing required SQLite symbol: sqlite3_is_interrupted")
            if not self.lib.check_symbol("sqlite3_busy_handler"): raise Error("Missing required SQLite symbol: sqlite3_busy_handler")
            if not self.lib.check_symbol("sqlite3_busy_timeout"): raise Error("Missing required SQLite symbol: sqlite3_busy_timeout")
            if not self.lib.check_symbol("sqlite3_malloc64"): raise Error("Missing required SQLite symbol: sqlite3_malloc64")
            if not self.lib.check_symbol("sqlite3_free"): raise Error("Missing required SQLite symbol: sqlite3_free")
            if not self.lib.check_symbol("sqlite3_msize"): raise Error("Missing required SQLite symbol: sqlite3_msize")
            if not self.lib.check_symbol("sqlite3_set_authorizer"): raise Error("Missing required SQLite symbol: sqlite3_set_authorizer")
            if not self.lib.check_symbol("sqlite3_trace"): raise Error("Missing required SQLite symbol: sqlite3_trace")
            if not self.lib.check_symbol("sqlite3_profile"): raise Error("Missing required SQLite symbol: sqlite3_profile")
            if not self.lib.check_symbol("sqlite3_trace_v2"): raise Error("Missing required SQLite symbol: sqlite3_trace_v2")
            if not self.lib.check_symbol("sqlite3_progress_handler"): raise Error("Missing required SQLite symbol: sqlite3_progress_handler")
            if not self.lib.check_symbol("sqlite3_open_v2"): raise Error("Missing required SQLite symbol: sqlite3_open_v2")
            if not self.lib.check_symbol("sqlite3_errcode"): raise Error("Missing required SQLite symbol: sqlite3_errcode")
            if not self.lib.check_symbol("sqlite3_extended_errcode"): raise Error("Missing required SQLite symbol: sqlite3_extended_errcode")
            if not self.lib.check_symbol("sqlite3_errmsg"): raise Error("Missing required SQLite symbol: sqlite3_errmsg")
            if not self.lib.check_symbol("sqlite3_errstr"): raise Error("Missing required SQLite symbol: sqlite3_errstr")
            if not self.lib.check_symbol("sqlite3_error_offset"): raise Error("Missing required SQLite symbol: sqlite3_error_offset")
            if not self.lib.check_symbol("sqlite3_limit"): raise Error("Missing required SQLite symbol: sqlite3_limit")
            if not self.lib.check_symbol("sqlite3_prepare_v2"): raise Error("Missing required SQLite symbol: sqlite3_prepare_v2")
            if not self.lib.check_symbol("sqlite3_prepare_v3"): raise Error("Missing required SQLite symbol: sqlite3_prepare_v3")
            if not self.lib.check_symbol("sqlite3_sql"): raise Error("Missing required SQLite symbol: sqlite3_sql")
            if not self.lib.check_symbol("sqlite3_expanded_sql"): raise Error("Missing required SQLite symbol: sqlite3_expanded_sql")
            if not self.lib.check_symbol("sqlite3_stmt_readonly"): raise Error("Missing required SQLite symbol: sqlite3_stmt_readonly")
            if not self.lib.check_symbol("sqlite3_stmt_isexplain"): raise Error("Missing required SQLite symbol: sqlite3_stmt_isexplain")
            if not self.lib.check_symbol("sqlite3_stmt_busy"): raise Error("Missing required SQLite symbol: sqlite3_stmt_busy")
            if not self.lib.check_symbol("sqlite3_bind_blob64"): raise Error("Missing required SQLite symbol: sqlite3_bind_blob64")
            if not self.lib.check_symbol("sqlite3_bind_double"): raise Error("Missing required SQLite symbol: sqlite3_bind_double")
            if not self.lib.check_symbol("sqlite3_bind_int64"): raise Error("Missing required SQLite symbol: sqlite3_bind_int64")
            if not self.lib.check_symbol("sqlite3_bind_null"): raise Error("Missing required SQLite symbol: sqlite3_bind_null")
            if not self.lib.check_symbol("sqlite3_bind_text64"): raise Error("Missing required SQLite symbol: sqlite3_bind_text64")
            if not self.lib.check_symbol("sqlite3_bind_pointer"): raise Error("Missing required SQLite symbol: sqlite3_bind_pointer")
            if not self.lib.check_symbol("sqlite3_bind_zeroblob"): raise Error("Missing required SQLite symbol: sqlite3_bind_zeroblob")
            if not self.lib.check_symbol("sqlite3_bind_parameter_count"): raise Error("Missing required SQLite symbol: sqlite3_bind_parameter_count")
            if not self.lib.check_symbol("sqlite3_bind_parameter_name"): raise Error("Missing required SQLite symbol: sqlite3_bind_parameter_name")
            if not self.lib.check_symbol("sqlite3_bind_parameter_index"): raise Error("Missing required SQLite symbol: sqlite3_bind_parameter_index")
            if not self.lib.check_symbol("sqlite3_clear_bindings"): raise Error("Missing required SQLite symbol: sqlite3_clear_bindings")
            if not self.lib.check_symbol("sqlite3_column_count"): raise Error("Missing required SQLite symbol: sqlite3_column_count")
            if not self.lib.check_symbol("sqlite3_column_name"): raise Error("Missing required SQLite symbol: sqlite3_column_name")
            if not self.lib.check_symbol("sqlite3_column_database_name"): raise Error("Missing required SQLite symbol: sqlite3_column_database_name")
            if not self.lib.check_symbol("sqlite3_column_table_name"): raise Error("Missing required SQLite symbol: sqlite3_column_table_name")
            if not self.lib.check_symbol("sqlite3_column_origin_name"): raise Error("Missing required SQLite symbol: sqlite3_column_origin_name")
            if not self.lib.check_symbol("sqlite3_column_decltype"): raise Error("Missing required SQLite symbol: sqlite3_column_decltype")
            if not self.lib.check_symbol("sqlite3_step"): raise Error("Missing required SQLite symbol: sqlite3_step")
            if not self.lib.check_symbol("sqlite3_column_blob"): raise Error("Missing required SQLite symbol: sqlite3_column_blob")
            if not self.lib.check_symbol("sqlite3_column_double"): raise Error("Missing required SQLite symbol: sqlite3_column_double")
            if not self.lib.check_symbol("sqlite3_column_int64"): raise Error("Missing required SQLite symbol: sqlite3_column_int64")
            if not self.lib.check_symbol("sqlite3_column_text"): raise Error("Missing required SQLite symbol: sqlite3_column_text")
            if not self.lib.check_symbol("sqlite3_column_value"): raise Error("Missing required SQLite symbol: sqlite3_column_value")
            if not self.lib.check_symbol("sqlite3_column_bytes"): raise Error("Missing required SQLite symbol: sqlite3_column_bytes")
            if not self.lib.check_symbol("sqlite3_column_type"): raise Error("Missing required SQLite symbol: sqlite3_column_type")
            if not self.lib.check_symbol("sqlite3_finalize"): raise Error("Missing required SQLite symbol: sqlite3_finalize")
            if not self.lib.check_symbol("sqlite3_reset"): raise Error("Missing required SQLite symbol: sqlite3_reset")
            if not self.lib.check_symbol("sqlite3_create_function_v2"): raise Error("Missing required SQLite symbol: sqlite3_create_function_v2")
            if not self.lib.check_symbol("sqlite3_create_window_function"): raise Error("Missing required SQLite symbol: sqlite3_create_window_function")
            if not self.lib.check_symbol("sqlite3_aggregate_count"): raise Error("Missing required SQLite symbol: sqlite3_aggregate_count")
            if not self.lib.check_symbol("sqlite3_expired"): raise Error("Missing required SQLite symbol: sqlite3_expired")
            if not self.lib.check_symbol("sqlite3_transfer_bindings"): raise Error("Missing required SQLite symbol: sqlite3_transfer_bindings")
            if not self.lib.check_symbol("sqlite3_global_recover"): raise Error("Missing required SQLite symbol: sqlite3_global_recover")
            if not self.lib.check_symbol("sqlite3_thread_cleanup"): raise Error("Missing required SQLite symbol: sqlite3_thread_cleanup")
            if not self.lib.check_symbol("sqlite3_memory_alarm"): raise Error("Missing required SQLite symbol: sqlite3_memory_alarm")
            if not self.lib.check_symbol("sqlite3_value_blob"): raise Error("Missing required SQLite symbol: sqlite3_value_blob")
            if not self.lib.check_symbol("sqlite3_value_double"): raise Error("Missing required SQLite symbol: sqlite3_value_double")
            if not self.lib.check_symbol("sqlite3_value_int64"): raise Error("Missing required SQLite symbol: sqlite3_value_int64")
            if not self.lib.check_symbol("sqlite3_value_pointer"): raise Error("Missing required SQLite symbol: sqlite3_value_pointer")
            if not self.lib.check_symbol("sqlite3_value_text"): raise Error("Missing required SQLite symbol: sqlite3_value_text")
            if not self.lib.check_symbol("sqlite3_value_bytes"): raise Error("Missing required SQLite symbol: sqlite3_value_bytes")
            if not self.lib.check_symbol("sqlite3_value_type"): raise Error("Missing required SQLite symbol: sqlite3_value_type")
            if not self.lib.check_symbol("sqlite3_value_nochange"): raise Error("Missing required SQLite symbol: sqlite3_value_nochange")
            if not self.lib.check_symbol("sqlite3_value_subtype"): raise Error("Missing required SQLite symbol: sqlite3_value_subtype")
            if not self.lib.check_symbol("sqlite3_aggregate_context"): raise Error("Missing required SQLite symbol: sqlite3_aggregate_context")
            if not self.lib.check_symbol("sqlite3_user_data"): raise Error("Missing required SQLite symbol: sqlite3_user_data")
            if not self.lib.check_symbol("sqlite3_context_db_handle"): raise Error("Missing required SQLite symbol: sqlite3_context_db_handle")
            if not self.lib.check_symbol("sqlite3_get_auxdata"): raise Error("Missing required SQLite symbol: sqlite3_get_auxdata")
            if not self.lib.check_symbol("sqlite3_set_auxdata"): raise Error("Missing required SQLite symbol: sqlite3_set_auxdata")
            if not self.lib.check_symbol("sqlite3_result_blob64"): raise Error("Missing required SQLite symbol: sqlite3_result_blob64")
            if not self.lib.check_symbol("sqlite3_result_double"): raise Error("Missing required SQLite symbol: sqlite3_result_double")
            if not self.lib.check_symbol("sqlite3_result_error"): raise Error("Missing required SQLite symbol: sqlite3_result_error")
            if not self.lib.check_symbol("sqlite3_result_error_toobig"): raise Error("Missing required SQLite symbol: sqlite3_result_error_toobig")
            if not self.lib.check_symbol("sqlite3_result_error_nomem"): raise Error("Missing required SQLite symbol: sqlite3_result_error_nomem")
            if not self.lib.check_symbol("sqlite3_result_error_code"): raise Error("Missing required SQLite symbol: sqlite3_result_error_code")
            if not self.lib.check_symbol("sqlite3_result_int64"): raise Error("Missing required SQLite symbol: sqlite3_result_int64")
            if not self.lib.check_symbol("sqlite3_result_null"): raise Error("Missing required SQLite symbol: sqlite3_result_null")
            if not self.lib.check_symbol("sqlite3_result_text64"): raise Error("Missing required SQLite symbol: sqlite3_result_text64")
            if not self.lib.check_symbol("sqlite3_result_value"): raise Error("Missing required SQLite symbol: sqlite3_result_value")
            if not self.lib.check_symbol("sqlite3_result_pointer"): raise Error("Missing required SQLite symbol: sqlite3_result_pointer")
            if not self.lib.check_symbol("sqlite3_result_zeroblob"): raise Error("Missing required SQLite symbol: sqlite3_result_zeroblob")
            if not self.lib.check_symbol("sqlite3_result_subtype"): raise Error("Missing required SQLite symbol: sqlite3_result_subtype")
            if not self.lib.check_symbol("sqlite3_create_collation_v2"): raise Error("Missing required SQLite symbol: sqlite3_create_collation_v2")
            if not self.lib.check_symbol("sqlite3_collation_needed"): raise Error("Missing required SQLite symbol: sqlite3_collation_needed")
            if not self.lib.check_symbol("sqlite3_soft_heap_limit"): raise Error("Missing required SQLite symbol: sqlite3_soft_heap_limit")
            if not self.lib.check_symbol("sqlite3_soft_heap_limit64"): raise Error("Missing required SQLite symbol: sqlite3_soft_heap_limit64")
            if not self.lib.check_symbol("sqlite3_stmt_status"): raise Error("Missing required SQLite symbol: sqlite3_stmt_status")
            if not self.lib.check_symbol("sqlite3_table_column_metadata"): raise Error("Missing required SQLite symbol: sqlite3_table_column_metadata")
            if not self.lib.check_symbol("sqlite3_load_extension"): raise Error("Missing required SQLite symbol: sqlite3_load_extension")
            if not self.lib.check_symbol("sqlite3_enable_load_extension"): raise Error("Missing required SQLite symbol: sqlite3_enable_load_extension")
            if not self.lib.check_symbol("sqlite3_get_autocommit"): raise Error("Missing required SQLite symbol: sqlite3_get_autocommit")
            if not self.lib.check_symbol("sqlite3_db_handle"): raise Error("Missing required SQLite symbol: sqlite3_db_handle")
            if not self.lib.check_symbol("sqlite3_db_name"): raise Error("Missing required SQLite symbol: sqlite3_db_name")
            if not self.lib.check_symbol("sqlite3_db_filename"): raise Error("Missing required SQLite symbol: sqlite3_db_filename")
            if not self.lib.check_symbol("sqlite3_db_readonly"): raise Error("Missing required SQLite symbol: sqlite3_db_readonly")
            if not self.lib.check_symbol("sqlite3_txn_state"): raise Error("Missing required SQLite symbol: sqlite3_txn_state")
            if not self.lib.check_symbol("sqlite3_next_stmt"): raise Error("Missing required SQLite symbol: sqlite3_next_stmt")
            if not self.lib.check_symbol("sqlite3_update_hook"): raise Error("Missing required SQLite symbol: sqlite3_update_hook")
            if not self.lib.check_symbol("sqlite3_commit_hook"): raise Error("Missing required SQLite symbol: sqlite3_commit_hook")
            if not self.lib.check_symbol("sqlite3_rollback_hook"): raise Error("Missing required SQLite symbol: sqlite3_rollback_hook")
            if not self.lib.check_symbol("sqlite3_auto_extension"): raise Error("Missing required SQLite symbol: sqlite3_auto_extension")
            if not self.lib.check_symbol("sqlite3_db_release_memory"): raise Error("Missing required SQLite symbol: sqlite3_db_release_memory")
            if not self.lib.check_symbol("sqlite3_cancel_auto_extension"): raise Error("Missing required SQLite symbol: sqlite3_cancel_auto_extension")
            if not self.lib.check_symbol("sqlite3_reset_auto_extension"): raise Error("Missing required SQLite symbol: sqlite3_reset_auto_extension")
            if not self.lib.check_symbol("sqlite3_create_module_v2"): raise Error("Missing required SQLite symbol: sqlite3_create_module_v2")
            if not self.lib.check_symbol("sqlite3_blob_open"): raise Error("Missing required SQLite symbol: sqlite3_blob_open")
            if not self.lib.check_symbol("sqlite3_blob_reopen"): raise Error("Missing required SQLite symbol: sqlite3_blob_reopen")
            if not self.lib.check_symbol("sqlite3_blob_close"): raise Error("Missing required SQLite symbol: sqlite3_blob_close")
            if not self.lib.check_symbol("sqlite3_blob_bytes"): raise Error("Missing required SQLite symbol: sqlite3_blob_bytes")
            if not self.lib.check_symbol("sqlite3_blob_read"): raise Error("Missing required SQLite symbol: sqlite3_blob_read")
            if not self.lib.check_symbol("sqlite3_blob_write"): raise Error("Missing required SQLite symbol: sqlite3_blob_write")
            if not self.lib.check_symbol("sqlite3_file_control"): raise Error("Missing required SQLite symbol: sqlite3_file_control")
            if not self.lib.check_symbol("sqlite3_backup_init"): raise Error("Missing required SQLite symbol: sqlite3_backup_init")
            if not self.lib.check_symbol("sqlite3_backup_step"): raise Error("Missing required SQLite symbol: sqlite3_backup_step")
            if not self.lib.check_symbol("sqlite3_backup_finish"): raise Error("Missing required SQLite symbol: sqlite3_backup_finish")
            if not self.lib.check_symbol("sqlite3_backup_remaining"): raise Error("Missing required SQLite symbol: sqlite3_backup_remaining")
            if not self.lib.check_symbol("sqlite3_backup_pagecount"): raise Error("Missing required SQLite symbol: sqlite3_backup_pagecount")
            if not self.lib.check_symbol("sqlite3_unlock_notify"): raise Error("Missing required SQLite symbol: sqlite3_unlock_notify")
            if not self.lib.check_symbol("sqlite3_log"): raise Error("Missing required SQLite symbol: sqlite3_log")
            if not self.lib.check_symbol("sqlite3_wal_hook"): raise Error("Missing required SQLite symbol: sqlite3_wal_hook")
            if not self.lib.check_symbol("sqlite3_wal_autocheckpoint"): raise Error("Missing required SQLite symbol: sqlite3_wal_autocheckpoint")
            if not self.lib.check_symbol("sqlite3_wal_checkpoint"): raise Error("Missing required SQLite symbol: sqlite3_wal_checkpoint")
            if not self.lib.check_symbol("sqlite3_wal_checkpoint_v2"): raise Error("Missing required SQLite symbol: sqlite3_wal_checkpoint_v2")
            if not self.lib.check_symbol("sqlite3_vtab_config"): raise Error("Missing required SQLite symbol: sqlite3_vtab_config")
            if not self.lib.check_symbol("sqlite3_vtab_on_conflict"): raise Error("Missing required SQLite symbol: sqlite3_vtab_on_conflict")
            if not self.lib.check_symbol("sqlite3_vtab_nochange"): raise Error("Missing required SQLite symbol: sqlite3_vtab_nochange")
            if not self.lib.check_symbol("sqlite3_vtab_collation"): raise Error("Missing required SQLite symbol: sqlite3_vtab_collation")
            if not self.lib.check_symbol("sqlite3_vtab_distinct"): raise Error("Missing required SQLite symbol: sqlite3_vtab_distinct")
            if not self.lib.check_symbol("sqlite3_declare_vtab"): raise Error("Missing required SQLite symbol: sqlite3_declare_vtab")
            if not self.lib.check_symbol("sqlite3_db_cacheflush"): raise Error("Missing required SQLite symbol: sqlite3_db_cacheflush")
            if not self.lib.check_symbol("sqlite3_serialize"): raise Error("Missing required SQLite symbol: sqlite3_serialize")
            if not self.lib.check_symbol("sqlite3_deserialize"): raise Error("Missing required SQLite symbol: sqlite3_deserialize")
        except e:
            os.abort(String(t"Failed to load the SQLite library: {e}"))

    def sqlite3_libversion(self) -> ImmExternalPointer[c_char]:
        """Get the SQLite library version string.

        Returns a pointer to a string containing the version of the SQLite
        library that is running. This corresponds to the SQLITE_VERSION
        string.

        Returns:
            Pointer to a null-terminated string containing the SQLite version.
        """
        try:
            return self.lib.get_function[Pointer[Int8, ImmUntrackedOrigin]]("sqlite3_libversion")()
        except:
            os.abort("sqlite3_libversion: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_sourceid(self) -> ImmExternalPointer[c_char]:
        """Get the SQLite source ID.

        Returns a pointer to a string containing the date and time of
        the check-in (UTC) and a SHA1 hash of the entire source tree.

        Returns:
            Pointer to a string containing the SQLite source identifier.
        """
        try:
            return self.lib.get_function[ImmExternalPointer[c_char]]("sqlite3_sourceid")()
        except:
            os.abort("sqlite3_sourceid: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_libversion_number(self) -> c_int:
        """Get the SQLite library version number.

        Returns an integer equal to SQLITE_VERSION_NUMBER. The version
        number is in the format (X*1000000 + Y*1000 + Z) where X, Y, and Z
        are the major, minor, and release numbers respectively.

        Returns:
            The SQLite library version as an integer.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_libversion_number")()
        except:
            os.abort("sqlite3_libversion_number: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_threadsafe(self) -> c_int:
        """Test if the library is threadsafe.

        Returns zero if and only if SQLite was compiled with mutexing code
        omitted due to the SQLITE_THREADSAFE compile-time option being set to 0.

        Returns:
            Non-zero if SQLite is threadsafe, 0 if not threadsafe.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_threadsafe")()
        except:
            os.abort("sqlite3_threadsafe: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_close")(connection)
        except:
            os.abort("sqlite3_close: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_config")(op)
        except:
            os.abort("sqlite3_config: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_db_config")(db, op)
        except:
            os.abort("sqlite3_db_config: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_extended_result_codes")(db, onoff)
        except:
            os.abort("sqlite3_extended_result_codes: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[Int64]("sqlite3_last_insert_rowid")(db)
        except:
            os.abort("sqlite3_last_insert_rowid: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_changes")(db)
        except:
            os.abort("sqlite3_changes: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[Int64]("sqlite3_changes64")(db)
        except:
            os.abort("sqlite3_changes64: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_total_changes")(db)
        except:
            os.abort("sqlite3_total_changes: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[Int64]("sqlite3_total_changes64")(db)
        except:
            os.abort("sqlite3_total_changes64: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            self.lib.get_function[NoneType]("sqlite3_interrupt")(db)
        except:
            pass

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
        try:
            return self.lib.get_function[c_int]("sqlite3_is_interrupted")(db)
        except:
            os.abort("sqlite3_is_interrupted: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_busy_handler")(db, callback, arg.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_busy_handler: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_busy_timeout")(db, ms)
        except:
            os.abort("sqlite3_busy_timeout: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_malloc64(self, size: UInt64) -> Optional[MutExternalPointer[NoneType]]:
        """Memory Allocation Subsystem - 64-bit.

        This routine is like `sqlite3_malloc` except that it allocates memory
        with a 64-bit size argument. This routine is intended for use with
        large allocations that may exceed the 32-bit limit.

        Args:
            size: Number of bytes to allocate.

        Returns:
            Pointer to allocated memory, or None if allocation fails.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_malloc64")(size)
        except:
            os.abort("sqlite3_malloc64: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_free(self, ptr: MutExternalPointer[NoneType]):
        """Memory Deallocation.

        This routine releases memory previously returned by `sqlite3_malloc`,
        `sqlite3_malloc64`, `sqlite3_realloc`, or `sqlite3_realloc64`.
        Passing a NULL pointer to `sqlite3_free` is a harmless no-op.

        Args:
            ptr: Pointer to memory to free.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_free")(ptr)
        except:
            pass

    def sqlite3_msize(self, ptr: MutExternalPointer[NoneType]) -> UInt64:
        """Memory Size Of Allocation.

        This routine returns the number of bytes of memory that were allocated
        by `sqlite3_malloc`, `sqlite3_malloc64`, `sqlite3_realloc`, or
        `sqlite3_realloc64`. The size returned is always at least as large
        as the requested size but may be larger.

        Args:
            ptr: Pointer to allocated memory.

        Returns:
            Size of the allocation in bytes.
        """
        try:
            return self.lib.get_function[UInt64]("sqlite3_msize")(ptr)
        except:
            os.abort("sqlite3_msize: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_set_authorizer[
        userdata_origin: MutOrigin, //,
        auth_callback: AuthCallbackFn,
    ](self, db: MutExternalPointer[sqlite3_connection], pUserData: Optional[MutOpaquePointer[userdata_origin]]) -> c_int:
        """Compile-Time Authorization Callbacks.

        This routine registers an authorizer callback with a particular database
        connection. The authorizer callback is invoked as SQL statements are being
        compiled by `sqlite3_prepare` or its variants. At various points during
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
        var user_data = Optional[MutExternalPointer[NoneType]](pUserData.value().unsafe_origin_cast[MutUntrackedOrigin]()) if pUserData else None
        try:
            return self.lib.get_function[c_int]("sqlite3_set_authorizer")(db, auth_callback, user_data)
        except:
            os.abort("sqlite3_set_authorizer: symbol not found in libsqlite3 (should have been validated in __init__)")
    
    def sqlite3_remove_authorizer(
        self,
        db: MutExternalPointer[sqlite3_connection]
    ) -> c_int:
        """Compile-Time Authorization Callbacks.

        This routine registers an authorizer callback with a particular database
        connection. The authorizer callback is invoked as SQL statements are being
        compiled by `sqlite3_prepare` or its variants. At various points during
        the compilation process, the authorizer callback is invoked to see if the
        action being coded is allowed. The authorizer callback should return
        SQLITE_OK to allow the action, SQLITE_IGNORE to cause the entire SQL
        statement to be silently ignored, or SQLITE_DENY to cause the entire
        SQL statement to fail with an error.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_set_authorizer")(db, None, None)
        except:
            os.abort("sqlite3_remove_authorizer: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_trace[arg_origin: MutOrigin](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xTrace: TraceCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ) -> Optional[MutExternalPointer[NoneType]]:
        """Deprecated SQL Trace Hook.

        This routine registers a callback function that is invoked at various
        times when an SQL statement is being run by `sqlite3_step`. The callback
        is passed a UTF-8 rendering of the SQL statement text as the statement
        first begins executing. This interface is deprecated; use `sqlite3_trace_v2`
        instead.

        Args:
            db: Database connection handle.
            xTrace: Trace callback function.
            pArg: User data pointer passed to callback.

        Returns:
            Previously registered user data pointer.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_trace")(db, xTrace, pArg.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_trace: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_profile[
        arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xProfile: ProfileCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ) -> Optional[MutExternalPointer[NoneType]]:
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
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_profile")(db, xProfile, pArg.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_profile: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_trace_v2(
        self,
        db: MutExternalPointer[sqlite3_connection],
        uMask: c_uint,
        xCallback: TraceV2CallbackFn,
        pCtx: Optional[MutExternalPointer[NoneType]],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_trace_v2")(db, uMask, xCallback, pCtx)
        except:
            os.abort("sqlite3_trace_v2: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            self.lib.get_function[NoneType]("sqlite3_progress_handler")(db, nOps, xProgress, pArg.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            pass

    def sqlite3_open_v2[
        filename_origin: ImmOrigin,
        db_origin: MutOrigin,
        vfs_origin: ImmOrigin,
    ](
        self,
        filename: ImmPointer[c_char, filename_origin],
        ppDb: MutPointer[MutExternalPointer[sqlite3_connection], db_origin],
        flags: c_int,
        zVfs: ImmPointer[c_char, vfs_origin],
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
            zVfs: Name of VFS module to use (None for default).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_open_v2")(
                filename.unsafe_origin_cast[MutUntrackedOrigin](),
                ppDb.unsafe_origin_cast[MutUntrackedOrigin](),
                flags,
                zVfs.unsafe_origin_cast[MutUntrackedOrigin]()
            )
        except:
            os.abort("sqlite3_open_v2: symbol not found in libsqlite3 (should have been validated in __init__)")
    
    def sqlite3_open_v2[
        filename_origin: ImmOrigin,
        db_origin: MutOrigin,
    ](
        self,
        filename: ImmPointer[c_char, filename_origin],
        ppDb: MutPointer[MutExternalPointer[sqlite3_connection], db_origin],
        flags: c_int,
    ) -> c_int:
        """Open A Database Connection with specified flags. VFS is set to default by passing None.

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

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_open_v2")(
                filename.unsafe_origin_cast[MutUntrackedOrigin](),
                ppDb.unsafe_origin_cast[MutUntrackedOrigin](),
                flags,
                None
            )
        except:
            os.abort("sqlite3_open_v2: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_errcode")(db)
        except:
            os.abort("sqlite3_errcode: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_extended_errcode")(db)
        except:
            os.abort("sqlite3_extended_errcode: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_errmsg(self, db: MutExternalPointer[sqlite3_connection]) -> Optional[ImmExternalPointer[c_char]]:
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
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_errmsg")(db)
        except:
            os.abort("sqlite3_errmsg: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_errstr(self, e: c_int) -> Optional[ImmExternalPointer[c_char]]:
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
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_errstr")(e)
        except:
            os.abort("sqlite3_errstr: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_error_offset")(db)
        except:
            os.abort("sqlite3_error_offset: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_limit")(db, id, newVal)
        except:
            os.abort("sqlite3_limit: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_prepare_v2[
        sql_origin: ImmOrigin, stmt_origin: MutOrigin, tail_origin1: ImmOrigin, tail_origin2: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSql: ImmPointer[c_char, sql_origin],
        nByte: c_int,
        ppStmt: MutPointer[MutExternalPointer[sqlite3_stmt], stmt_origin],
        pzTail: MutPointer[ImmPointer[c_char, tail_origin1], tail_origin2],
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
            nByte: Maximum length of zSql in bytes (or -1 for None-terminated).
            ppStmt: OUT: Compiled prepared statement object.
            pzTail: OUT: Pointer to unused portion of zSql (or None).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # var temp_tail = pzTail[].unsafe_origin_cast[ImmUntrackedOrigin]()
        # return self._fn_sqlite3_prepare_v2(
        #     db,
        #     zSql.unsafe_origin_cast[MutUntrackedOrigin](),
        #     nByte,
        #     ppStmt.unsafe_origin_cast[MutUntrackedOrigin](),
        #     Pointer(to=temp_tail).unsafe_origin_cast[MutUntrackedOrigin]()
        # )
        try:
            return self.lib.get_function[c_int]("sqlite3_prepare_v2")(db, zSql, nByte, ppStmt, pzTail)
        except:
            os.abort("sqlite3_prepare_v2: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_prepare_v3[
        sql_origin: ImmOrigin, stmt_origin: MutOrigin, tail_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSql: ImmPointer[c_char, sql_origin],
        nByte: c_int,
        prepFlags: c_uint,
        ppStmt: MutPointer[Optional[MutExternalPointer[sqlite3_stmt]], stmt_origin],
        pzTail: MutPointer[ImmPointer[c_char, sql_origin], tail_origin],
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
            nByte: Maximum length of zSql in bytes (or -1 for None-terminated).
            prepFlags: Flags controlling statement preparation.
            ppStmt: OUT: Compiled prepared statement object.
            pzTail: OUT: Pointer to unused portion of zSql (or None).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        # var temp_tail = pzTail[].unsafe_origin_cast[ImmUntrackedOrigin]()
        # return self._fn_sqlite3_prepare_v3(
        #     db,
        #     zSql.unsafe_origin_cast[MutUntrackedOrigin](),
        #     nByte,
        #     prepFlags,
        #     ppStmt.unsafe_origin_cast[MutUntrackedOrigin](),
        #     Pointer(to=temp_tail).unsafe_origin_cast[MutUntrackedOrigin]()
        #     # pzTail.unsafe_origin_cast[MutUntrackedOrigin]()
        # )
        try:
            return self.lib.get_function[c_int]("sqlite3_prepare_v3")(db, zSql, nByte, prepFlags, ppStmt, pzTail)
        except:
            os.abort("sqlite3_prepare_v3: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_sql(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> Optional[ImmExternalPointer[c_char]]:
        """Retrieve the SQL text of a prepared statement.

        Returns a pointer to a copy of the UTF-8 SQL text used to create the
        prepared statement if that statement was compiled using sqlite3_prepare_v2()
        or its variants.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Pointer to the SQL text used to create the statement.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_sql")(pStmt)
        except:
            os.abort("sqlite3_sql: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_expanded_sql(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> Optional[MutExternalPointer[c_char]]:
        """Retrieve SQL with bound parameters expanded.

        Returns a pointer to a UTF-8 string containing the SQL text of the
        prepared statement with bound parameters expanded inline. This is useful
        for debugging and logging purposes.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Pointer to the expanded SQL text, or None if out of memory.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[c_char]]]("sqlite3_expanded_sql")(pStmt)
        except:
            os.abort("sqlite3_expanded_sql: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_stmt_readonly(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_stmt_readonly")(pStmt)
        except:
            os.abort("sqlite3_stmt_readonly: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_stmt_isexplain(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
        """Query The EXPLAIN Setting For A Prepared Statement.

        This routine returns 0 if the prepared statement is a normal statement,
        1 if it is an EXPLAIN statement, or 2 if it is an EXPLAIN QUERY PLAN
        statement. This information can be useful for logging and debugging purposes.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            0 for normal statement, 1 for EXPLAIN, 2 for EXPLAIN QUERY PLAN.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_stmt_isexplain")(pStmt)
        except:
            os.abort("sqlite3_stmt_isexplain: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_stmt_busy(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_stmt_busy")(pStmt)
        except:
            os.abort("sqlite3_stmt_busy: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_blob64[
        value_origin: ImmOrigin, //
    ](
        self,
        pStmt: Optional[MutExternalPointer[sqlite3_stmt]],
        idx: c_int,
        value: ImmOpaquePointer[value_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_blob64")(pStmt, idx, value.unsafe_origin_cast[MutUntrackedOrigin](), n, destructor_callback)
        except:
            os.abort("sqlite3_bind_blob64: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_double(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int, value: Float64) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_double")(pStmt, idx, value)
        except:
            os.abort("sqlite3_bind_double: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_int64(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int, value: Int64) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_int64")(pStmt, idx, value)
        except:
            os.abort("sqlite3_bind_int64: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_null(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int) -> c_int:
        """Binding Values To Prepared Statements - NULL.

        This routine binds a NULL value to a parameter in a prepared statement.
        The parameter is identified by its index (1-based).

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_null")(pStmt, idx)
        except:
            os.abort("sqlite3_bind_null: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_text64[
        value_origin: ImmOrigin, //
    ](
        self,
        pStmt: Optional[MutExternalPointer[sqlite3_stmt]],
        idx: c_int,
        value: ImmPointer[c_char, value_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_text64")(pStmt, idx, value.unsafe_origin_cast[MutUntrackedOrigin](), n, destructor_callback, encoding)
        except:
            os.abort("sqlite3_bind_text64: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_pointer[
        value_origin: MutOrigin,
        type_origin: ImmOrigin,
        //
    ](
        self,
        pStmt: Optional[MutExternalPointer[sqlite3_stmt]],
        idx: c_int,
        value: MutOpaquePointer[value_origin],
        typeStr: ImmPointer[c_char, type_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_pointer")(pStmt, idx, value.unsafe_origin_cast[MutUntrackedOrigin](), typeStr.unsafe_origin_cast[MutUntrackedOrigin](), destructor_callback)
        except:
            os.abort("sqlite3_bind_pointer: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_zeroblob(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int, n: c_int) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_zeroblob")(pStmt, idx, n)
        except:
            os.abort("sqlite3_bind_zeroblob: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_parameter_count(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
        """Return the number of parameters in a prepared statement.

        This function returns the number of SQL parameters in the prepared
        statement. SQL parameters are tokens such as "?" or ":name" or "$var"
        that are used to substitute values at runtime.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            The number of SQL parameters in the prepared statement.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_parameter_count")(pStmt)
        except:
            os.abort("sqlite3_bind_parameter_count: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_parameter_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> Optional[ImmExternalPointer[c_char]]:
        """Name Of A Host Parameter.

        This routine returns a pointer to the name of the N-th SQL parameter
        in the prepared statement. SQL parameters of the form "?NNN" or ":AAA"
        or "@AAA" or "$AAA" have a name which is the string "?NNN" or ":AAA"
        or "@AAA" or "$AAA" respectively. Parameters of the form "?" without
        a following integer have no name and this routine returns None.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the parameter (1-based).

        Returns:
            Pointer to parameter name, or None if no name or invalid index.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_bind_parameter_name")(pStmt, idx)
        except:
            os.abort("sqlite3_bind_parameter_name: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_bind_parameter_index[origin: ImmOrigin, //](
        self, pStmt: MutExternalPointer[sqlite3_stmt], zName: ImmPointer[c_char, origin]
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
        try:
            return self.lib.get_function[c_int]("sqlite3_bind_parameter_index")(pStmt, zName.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_bind_parameter_index: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_clear_bindings(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
        """Reset All Bindings On A Prepared Statement.

        Contrary to the intuition of many, sqlite3_reset() does not reset
        the bindings on a prepared statement. This routine resets all
        parameters to NULL.

        Args:
            pStmt: Prepared statement.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_clear_bindings")(pStmt)
        except:
            os.abort("sqlite3_clear_bindings: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_count(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
        """Return the number of columns in a result set.

        This function returns the number of columns in the result set returned
        by the prepared statement. This value does not change from one execution
        of the prepared statement to the next.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            The number of columns in the result set.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_column_count")(pStmt)
        except:
            os.abort("sqlite3_column_count: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_name(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], N: c_int) -> Optional[ImmExternalPointer[c_char]]:
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
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_column_name")(pStmt, N)
        except:
            os.abort("sqlite3_column_name: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_database_name(
        self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int
    ) -> Optional[ImmExternalPointer[c_char]]:
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
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_column_database_name")(pStmt, idx)
        except:
            os.abort("sqlite3_column_database_name: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_table_name(
        self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int
    ) -> Optional[ImmExternalPointer[c_char]]:
        """Source Of Data In A Query Result.

        This routine returns the name of the table that is the origin of a
        particular result column in a SELECT statement. This routine requires
        that SQLite be compiled with the SQLITE_ENABLE_COLUMN_METADATA
        preprocessor symbol.

        If the Nth column returned by the statement is an expression or subquery
        and is not a column value, then the function returns None.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the table name or None if the column is an expression or subquery.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_column_table_name")(pStmt, idx)
        except:
            os.abort("sqlite3_column_table_name: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_origin_name(
        self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], idx: c_int
    ) -> Optional[ImmExternalPointer[c_char]]:
        """Source Of Data In A Query Result.

        This routine returns the name of the table column that is the origin
        of a particular result column in a SELECT statement. This routine
        requires that SQLite be compiled with the SQLITE_ENABLE_COLUMN_METADATA
        preprocessor symbol.

        If the Nth column returned by the statement is an expression or subquery
        and is not a column value, then the function returns None.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the origin column name or None if the column is an expression or subquery.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_column_origin_name")(pStmt, idx)
        except:
            os.abort("sqlite3_column_origin_name: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_decltype(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> Optional[ImmExternalPointer[c_char]]:
        """Declared Datatype Of A Query Result.

        This routine returns the declared datatype of a result column. The
        returned string is UTF-8 encoded and is the datatype declaration as
        it appears in the CREATE TABLE statement. For example, in the database
        schema "CREATE TABLE t1(c1 VARIANT)", the declared type of column c1
        is "VARIANT". If the Nth column of the result set is an expression or subquery,
        then a NULL pointer is returned. The returned string is always UTF-8 encoded.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            Pointer to the declared datatype string, or None if the column is an expression or subquery.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_column_decltype")(pStmt, idx)
        except:
            os.abort("sqlite3_column_decltype: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_step(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_step")(pStmt)
        except:
            os.abort("sqlite3_step: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_blob(
        self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int
    ) -> Optional[ImmExternalPointer[NoneType]]:
        """Result Values From A Query - BLOB.

        These routines return information about a single column of the current
        result row of a query. This routine returns the value of the specified
        column as a BLOB (Binary Large OBject).

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Pointer to the BLOB data, or None if the column is NULL.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[NoneType]]]("sqlite3_column_blob")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_blob: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_double(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int) -> Float64:
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
        try:
            return self.lib.get_function[Float64]("sqlite3_column_double")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_double: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_int64(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int) -> Int64:
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
        try:
            return self.lib.get_function[Int64]("sqlite3_column_int64")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_int64: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_text(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int) -> Optional[ImmExternalPointer[c_uchar]]:
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
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_uchar]]]("sqlite3_column_text")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_text: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_value(
        self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int
    ) -> Optional[MutExternalPointer[sqlite3_value]]:
        """Result Values From A Query - Unprotected sqlite3_value.

        This routine returns the sqlite3_value object for the specified column.
        The returned value is unprotected, meaning it is only valid until the
        next call to sqlite3_step() or sqlite3_reset(). Use sqlite3_value_*()
        functions to extract information from the returned value.

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Pointer to the sqlite3_value object for the column or None if the column is out of range or an OOM error occurs.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[sqlite3_value]]]("sqlite3_column_value")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_value: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_bytes(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int) -> c_int:
        """Size Of A BLOB Or TEXT Result In Bytes.

        This routine returns the number of bytes in a BLOB or TEXT result.
        For BLOBs, this is the exact size. For TEXT, this is the number of
        bytes in the UTF-8 encoding. This routine must be called after
        sqlite3_column_blob() or sqlite3_column_text().

        Args:
            pStmt: Prepared statement being evaluated.
            iCol: Index of the column (leftmost column is 0).

        Returns:
            Number of bytes in the BLOB or TEXT value or 0 if the column is NULL.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_column_bytes")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_bytes: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_column_type(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]], iCol: c_int) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_column_type")(pStmt, iCol)
        except:
            os.abort("sqlite3_column_type: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_finalize(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_finalize")(pStmt)
        except:
            os.abort("sqlite3_finalize: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_reset(self, pStmt: Optional[MutExternalPointer[sqlite3_stmt]]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_reset")(pStmt)
        except:
            os.abort("sqlite3_reset: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_remove_function[
        fn_name_origin: ImmOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
    ) -> c_int:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. The function
        registers scalar or aggregate functions with a database connection.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        var eTextRep = c_int(0)
        try:
            return self.lib.get_function[c_int]("sqlite3_create_function_v2")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                None,
                None,
                None,
                None,
                None
            )
        except:
            os.abort("sqlite3_remove_function: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_scalar_function[
        fn_name_origin: ImmOrigin,
        app_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xFunc: ScalarFnCallback,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Adds a scalar SQL function or redefines the behavior of an existing scalar SQL function.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            pApp: User data pointer passed to function callbacks.
            xFunc: Scalar function implementation.
            destructor_callback: Destructor for pApp when function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_create_function_v2")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                pApp.unsafe_origin_cast[MutUntrackedOrigin](),
                xFunc,
                None,
                None,
                destructor_callback
            )
        except:
            os.abort("sqlite3_create_scalar_function: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_scalar_function[
        fn_name_origin: ImmOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        xFunc: ScalarFnCallback,
    ) -> c_int:
        """Adds a scalar SQL function or redefines the behavior of an existing scalar SQL function.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            xFunc: Scalar function implementation (NULL for aggregates).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_create_function_v2")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                None,
                xFunc,
                None,
                None,
                None
            )
        except:
            os.abort("sqlite3_create_scalar_function: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_aggregate_function[
        fn_name_origin: ImmOrigin,
        app_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Adds an aggregate SQL function or redefines the behavior of an existing aggregate SQL function.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            pApp: User data pointer passed to function callbacks.
            xStep: Aggregate step function.
            xFinal: Aggregate finalization function.
            destructor_callback: Destructor for pApp when function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_create_function_v2")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                pApp.unsafe_origin_cast[MutUntrackedOrigin](),
                None,
                xStep,
                xFinal,
                destructor_callback
            )
        except:
            os.abort("sqlite3_create_aggregate_function: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_aggregate_function[
        fn_name_origin: ImmOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
    ) -> c_int:
         """Adds an aggregate SQL function or redefines the behavior of an existing aggregate SQL function.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            xStep: Aggregate step function.
            xFinal: Aggregate finalization function.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_create_function_v2")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                None,
                None,
                xStep,
                xFinal,
                None
            )
        except:
            os.abort("sqlite3_create_aggregate_function: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_window_function[
        fn_name_origin: ImmOrigin,
        app_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
        xValue: WindowValueCallback,
        xInverse: WindowInverseCallback,
        destructor_callback: ResultDestructorFn,
    ) -> c_int:
        """Adds an window aggregate SQL function or redefines the behavior of an existing window aggregate SQL function.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding and other flags (SQLITE_UTF8, etc.).
            pApp: User data pointer passed to function callbacks.
            xStep: Aggregate step function.
            xFinal: Aggregate finalization function.
            xValue: Window function value callback.
            xInverse: Window function inverse callback.
            destructor_callback: Destructor for pApp when function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_create_window_function")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                pApp.unsafe_origin_cast[MutUntrackedOrigin](),
                xStep,
                xFinal,
                xValue,
                xInverse,
                destructor_callback
            )
        except:
            os.abort("sqlite3_create_window_function: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_window_function[
        fn_name_origin: ImmOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFunctionName: ImmPointer[c_char, fn_name_origin],
        nArg: c_int,
        eTextRep: c_int,
        xStep: AggStepCallback,
        xFinal: AggFinalCallback,
        xValue: WindowValueCallback,
        xInverse: WindowInverseCallback,
    ) -> c_int:
        """Adds an window aggregate SQL function or redefines the behavior of an existing window aggregate SQL function.

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
        try:
            return self.lib.get_function[c_int]("sqlite3_create_window_function")(
                db,
                zFunctionName.unsafe_origin_cast[MutUntrackedOrigin](),
                nArg,
                eTextRep,
                None,
                xStep,
                xFinal,
                xValue,
                xInverse,
                None
            )
        except:
            os.abort("sqlite3_create_window_function: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_aggregate_count")(ctx)
        except:
            os.abort("sqlite3_aggregate_count: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_expired")(pStmt)
        except:
            os.abort("sqlite3_expired: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_transfer_bindings")(fromStmt, toStmt)
        except:
            os.abort("sqlite3_transfer_bindings: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_global_recover(self) -> c_int:
        """Attempt To Free Heap Memory (Deprecated).

        This function was used to attempt to recover from allocation failures.
        It is deprecated and may be removed in a future release. It always
        returns SQLITE_OK and does nothing.

        Returns:
            Always returns SQLITE_OK.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_global_recover")()
        except:
            os.abort("sqlite3_global_recover: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_thread_cleanup(self):
        """Clean Up Thread-Local Storage (Deprecated).

        This function was used to clean up thread-local storage for SQLite.
        It is deprecated and does nothing in modern versions of SQLite.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_thread_cleanup")()
        except:
            pass

    def sqlite3_memory_alarm[
        origin: MutOrigin, //
    ](
        self,
        callback: MemoryAlarmCallbackFn,
        arg: MutPointer[NoneType, origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_memory_alarm")(callback, arg.unsafe_origin_cast[MutUntrackedOrigin](), n)
        except:
            os.abort("sqlite3_memory_alarm: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_blob(self, value: MutExternalPointer[sqlite3_value]) -> Optional[ImmExternalPointer[NoneType]]:
        """Obtaining SQL Values - BLOB.

        This routine extracts a BLOB value from an sqlite3_value object.
        These routines are used to extract type, size, and content information
        from sqlite3_value objects that are passed as parameters to
        application-defined SQL functions.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Pointer to the BLOB data or None if the value is not a BLOB or an OOM error occurred.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[NoneType]]]("sqlite3_value_blob")(value)
        except:
            os.abort("sqlite3_value_blob: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_double(self, value: MutExternalPointer[sqlite3_value]) -> Float64:
        """Obtaining SQL Values - REAL.

        This routine extracts a floating point value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a double precision floating point number.
        """
        try:
            return self.lib.get_function[Float64]("sqlite3_value_double")(value)
        except:
            os.abort("sqlite3_value_double: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_int64(self, value: MutExternalPointer[sqlite3_value]) -> Int64:
        """Obtaining SQL Values - INTEGER (64-bit).

        This routine extracts a 64-bit signed integer value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a 64-bit signed integer.
        """
        try:
            return self.lib.get_function[Int64]("sqlite3_value_int64")(value)
        except:
            os.abort("sqlite3_value_int64: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_pointer[
        origin: ImmOrigin, //
    ](
        self, value: MutExternalPointer[sqlite3_value], typeStr: ImmPointer[c_char, origin]
    ) -> Optional[MutExternalPointer[NoneType]]:
        """Obtaining SQL Values - Pointer.

        This routine extracts a pointer value from an sqlite3_value object.
        The pointer is type-checked using the provided type string. Returns
        NULL if the value is not a pointer or if the type string doesn't match.

        Args:
            value: Pointer to the sqlite3_value object.
            typeStr: Type identifier string for type safety.

        Returns:
            The pointer value, or None if not a matching pointer type.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_value_pointer")(value, typeStr.unsafe_origin_cast[ImmUntrackedOrigin]())
        except:
            os.abort("sqlite3_value_pointer: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_text(self, value: MutExternalPointer[sqlite3_value]) -> Optional[ImmExternalPointer[c_uchar]]:
        """Obtaining SQL Values - TEXT.

        This routine extracts a UTF-8 text value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Pointer to the UTF-8 encoded text or None if the value is not text or an OOM error occurred.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_uchar]]]("sqlite3_value_text")(value)
        except:
            os.abort("sqlite3_value_text: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_bytes(self, value: MutExternalPointer[sqlite3_value]) -> c_int:
        """Size Of A BLOB Or TEXT Value In Bytes.

        This routine returns the number of bytes in a BLOB or TEXT value.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Number of bytes in the value.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_value_bytes")(value)
        except:
            os.abort("sqlite3_value_bytes: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_value_type(self, value: MutExternalPointer[sqlite3_value]) -> c_int:
        """Datatype Code For An sqlite3_value.

        This routine returns one of SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT,
        SQLITE_BLOB, or SQLITE_NULL, indicating the datatype of the value.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Datatype code.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_value_type")(value)
        except:
            os.abort("sqlite3_value_type: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_value_nochange")(value)
        except:
            os.abort("sqlite3_value_nochange: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_uint]("sqlite3_value_subtype")(value)
        except:
            os.abort("sqlite3_value_subtype: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_aggregate_context(
        self, ctx: MutExternalPointer[sqlite3_context], nBytes: c_int
    ) -> Optional[MutExternalPointer[NoneType]]:
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
            Pointer to aggregate context memory, or None if allocation fails.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_aggregate_context")(ctx, nBytes)
        except:
            os.abort("sqlite3_aggregate_context: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_user_data(self, ctx: MutExternalPointer[sqlite3_context]) -> Optional[MutExternalPointer[NoneType]]:
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
            User data pointer that was passed during function creation, or None if no user data was set.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_user_data")(ctx)
        except:
            os.abort("sqlite3_user_data: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_context_db_handle(
        self, ctx: MutExternalPointer[sqlite3_context]
    ) -> Optional[MutExternalPointer[sqlite3_connection]]:
        """Database Connection For Functions.

        This routine returns a copy of the pointer to the database connection
        (the 1st parameter) of the `sqlite3_create_function` or
        `sqlite3_create_function16` routine that originally registered the
        application defined function.

        Args:
            ctx: SQL function context pointer.

        Returns:
            Database connection handle or None if the context is invalid.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[sqlite3_connection]]]("sqlite3_context_db_handle")(ctx)
        except:
            os.abort("sqlite3_context_db_handle: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_get_auxdata(self, ctx: MutExternalPointer[sqlite3_context], N: c_int) -> Optional[MutExternalPointer[NoneType]]:
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
            Auxiliary data pointer, or None if none was set.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_get_auxdata")(ctx, N)
        except:
            os.abort("sqlite3_get_auxdata: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            self.lib.get_function[NoneType]("sqlite3_set_auxdata")(ctx, N, data.unsafe_origin_cast[MutUntrackedOrigin](), destructor_callback)
        except:
            pass

    def sqlite3_result_blob64[
        origin: ImmOrigin, //
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        value: ImmOpaquePointer[origin],
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
        try:
            self.lib.get_function[NoneType]("sqlite3_result_blob64")(ctx, value.unsafe_origin_cast[MutUntrackedOrigin](), n, destructor_callback)
        except:
            pass

    def sqlite3_result_double(self, ctx: MutExternalPointer[sqlite3_context], value: Float64):
        """Setting The Result Of An SQL Function - REAL.

        This routine sets the result of an application-defined SQL function to
        be a floating point value.

        Args:
            ctx: SQL function context pointer.
            value: The floating point value to return.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_double")(ctx, value)
        except:
            pass

    def sqlite3_result_error[
        origin: ImmOrigin, //
    ](self, ctx: MutExternalPointer[sqlite3_context], msg: ImmPointer[c_char, origin], n: c_int):
        """Setting The Result Of An SQL Function - Error.

        This routine causes the SQL function to terminate with an error. The
        error message is copied into memory obtained from sqlite3_malloc() so
        the original error message string can be deallocated after this routine
        returns.

        Args:
            ctx: SQL function context pointer.
            msg: Error message text (UTF-8).
            n: Length of error message in bytes, or -1 for None-terminated.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_error")(ctx, msg.unsafe_origin_cast[MutUntrackedOrigin](), n)
        except:
            pass

    def sqlite3_result_error_toobig(self, ctx: MutExternalPointer[sqlite3_context]):
        """Setting The Result Of An SQL Function - SQLITE_TOOBIG Error.

        This routine causes the SQL function to terminate with the error code
        SQLITE_TOOBIG, indicating that a string or BLOB is too large.

        Args:
            ctx: SQL function context pointer.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_error_toobig")(ctx)
        except:
            pass

    def sqlite3_result_error_nomem(self, ctx: MutExternalPointer[sqlite3_context]):
        """Setting The Result Of An SQL Function - SQLITE_NOMEM Error.

        This routine causes the SQL function to terminate with the error code
        SQLITE_NOMEM, indicating an out-of-memory condition.

        Args:
            ctx: SQL function context pointer.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_error_nomem")(ctx)
        except:
            pass

    def sqlite3_result_error_code(self, ctx: MutExternalPointer[sqlite3_context], code: c_int):
        """Setting The Result Of An SQL Function - Error Code.

        This routine changes the error code returned by the SQL function. By
        default, functions return SQLITE_ERROR, but this can be changed to any
        valid error code using this function.

        Args:
            ctx: SQL function context pointer.
            code: Error code to return (e.g., SQLITE_CONSTRAINT, SQLITE_BUSY).
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_error_code")(ctx, code)
        except:
            pass

    def sqlite3_result_int64(self, ctx: MutExternalPointer[sqlite3_context], value: Int64):
        """Setting The Result Of An SQL Function - INTEGER (64-bit).

        This routine sets the result of an application-defined SQL function to
        be a 64-bit signed integer value.

        Args:
            ctx: SQL function context pointer.
            value: The 64-bit integer value to return.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_int64")(ctx, value)
        except:
            pass

    def sqlite3_result_null(self, ctx: MutExternalPointer[sqlite3_context]):
        """Setting The Result Of An SQL Function - NULL.

        This routine sets the result of an application-defined SQL function to
        be NULL.

        Args:
            ctx: SQL function context pointer.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_null")(ctx)
        except:
            pass

    def sqlite3_result_text64[
        value_origin: ImmOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        value: ImmPointer[c_char, value_origin],
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
        try:
            self.lib.get_function[NoneType]("sqlite3_result_text64")(ctx, value.unsafe_origin_cast[MutUntrackedOrigin](), n, destructor_callback, encoding)
        except:
            pass

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
        try:
            self.lib.get_function[NoneType]("sqlite3_result_value")(ctx, value)
        except:
            pass

    def sqlite3_result_pointer[
        ptr_origin: MutOrigin,
        type_origin: ImmOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        ptr: MutOpaquePointer[ptr_origin],
        typeStr: ImmPointer[c_char, type_origin],
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
        try:
            self.lib.get_function[NoneType]("sqlite3_result_pointer")(ctx, ptr.unsafe_origin_cast[MutUntrackedOrigin](), typeStr.unsafe_origin_cast[MutUntrackedOrigin](), destructor_callback)
        except:
            pass

    def sqlite3_result_zeroblob(self, ctx: MutExternalPointer[sqlite3_context], n: c_int):
        """Setting The Result Of An SQL Function - Zeroblob.

        This routine sets the result of an application-defined SQL function to
        be a BLOB filled with zeros. The BLOB can later be opened and written
        to using the incremental BLOB I/O routines.

        Args:
            ctx: SQL function context pointer.
            n: Size of the zeroblob in bytes.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_zeroblob")(ctx, n)
        except:
            pass

    def sqlite3_result_subtype(self, ctx: MutExternalPointer[sqlite3_context], subtype: c_uint):
        """Setting The Subtype Of An SQL Function Result.

        This routine sets the subtype of the result value of an application-defined
        SQL function. The subtype information can be used to pass a limited amount
        of context from one SQL function to another.

        Args:
            ctx: SQL function context pointer.
            subtype: Subtype value to set (application-defined).
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_result_subtype")(ctx, subtype)
        except:
            pass

    def sqlite3_create_collation_v2[
        name_origin: ImmOrigin,
        arg_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zName: ImmPointer[c_char, name_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_create_collation_v2")(
                db,
                zName.unsafe_origin_cast[MutUntrackedOrigin](),
                eTextRep,
                pArg.unsafe_origin_cast[MutUntrackedOrigin](),
                xCompare,
                destructor_callback
            )
        except:
            os.abort("sqlite3_create_collation_v2: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_collation_needed")(db, pArg.unsafe_origin_cast[MutUntrackedOrigin](), callback)
        except:
            os.abort("sqlite3_collation_needed: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_soft_heap_limit")(n)
        except:
            os.abort("sqlite3_soft_heap_limit: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[Int64]("sqlite3_soft_heap_limit64")(n)
        except:
            os.abort("sqlite3_soft_heap_limit64: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_stmt_status")(pStmt, op, resetFlg)
        except:
            os.abort("sqlite3_stmt_status: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_table_column_metadata(
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDbName: Optional[ImmExternalPointer[c_char]],
        zTableName: ImmExternalPointer[c_char],
        zColumnName: Optional[ImmExternalPointer[c_char]],
        pzDataType: MutExternalPointer[Optional[ImmExternalPointer[c_char]]],
        pzCollSeq: MutExternalPointer[Optional[ImmExternalPointer[c_char]]],
        pNotNull: Optional[MutExternalPointer[c_int]],
        pPrimaryKey: Optional[MutExternalPointer[c_int]],
        pAutoinc: Optional[MutExternalPointer[c_int]],
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
        #     zDbName.unsafe_origin_cast[MutUntrackedOrigin](),
        #     zTableName.unsafe_origin_cast[MutUntrackedOrigin](),
        #     zColumnName.unsafe_origin_cast[MutUntrackedOrigin](),
        #     pzDataType.unsafe_origin_cast[MutUntrackedOrigin](),
        #     pzCollSeq.unsafe_origin_cast[MutUntrackedOrigin](),
        #     pNotNull.unsafe_origin_cast[MutUntrackedOrigin](),
        #     pPrimaryKey.unsafe_origin_cast[MutUntrackedOrigin](),
        #     pAutoinc.unsafe_origin_cast[MutUntrackedOrigin]()
        # )
        try:
            return self.lib.get_function[c_int]("sqlite3_table_column_metadata")(
                db, zDbName, zTableName, zColumnName, pzDataType, pzCollSeq, pNotNull, pPrimaryKey, pAutoinc
            )
        except:
            os.abort("sqlite3_table_column_metadata: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_load_extension[
        file_origin: ImmOrigin,
        err_msg_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zFile: ImmPointer[c_char, file_origin],
        zProc: Optional[ImmExternalPointer[c_char]],
        pzErrMsg: MutPointer[Optional[MutExternalPointer[c_char]], err_msg_origin],
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
        # return self._fn_sqlite3_load_extension(db, zFile.unsafe_origin_cast[MutUntrackedOrigin](), zProc.unsafe_origin_cast[MutUntrackedOrigin](), pzErrMsg.unsafe_origin_cast[MutUntrackedOrigin]())
        try:
            return self.lib.get_function[c_int]("sqlite3_load_extension")(db, zFile, zProc, pzErrMsg)
        except:
            os.abort("sqlite3_load_extension: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_enable_load_extension")(db, onoff)
        except:
            os.abort("sqlite3_enable_load_extension: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_get_autocommit")(db)
        except:
            os.abort("sqlite3_get_autocommit: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_db_handle(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> Optional[MutExternalPointer[sqlite3_connection]]:
        """Find The Database Handle Of A Prepared Statement.

        This routine returns the database connection pointer that was used to
        create the prepared statement using sqlite3_prepare_v2() or its variants.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Database connection handle that owns the statement, or None if the statement is invalid.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[sqlite3_connection]]]("sqlite3_db_handle")(pStmt)
        except:
            os.abort("sqlite3_db_handle: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_db_name(self, db: MutExternalPointer[sqlite3_connection], N: c_int) -> Optional[ImmExternalPointer[c_char]]:
        """Return The Schema Name For A Database.

        This routine returns the schema name for the N-th database on the
        database connection. The main database file has index 0, the temp
        database has index 1. Additional databases (attached via ATTACH)
        have indices starting at 2.

        Args:
            db: Database connection handle.
            N: Database index (0 for main, 1 for temp, 2+ for attached).

        Returns:
            Pointer to the schema name, or None if N is out of range.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_db_name")(db, N)
        except:
            os.abort("sqlite3_db_name: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_db_filename[
        origin: ImmOrigin, //
    ](
        self, db: MutExternalPointer[sqlite3_connection], zDbName: ImmPointer[c_char, origin]
    ) -> Optional[ImmExternalPointer[c_char]]:
        """Return The Filename For A Database.

        This routine returns the filename for the database schema specified
        by zDbName. The filename is returned as UTF-8. If the schema does
        not exist or if it is an in-memory or temporary database, this
        routine returns NULL or an empty string.

        Args:
            db: Database connection handle.
            zDbName: Name of the database schema.

        Returns:
            Pointer to the filename, or None if not found or an empty string if the database is in-memory or temporary.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_db_filename")(db, zDbName.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_db_filename: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_db_readonly[
        origin: ImmOrigin, //
    ](self, db: MutExternalPointer[sqlite3_connection], zDbName: ImmPointer[c_char, origin]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_db_readonly")(db, zDbName.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_db_readonly: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_txn_state[
        origin: ImmOrigin, //
    ](self, db: MutExternalPointer[sqlite3_connection], zSchema: ImmPointer[c_char, origin]) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_txn_state")(db, zSchema.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_txn_state: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_next_stmt(
        self, pDb: MutExternalPointer[sqlite3_connection], pStmt: Optional[MutExternalPointer[sqlite3_stmt]]
    ) -> Optional[MutExternalPointer[sqlite3_stmt]]:
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
            Pointer to next prepared statement, or None if none.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[sqlite3_stmt]]]("sqlite3_next_stmt")(pDb, pStmt)
        except:
            os.abort("sqlite3_next_stmt: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_update_hook(
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: Optional[MutExternalPointer[UpdateHookCallbackFn]],
        pArg: Optional[MutExternalPointer[NoneType]],
    ) -> None:
        """Data Change Notification Callbacks.

        This routine registers a callback function with the database connection
        that is invoked whenever a row is updated, inserted, or deleted in a
        rowid table. The callback is invoked before the change is committed.
        The callback receives the operation type (INSERT, UPDATE, or DELETE),
        database name, table name, and rowid of the affected row.

        Passing `None` for `xCallback` unregisters any existing update hook.

        Args:
            db: Database connection handle.
            xCallback: Callback function to invoke on data changes, or `None` to clear.
            pArg: User data pointer passed to callback, or `None`.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_update_hook")(db, xCallback, pArg)
        except:
            pass

    def sqlite3_commit_hook(
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: Optional[MutExternalPointer[CommitHookCallbackFn]],
        pArg: Optional[MutExternalPointer[NoneType]],
    ) -> Optional[MutExternalPointer[NoneType]]:
        """Commit And Rollback Notification Callbacks.

        This routine registers a callback function to be invoked whenever a
        transaction is committed. The callback can return non-zero to convert
        the commit into a rollback. This is useful for implementing custom
        constraints or synchronization logic.

        Passing `None` for `xCallback` unregisters any existing commit hook.

        Args:
            db: Database connection handle.
            xCallback: Callback function invoked before commit, or `None` to clear.
            pArg: User data pointer passed to callback, or `None`.

        Returns:
            Previously registered user data pointer or None if no previous callback was registered.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_commit_hook")(db, xCallback, pArg)
        except:
            os.abort("sqlite3_commit_hook: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_rollback_hook(
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: Optional[MutExternalPointer[RollbackHookCallbackFn]],
        pArg: Optional[MutExternalPointer[NoneType]],
    ) -> Optional[MutExternalPointer[NoneType]]:
        """Commit And Rollback Notification Callbacks.

        This routine registers a callback function to be invoked whenever a
        transaction is rolled back. The callback is invoked after the rollback
        has completed. This is useful for cleanup or logging purposes.

        Passing `None` for `xCallback` unregisters any existing rollback hook.

        Args:
            db: Database connection handle.
            xCallback: Callback function invoked after rollback, or `None` to clear.
            pArg: User data pointer passed to callback, or `None`.

        Returns:
            Previously registered user data pointer or None if no previous callback was registered.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_rollback_hook")(db, xCallback, pArg)
        except:
            os.abort("sqlite3_rollback_hook: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_auto_extension")(xEntryPoint)
        except:
            os.abort("sqlite3_auto_extension: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_db_release_memory")(db)
        except:
            os.abort("sqlite3_db_release_memory: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_cancel_auto_extension[
        origin: MutOrigin, //
    ](self, xEntryPoint: MutPointer[CancelExtensionCallbackFn, origin]) -> c_int:
        """Cancel An Auto-Extension.

        This routine unregisters an extension entry point that was previously
        registered using sqlite3_auto_extension(). The extension will no longer
        be automatically loaded into new database connections.

        Args:
            xEntryPoint: Extension initialization function to unregister.

        Returns:
            1 if the extension was found and canceled, 0 otherwise.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_cancel_auto_extension")(
                xEntryPoint.unsafe_origin_cast[MutUntrackedOrigin]()
            )
        except:
            os.abort("sqlite3_cancel_auto_extension: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_reset_auto_extension(self) -> c_int:
        """Reset The Automatic Extension Loading.

        This routine disables all automatic extensions previously registered
        using sqlite3_auto_extension(). This is useful when shutting down
        the application or when you want to start fresh with a new set of
        auto-extensions.

        Returns:
            Always returns SQLITE_OK.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_reset_auto_extension")()
        except:
            os.abort("sqlite3_reset_auto_extension: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_create_module_v2[
        name_origin: ImmOrigin,
        module_origin: MutOrigin,
        client_data_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zName: ImmPointer[c_char, name_origin],
        p: MutPointer[sqlite3_module, module_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_create_module_v2")(
                db,
                zName.unsafe_origin_cast[MutUntrackedOrigin](),
                p,
                pClientData.unsafe_origin_cast[MutUntrackedOrigin](),
                destructor_callback
            )
        except:
            os.abort("sqlite3_create_module_v2: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_blob_open[
        db_origin: ImmOrigin, table_origin: ImmOrigin, column_origin: ImmOrigin, blob_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDb: ImmPointer[c_char, db_origin],
        zTable: ImmPointer[c_char, table_origin],
        zColumn: ImmPointer[c_char, column_origin],
        iRow: Int64,
        flags: c_int,
        ppBlob: MutPointer[MutExternalPointer[sqlite3_blob], blob_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_blob_open")(db, zDb.unsafe_origin_cast[MutUntrackedOrigin](), zTable.unsafe_origin_cast[MutUntrackedOrigin](), zColumn.unsafe_origin_cast[MutUntrackedOrigin](), iRow, flags, ppBlob.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_blob_open: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_blob_reopen")(pBlob, iRow)
        except:
            os.abort("sqlite3_blob_reopen: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_blob_close")(pBlob)
        except:
            os.abort("sqlite3_blob_close: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_blob_bytes")(pBlob)
        except:
            os.abort("sqlite3_blob_bytes: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_blob_read")(pBlob, Z.unsafe_origin_cast[MutUntrackedOrigin](), N, iOffset)
        except:
            os.abort("sqlite3_blob_read: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_blob_write")(pBlob, z.unsafe_origin_cast[MutUntrackedOrigin](), n, iOffset)
        except:
            os.abort("sqlite3_blob_write: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_file_control[
        db_name_origin: ImmOrigin,
        arg_origin: MutOrigin,
        //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDbName: ImmPointer[c_char, db_name_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_file_control")(db, zDbName.unsafe_origin_cast[MutUntrackedOrigin](), op, pArg.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_file_control: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_backup_init[
        dest_name_origin: ImmOrigin,
        source_name_origin: ImmOrigin,
        //
    ](
        self,
        pDest: MutExternalPointer[sqlite3_connection],
        zDestName: ImmPointer[c_char, dest_name_origin],
        pSource: MutExternalPointer[sqlite3_connection],
        zSourceName: ImmPointer[c_char, source_name_origin],
    ) -> Optional[MutExternalPointer[sqlite3_backup]]:
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
            Backup handle, or None on error.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[sqlite3_backup]]]("sqlite3_backup_init")(pDest, zDestName.unsafe_origin_cast[MutUntrackedOrigin](), pSource, zSourceName.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_backup_init: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_backup_step")(p, nPage)
        except:
            os.abort("sqlite3_backup_step: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_backup_finish")(p)
        except:
            os.abort("sqlite3_backup_finish: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_backup_remaining")(p)
        except:
            os.abort("sqlite3_backup_remaining: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_backup_pagecount")(p)
        except:
            os.abort("sqlite3_backup_pagecount: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_unlock_notify")(
                pBlocked,
                xNotify,
                pNotifyArg.unsafe_origin_cast[MutUntrackedOrigin]()
            )
        except:
            os.abort("sqlite3_unlock_notify: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_log[origin: ImmOrigin, //](self, iErrCode: c_int, zFormat: ImmPointer[c_char, origin]):
        """Error Logging Interface.

        This routine is used by SQLite internally to log error and warning
        messages. Applications can also use this interface to write messages
        to the SQLite error log. The format string and arguments follow
        printf conventions.

        Args:
            iErrCode: Error code associated with the message.
            zFormat: Printf-style format string.
        """
        try:
            self.lib.get_function[NoneType]("sqlite3_log")(iErrCode, zFormat.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            pass

    def sqlite3_wal_hook[
        arg_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: WALHookCallbackFn,
        pArg: MutOpaquePointer[arg_origin],
    ) -> Optional[MutExternalPointer[NoneType]]:
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
            Previously registered user data pointer or None if no previous callback was registered.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[NoneType]]]("sqlite3_wal_hook")(
                db,
                xCallback,
                pArg.unsafe_origin_cast[MutUntrackedOrigin]()
            )
        except:
            os.abort("sqlite3_wal_hook: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_wal_autocheckpoint")(db, N)
        except:
            os.abort("sqlite3_wal_autocheckpoint: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_wal_checkpoint(self, db: MutExternalPointer[sqlite3_connection], zDb: Optional[ImmExternalPointer[c_char]] = None) -> c_int:
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
        try:
            return self.lib.get_function[c_int]("sqlite3_wal_checkpoint")(db, zDb)
        except:
            os.abort("sqlite3_wal_checkpoint: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_wal_checkpoint_v2[log_origin: MutOrigin, checkpoint_origin: MutOrigin, //](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zDb: Optional[ImmExternalPointer[c_char]],
        eMode: c_int,
        pnLog: MutPointer[c_int, log_origin],
        pnCkpt: MutPointer[c_int, checkpoint_origin],
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
            pnLog: OUT: Total frames in WAL after checkpoint (or None).
            pnCkpt: OUT: Frames checkpointed (or None).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_wal_checkpoint_v2")(db, zDb, eMode, pnLog.unsafe_origin_cast[MutUntrackedOrigin](), pnCkpt.unsafe_origin_cast[MutUntrackedOrigin]())
        except:
            os.abort("sqlite3_wal_checkpoint_v2: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_vtab_config")(db, op)
        except:
            os.abort("sqlite3_vtab_config: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_vtab_on_conflict")(db)
        except:
            os.abort("sqlite3_vtab_on_conflict: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_vtab_nochange")(ctx)
        except:
            os.abort("sqlite3_vtab_nochange: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_vtab_collation(
        self, pIdxInfo: MutExternalPointer[sqlite3_index_info], iCons: c_int
    ) -> Optional[ImmExternalPointer[c_char]]:
        """Get Collation For A Virtual Table Constraint.

        This function is used within the xBestIndex method of a virtual table
        implementation to determine the collation sequence for a constraint.
        The function returns the name of the collation sequence or None if
        the constraint has no explicit collation.

        Args:
            pIdxInfo: Virtual table index information structure.
            iCons: Index of the constraint in the aConstraint array.

        Returns:
            Name of the collation sequence, or None if an OOM error occurs or if the constraint has no explicit collation.
        """
        try:
            return self.lib.get_function[Optional[ImmExternalPointer[c_char]]]("sqlite3_vtab_collation")(pIdxInfo, iCons)
        except:
            os.abort("sqlite3_vtab_collation: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_vtab_distinct")(pIdxInfo)
        except:
            os.abort("sqlite3_vtab_distinct: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_declare_vtab[sql_origin: ImmOrigin, //](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSQL: ImmPointer[c_char, sql_origin],
    ) -> c_int:
        """Declare The Schema Of A Virtual Table.

        This interface is used within the xCreate or xConnect methods of
        a virtual table module to declare the schema of the virtual table.
        The zSQL argument must be a CREATE TABLE SQL statement that describes
        the virtual table's columns and their declared types.

        This function must be called exactly once per invocation of
        xCreate or xConnect.

        Args:
            db: Database connection passed to xCreate or xConnect.
            zSQL: CREATE TABLE statement describing the virtual table schema.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        try:
            return self.lib.get_function[c_int]("sqlite3_declare_vtab")(db, zSQL)
        except:
            os.abort("sqlite3_declare_vtab: symbol not found in libsqlite3 (should have been validated in __init__)")

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
        try:
            return self.lib.get_function[c_int]("sqlite3_db_cacheflush")(db)
        except:
            os.abort("sqlite3_db_cacheflush: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_serialize[
        schema_origin: ImmOrigin,
        size_origin: MutOrigin,
        //,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSchema: ImmPointer[c_char, schema_origin],
        piSize: MutPointer[Int64, size_origin],
        mFlags: c_uint,
    ) -> Optional[MutExternalPointer[c_uchar]]:
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
            Pointer to serialized database, or None on error.
        """
        try:
            return self.lib.get_function[Optional[MutExternalPointer[c_uchar]]]("sqlite3_serialize")(db, zSchema.unsafe_origin_cast[MutUntrackedOrigin](), piSize.unsafe_origin_cast[MutUntrackedOrigin](), mFlags)
        except:
            os.abort("sqlite3_serialize: symbol not found in libsqlite3 (should have been validated in __init__)")

    def sqlite3_deserialize[
        schema_origin: ImmOrigin,
        data_origin: MutOrigin, //
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSchema: ImmPointer[c_char, schema_origin],
        pData: MutPointer[c_uchar, data_origin],
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
        try:
            return self.lib.get_function[c_int]("sqlite3_deserialize")(
                db,
                zSchema.unsafe_origin_cast[MutUntrackedOrigin](),
                pData.unsafe_origin_cast[MutUntrackedOrigin](),
                szDb,
                szBuf,
                mFlags
            )
        except:
            os.abort("sqlite3_deserialize: symbol not found in libsqlite3 (should have been validated in __init__)")
