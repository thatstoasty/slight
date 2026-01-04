from slight.c.raw_bindings import _sqlite3
from slight.result import SQLite3Result
from pathlib import Path
from sys.ffi import c_char, c_int, c_uint, c_uchar

from memory import MutOpaquePointer, MutUnsafePointer
from slight.c.types import (
    sqlite3_backup,
    sqlite3_blob,
    sqlite3_connection,
    sqlite3_context,
    ResultDestructorFn,
    AuthCallbackFn,
    sqlite3_file,
    sqlite3_index_info,
    sqlite3_snapshot,
    sqlite3_stmt,
    sqlite3_value,
    ImmutExternalPointer,
    MutExternalPointer,
    DataType,
    TextEncoding,
)
from slight.c.sqlite_string import SQLiteMallocString


struct sqlite3:
    """SQLite3 C API binding struct.

    This struct provides a high-level interface to the SQLite3 C library
    by dynamically loading the shared library and exposing the C functions
    as Mojo methods. It handles the FFI (Foreign Function Interface) calls
    to the underlying SQLite3 C implementation.
    """

    var lib: _sqlite3

    fn __init__(out self):
        self.lib = _sqlite3()

    fn version(self) -> ImmutExternalPointer[c_char]:
        """Get the SQLite library version string.

        Returns a pointer to a string containing the version of the SQLite
        library that is running. This corresponds to the SQLITE_VERSION
        string.

        Returns:
            StringSlice containing the SQLite version.
        """
        return self.lib.sqlite3_libversion()

    fn source_id(self) -> ImmutExternalPointer[c_char]:
        """Get the SQLite source ID.

        Returns a pointer to a string containing the date and time of
        the check-in (UTC) and a SHA1 hash of the entire source tree.

        Returns:
            StringSlice containing the SQLite source identifier.
        """
        return self.lib.sqlite3_sourceid()

    fn library_version_number(self) -> c_int:
        """Get the SQLite library version number.

        Returns an integer equal to SQLITE_VERSION_NUMBER. The version
        number is in the format (X*1000000 + Y*1000 + Z) where X, Y, and Z
        are the major, minor, and release numbers respectively.

        Returns:
            The SQLite library version as an integer.
        """
        return self.lib.sqlite3_libversion_number()
 
    fn test_thread_safety(self) -> SQLite3Result:
        """Test if the library is threadsafe.

        Returns zero if and only if SQLite was compiled with mutexing code
        omitted due to the SQLITE_THREADSAFE compile-time option being set to 0.

        Returns:
            Non-zero if SQLite is threadsafe, 0 if not threadsafe.
        """
        return self.lib.sqlite3_threadsafe()

    fn close(self, connection: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
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
        from [sqlite3_open()], [sqlite3_open16()], or
        [sqlite3_open_v2()], and not previously closed.
        ^Calling `sqlite3_close()` or `sqlite3_close_v2()` with a NULL pointer
        argument is a harmless no-op.
        """
        return self.lib.sqlite3_close(connection)

    fn configure_sqlite(self, op: c_int) -> SQLite3Result:
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
        return self.lib.sqlite3_config(op)

    fn configure_database_connection(self, db: MutExternalPointer[sqlite3_connection], op: c_int) -> SQLite3Result:
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
        return self.lib.sqlite3_db_config(db, op)

    fn extended_result_codes(self, db: MutExternalPointer[sqlite3_connection], onoff: c_int) -> SQLite3Result:
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
        return self.lib.sqlite3_extended_result_codes(db, onoff)

    fn last_insert_rowid(self, db: MutExternalPointer[sqlite3_connection]) -> Int64:
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
        return self.lib.sqlite3_last_insert_rowid(db)

    fn changes(self, db: MutExternalPointer[sqlite3_connection]) -> Int32:
        """Count The Number of Rows Modified.

        This function returns the number of rows modified, inserted or deleted
        by the most recently completed INSERT, UPDATE, or DELETE statement on
        the database connection specified in the first argument.

        Args:
            db: Database connection handle.

        Returns:
            Number of rows changed by the most recent INSERT, UPDATE, or DELETE.
        """
        return self.lib.sqlite3_changes(db)

    fn changes64(self, db: MutExternalPointer[sqlite3_connection]) -> Int64:
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
        return self.lib.sqlite3_changes64(db)

    fn total_changes(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
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
        return self.lib.sqlite3_total_changes(db)

    fn total_changes64(self, db: MutExternalPointer[sqlite3_connection]) -> Int64:
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
        return self.lib.sqlite3_total_changes64(db)

    fn interrupt(self, db: MutExternalPointer[sqlite3_connection]) -> None:
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
        self.lib.sqlite3_interrupt(db)

    fn is_interrupted(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
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
        return self.lib.sqlite3_is_interrupted(db)

    fn busy_handler[
        cb_origin: MutOrigin,
        arg_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        callback: fn (MutOpaquePointer[cb_origin], c_int) -> c_int,
        arg: MutOpaquePointer[arg_origin],
    ) -> SQLite3Result:
        return self.lib.sqlite3_busy_handler(db, callback, arg)

    fn busy_timeout(self, db: MutExternalPointer[sqlite3_connection], ms: c_int) -> SQLite3Result:
        """Set A Busy Timeout.

        This routine sets a busy handler that sleeps for a specified amount of time
        when a table is locked.

        Args:
            db: Database connection.
            ms: Timeout in milliseconds.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_busy_timeout(db, ms)

    fn malloc64(self, size: UInt64) -> MutExternalPointer[NoneType]:
        """Allocate Memory (64-bit).

        This routine allocates memory using SQLite's memory allocation subsystem.

        Args:
            size: Number of bytes to allocate.

        Returns:
            Pointer to allocated memory or NULL on failure.
        """
        return self.lib.sqlite3_malloc64(size)

    fn free[origin: MutOrigin](self, ptr: MutOpaquePointer[origin]):
        """Free Memory.

        This routine frees memory that was obtained from malloc64.

        Args:
            ptr: Pointer to memory to free.
        """
        self.lib.sqlite3_free(ptr)

    fn msize[origin: MutOrigin](self, ptr: MutOpaquePointer[origin]) -> UInt64:
        """Memory Size.

        This routine returns the size of a memory allocation obtained from malloc64.

        Args:
            ptr: Pointer to allocated memory.

        Returns:
            Size of the allocation in bytes.
        """
        return self.lib.sqlite3_msize(ptr)

    fn set_authorizer[
        origin: MutOrigin,
        origin2: ImmutOrigin,
        origin3: ImmutOrigin,
        origin4: ImmutOrigin,
        origin5: ImmutOrigin,
        auth_callback: AuthCallbackFn,
        userdata_origin: MutOrigin,
    ](self, db: MutExternalPointer[sqlite3_connection], pUserData: MutOpaquePointer[userdata_origin],) -> SQLite3Result:
        """Register An Authorizer Callback.

        This routine registers a callback function to be invoked by SQLite whenever
        it tries to access a database or perform certain operations. The callback
        can approve, deny, or ignore the action.

        Args:
            db: Database connection.
            pUserData: User data pointer passed to the callback.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_set_authorizer[origin, origin2, origin3, origin4, origin5, auth_callback](db, pUserData)

    fn trace[
        origin: MutOrigin, origin2: ImmutOrigin, arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xTrace: fn (MutOpaquePointer[origin], ImmutUnsafePointer[c_char, origin2]) -> NoneType,
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Register A Trace Callback (Deprecated).

        This routine registers a callback function to be invoked for each SQL
        statement as it is executed. This function is deprecated - use trace_v2 instead.

        Args:
            db: Database connection.
            xTrace: Callback function invoked for each SQL statement.
            pArg: User data pointer passed to callback.

        Returns:
            Pointer to the previous trace callback data.
        """
        return self.lib.sqlite3_trace(db, xTrace, pArg)

    fn profile[
        origin: MutOrigin, origin2: ImmutOrigin, arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xProfile: fn (MutOpaquePointer[origin], ImmutUnsafePointer[c_char, origin2], UInt64) -> NoneType,
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Register A Profile Callback (Deprecated).

        This routine registers a callback function to be invoked when each SQL
        statement finishes, providing execution time information. This function
        is deprecated - use trace_v2 instead.

        Args:
            db: Database connection.
            xProfile: Callback function invoked when statements finish.
            pArg: User data pointer passed to callback.

        Returns:
            Pointer to the previous profile callback data.
        """
        return self.lib.sqlite3_profile(db, xProfile, pArg)

    fn trace_v2[
        origin: MutOrigin, origin2: MutOrigin, origin3: MutOrigin, ctx_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        uMask: UInt32,
        xCallback: fn (UInt32, MutOpaquePointer[origin], MutOpaquePointer[origin2], MutOpaquePointer[origin3]) -> c_int,
        pCtx: MutOpaquePointer[ctx_origin],
    ) -> SQLite3Result:
        """Register A Trace Callback (Version 2).

        This routine registers a callback function to be invoked for various
        tracing events based on the mask parameter.

        Args:
            db: Database connection.
            uMask: Bitmask of trace events to monitor.
            xCallback: Callback function invoked for trace events.
            pCtx: User data pointer passed to callback.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_trace_v2(db, uMask, xCallback, pCtx)

    fn progress_handler[
        origin: MutOrigin, arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        nOps: c_int,
        xProgress: fn (MutOpaquePointer[origin]) -> c_int,
        pArg: MutOpaquePointer[arg_origin],
    ):
        """Register A Progress Callback.

        This routine registers a callback function to be invoked periodically
        during long-running operations. The callback can be used to provide
        progress feedback or to interrupt the operation.

        Args:
            db: Database connection.
            nOps: Number of virtual machine instructions between callbacks.
            xProgress: Callback function invoked periodically.
            pArg: User data pointer passed to callback.
        """
        self.lib.sqlite3_progress_handler(db, nOps, xProgress, pArg)

    fn open_v2(
        self,
        mut filename: String,
        ppDb: MutUnsafePointer[MutExternalPointer[sqlite3_connection]],
        flags: c_int,
        var zVfs: Optional[String],
    ) -> SQLite3Result:
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
        var vfs_ptr = zVfs.value().as_c_string_slice().unsafe_ptr() if zVfs else ImmutExternalPointer[c_char]()
        return self.lib.sqlite3_open_v2(filename.as_c_string_slice().unsafe_ptr(), ppDb, flags, vfs_ptr)

    fn errcode(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
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
        return self.lib.sqlite3_errcode(db)

    fn extended_errcode(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
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
        return self.lib.sqlite3_extended_errcode(db)

    fn errmsg(self, db: MutExternalPointer[sqlite3_connection]) -> ImmutExternalPointer[c_char]:
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
        return self.lib.sqlite3_errmsg(db)
        # var ptr = self.lib.sqlite3_errmsg(db)
        # if not ptr:
        #     return None
        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn errstr(self, e: c_int) -> ImmutExternalPointer[c_char]:
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
        return self.lib.sqlite3_errstr(e)
        # var ptr = self.lib.sqlite3_errstr(e)
        # if not ptr:
        #     return None
        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn error_offset(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
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
        return self.lib.sqlite3_error_offset(db)

    fn limit(self, db: MutExternalPointer[sqlite3_connection], id: c_int, newVal: c_int) -> SQLite3Result:
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
        return self.lib.sqlite3_limit(db, id, newVal)

    fn prepare_v2[
        origin: ImmutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zSql: String,
        nByte: c_int,
        mut ppStmt: MutExternalPointer[sqlite3_stmt],
        mut pzTail: ImmutUnsafePointer[c_char, origin],
    ) -> SQLite3Result:
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
        return self.lib.sqlite3_prepare_v2(
            db, zSql.as_c_string_slice().unsafe_ptr(), nByte, UnsafePointer(to=ppStmt), UnsafePointer(to=pzTail)
        )

    fn prepare_v3[
        sql: ImmutOrigin, tail: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        zSql: ImmutUnsafePointer[c_char, sql],
        nByte: c_int,
        prepFlags: UInt32,
        mut ppStmt: MutExternalPointer[sqlite3_stmt],
        pzTail: MutUnsafePointer[ImmutUnsafePointer[c_char, origin=sql], tail],
    ) -> SQLite3Result:
        return self.lib.sqlite3_prepare_v3(db, zSql, nByte, prepFlags, UnsafePointer(to=ppStmt), pzTail)

    fn sql(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> ImmutExternalPointer[c_char]:
        """Retrieve the SQL text of a prepared statement.

        Returns a pointer to a copy of the UTF-8 SQL text used to create the
        prepared statement if that statement was compiled using sqlite3_prepare_v2()
        or its variants.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Pointer to the SQL text used to create the statement.
        """
        return self.lib.sqlite3_sql(pStmt)

    fn expanded_sql(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLiteMallocString:
        """Retrieve SQL with bound parameters expanded.

        Returns a pointer to a UTF-8 string containing the SQL text of the
        prepared statement with bound parameters expanded inline. This is useful
        for debugging and logging purposes.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Pointer to the expanded SQL text, or NULL if out of memory.
        """
        return SQLiteMallocString(self.lib.sqlite3_expanded_sql(pStmt))

    fn stmt_readonly(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
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
        return self.lib.sqlite3_stmt_readonly(pStmt)

    fn stmt_isexplain(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Determine If A Prepared Statement Is An EXPLAIN.

        This routine returns 1 if the prepared statement is an EXPLAIN statement,
        or 2 if the statement is an EXPLAIN QUERY PLAN. It returns 0 if the
        statement is an ordinary statement or a NULL pointer.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            1 for EXPLAIN, 2 for EXPLAIN QUERY PLAN, 0 otherwise.
        """
        return self.lib.sqlite3_stmt_isexplain(pStmt)

    fn stmt_busy(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
        """Determine If A Prepared Statement Has Been Reset.

        This routine returns true (non-zero) if the prepared statement has
        been stepped at least once using sqlite3_step() but has not run to
        completion and/or has not been reset using sqlite3_reset(). This
        function is useful for detecting if a statement is currently active.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            Non-zero if the statement is busy, zero if it is not.
        """
        return self.lib.sqlite3_stmt_busy(pStmt)

    fn bind_blob64[
        value_origin: ImmutOrigin,
    ](
        self,
        pStmt: MutExternalPointer[sqlite3_stmt],
        idx: c_int,
        value: ImmutOpaquePointer[value_origin],
        n: UInt64,
        destructor_callback: ResultDestructorFn,
    ) -> SQLite3Result:
        """Binding Values To Prepared Statements - BLOB (64-bit).

        This routine binds a BLOB value to a parameter in a prepared statement.
        The parameter is identified by its index (1-based). This version accepts
        a 64-bit length value for BLOBs larger than 2GB.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: Pointer to the BLOB data.
            n: Number of bytes in the BLOB.
            destructor_callback: Destructor callback for the BLOB data.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_bind_blob64(pStmt, idx, value, n, destructor_callback)

    fn bind_double(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int, value: Float64) -> SQLite3Result:
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
        return self.lib.sqlite3_bind_double(pStmt, idx, value)

    fn bind_int64(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int, value: Int64) -> SQLite3Result:
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
        return self.lib.sqlite3_bind_int64(pStmt, idx, value)

    fn bind_null(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int) -> SQLite3Result:
        """Binding Values To Prepared Statements - NULL.

        This routine binds a NULL value to a parameter in a prepared statement.
        The parameter is identified by its index (1-based).

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_bind_null(pStmt, idx)

    fn bind_text64(
        self,
        pStmt: MutExternalPointer[sqlite3_stmt],
        idx: c_int,
        mut value: String,
        n: UInt64,
        encoding: TextEncoding,
        destructor_callback: ResultDestructorFn,
    ) -> SQLite3Result:
        """Binding Values To Prepared Statements - TEXT (64-bit).

        This routine binds a text string to a parameter in a prepared statement.
        The parameter is identified by its index (1-based). This version accepts
        a 64-bit length value for strings larger than 2GB.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: The text string to bind.
            n: Number of bytes in the string.
            encoding: Text encoding (SQLITE_UTF8, SQLITE_UTF16, etc.).
            destructor_callback: Destructor callback for the string data.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_bind_text64(pStmt, idx, value.as_c_string_slice().unsafe_ptr(), n, encoding.value, destructor_callback)

    fn bind_pointer[
        value_origin: MutOrigin,
    ](
        self,
        pStmt: MutExternalPointer[sqlite3_stmt],
        idx: c_int,
        value: MutOpaquePointer[value_origin],
        mut typeStr: String,
        destructor_callback: ResultDestructorFn,
    ) -> SQLite3Result:
        """Binding Values To Prepared Statements - Pointer.

        This routine binds a pointer value to a parameter in a prepared statement.
        The pointer is identified by a type string and can be retrieved later
        using sqlite3_value_pointer(). This is useful for passing application-
        defined objects through SQL.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            value: Pointer to application data.
            typeStr: Type identifier string for the pointer.
            destructor_callback: Destructor callback for the pointer data.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_bind_pointer[](pStmt, idx, value, typeStr.as_c_string_slice().unsafe_ptr(), destructor_callback)

    fn bind_zeroblob(self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int, n: c_int) -> SQLite3Result:
        """Binding Values To Prepared Statements - Zeroblob.

        This routine binds a BLOB filled with zeros to a parameter in a prepared
        statement. The parameter is identified by its index (1-based). This is
        more efficient than creating a zero-filled buffer in application memory.

        Args:
            pStmt: Prepared statement.
            idx: Index of the parameter (1-based).
            n: Size of the zeroblob in bytes.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_bind_zeroblob(pStmt, idx, n)

    fn bind_parameter_count(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Return the number of parameters in a prepared statement.

        This function returns the number of SQL parameters in the prepared
        statement. SQL parameters are tokens such as "?" or ":name" or "$var"
        that are used to substitute values at runtime.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            The number of SQL parameters in the prepared statement.
        """
        return self.lib.sqlite3_bind_parameter_count(pStmt)

    fn bind_parameter_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get the name of a parameter in a prepared statement.

        This function returns the name of the N-th SQL parameter in the prepared
        statement. SQL parameters of the form "?NNN" or ":AAA" or "@AAA" or "$AAA"
        have a name which is the string "?NNN" or ":AAA" or "@AAA" or "$AAA"
        respectively. Parameters of the form "?" without a following integer have
        no name and this function returns NULL.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the parameter (1-based).

        Returns:
            The name of the parameter, or empty string if it has no name.
        """
        return self.lib.sqlite3_bind_parameter_name(pStmt, idx)
        # var ptr = self.lib.sqlite3_bind_parameter_name(pStmt, idx)
        # if not ptr:
        #     return None
        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn bind_parameter_index(self, pStmt: MutExternalPointer[sqlite3_stmt], mut zName: String) -> c_int:
        """Get the index of a named parameter.

        This function returns the index of an SQL parameter given its name.
        The index value returned is suitable for use as the second parameter
        to sqlite3_bind(). A zero is returned if no matching parameter is found.

        Args:
            pStmt: Pointer to the prepared statement.
            zName: Name of the parameter to find.

        Returns:
            Index of the parameter (1-based), or 0 if not found.
        """
        return self.lib.sqlite3_bind_parameter_index(pStmt, zName.as_c_string_slice().unsafe_ptr())

    fn clear_bindings(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
        """Reset All Bindings On A Prepared Statement.

        Contrary to the intuition of many, sqlite3_reset() does not reset
        the bindings on a prepared statement. This routine resets all
        parameters to NULL.

        Args:
            pStmt: Prepared statement.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_clear_bindings(pStmt)

    fn column_count(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> c_int:
        """Return the number of columns in a result set.

        This function returns the number of columns in the result set returned
        by the prepared statement. This value does not change from one execution
        of the prepared statement to the next.

        Args:
            pStmt: Pointer to the prepared statement.

        Returns:
            The number of columns in the result set.
        """
        return self.lib.sqlite3_column_count(pStmt)

    fn column_name(self, pStmt: MutExternalPointer[sqlite3_stmt], N: c_int) -> ImmutExternalPointer[c_char]:
        """Get the name of a column in a result set.

        This function returns the name assigned to a particular column in the
        result set of a SELECT statement. The leftmost column is number 0.
        The name is the value of the "AS" clause for that column, if present.
        Otherwise, it is the name of the column in the table.

        Args:
            pStmt: Pointer to the prepared statement.
            N: Index of the column (0-based).

        Returns:
            The column name, or None if N is out of range.
        """
        return self.lib.sqlite3_column_name(pStmt, N)

    fn column_database_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get the database name of a column.

        This function returns the name of the database that is the origin of
        a particular result column in a SELECT statement. Requires SQLite to
        be compiled with SQLITE_ENABLE_COLUMN_METADATA.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            The database name, or None if not available.
        """
        return self.lib.sqlite3_column_database_name(pStmt, idx)
        # var ptr = self.lib.sqlite3_column_database_name(pStmt, idx)
        # if not ptr:
        #     return None

        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn column_table_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get the table name of a column.

        This function returns the name of the table that is the origin of
        a particular result column in a SELECT statement. Requires SQLite to
        be compiled with SQLITE_ENABLE_COLUMN_METADATA.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            The table name, or None if not available.
        """
        return self.lib.sqlite3_column_table_name(pStmt, idx)
        # var ptr = self.lib.sqlite3_column_table_name(pStmt, idx)
        # if not ptr:
        #     return None

        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn column_origin_name(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get the origin column name.

        This function returns the name of the table column that is the origin
        of a particular result column in a SELECT statement. Requires SQLite to
        be compiled with SQLITE_ENABLE_COLUMN_METADATA.

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            The origin column name, or None if not available.
        """
        return self.lib.sqlite3_column_origin_name(pStmt, idx)
        # var ptr = self.lib.sqlite3_column_origin_name(pStmt, idx)
        # if not ptr:
        #     return None

        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn column_decltype(
        self, pStmt: MutExternalPointer[sqlite3_stmt], idx: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get the declared datatype of a column.

        This function returns the declared datatype of a result column. The
        datatype is the type declaration as it appears in the CREATE TABLE
        statement. For example, in "CREATE TABLE t1(c1 VARIANT)", the declared
        type of column c1 is "VARIANT".

        Args:
            pStmt: Pointer to the prepared statement.
            idx: Index of the column (0-based).

        Returns:
            The declared datatype, or None if not available.
        """
        return self.lib.sqlite3_column_decltype(pStmt, idx)
        # var ptr = self.lib.sqlite3_column_decltype(pStmt, idx)
        # if not ptr:
        #     return None

        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn step(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
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
        return self.lib.sqlite3_step(pStmt)

    fn column_blob(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> ImmutExternalPointer[NoneType]:
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
        return self.lib.sqlite3_column_blob(pStmt, iCol)

    fn column_double(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> Float64:
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
        return self.lib.sqlite3_column_double(pStmt, iCol)

    fn column_int64(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> Int64:
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
        return self.lib.sqlite3_column_int64(pStmt, iCol)

    fn column_text(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> ImmutExternalPointer[c_uchar]:
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
        return self.lib.sqlite3_column_text(pStmt, iCol)

    fn column_value(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> MutExternalPointer[sqlite3_value]:
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
        return self.lib.sqlite3_column_value(pStmt, iCol)

    fn column_bytes(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> c_int:
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
        return self.lib.sqlite3_column_bytes(pStmt, iCol)

    fn column_type(self, pStmt: MutExternalPointer[sqlite3_stmt], iCol: c_int) -> c_int:
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
        return self.lib.sqlite3_column_type(pStmt, iCol)

    fn finalize(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
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
        return self.lib.sqlite3_finalize(pStmt)

    fn reset(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
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
        return self.lib.sqlite3_reset(pStmt)

    # TODO: Create scalar and aggregate function variants since they require null function pointers.
    fn create_function_v2[
        app_origin: MutOrigin,
        fn_origin: MutOrigin,
        step_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zFunctionName: String,
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xFunc: fn (
            MutExternalPointer[sqlite3_context],
            c_int,
            MutUnsafePointer[MutExternalPointer[sqlite3_value], fn_origin],
        ) -> NoneType,
        xStep: fn (
            MutExternalPointer[sqlite3_context],
            c_int,
            MutUnsafePointer[MutExternalPointer[sqlite3_value], step_origin],
        ) -> NoneType,
        xFinal: fn (MutExternalPointer[sqlite3_context]) -> NoneType,
        destructor_callback: ResultDestructorFn,
    ) -> SQLite3Result:
        """Create Or Redefine SQL Functions.

        This function is used to add SQL functions or aggregates or to redefine
        the behavior of existing SQL functions or aggregates. For scalar functions,
        only xFunc should be non-NULL. For aggregate functions, xStep and xFinal
        should be non-NULL and xFunc should be NULL.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the SQL function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding (SQLITE_UTF8, SQLITE_UTF16, etc.).
            pApp: Application data pointer passed to callbacks.
            xFunc: Callback for scalar functions.
            xStep: Callback for aggregate step functions.
            xFinal: Callback for aggregate finalization.
            destructor_callback: Callback invoked when the function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_create_function_v2[
            app_origin=app_origin,
            fn_origin=fn_origin,
            step_origin=step_origin,
        ](db, zFunctionName.as_c_string_slice().unsafe_ptr(), nArg, eTextRep, pApp, xFunc, xStep, xFinal, destructor_callback)

    fn create_window_function[
        app_origin: MutOrigin,
        step_origin: MutOrigin,
        inverse_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zFunctionName: String,
        nArg: c_int,
        eTextRep: c_int,
        pApp: MutOpaquePointer[app_origin],
        xStep: fn (
            MutExternalPointer[sqlite3_context],
            c_int,
            MutUnsafePointer[MutExternalPointer[sqlite3_value], step_origin],
        ) -> NoneType,
        xFinal: fn (MutExternalPointer[sqlite3_context]) -> NoneType,
        xValue: fn (MutExternalPointer[sqlite3_context]) -> NoneType,
        xInverse: fn (
            MutExternalPointer[sqlite3_context],
            c_int,
            MutUnsafePointer[MutExternalPointer[sqlite3_value], inverse_origin],
        ) -> NoneType,
        destructor_callback: ResultDestructorFn,
    ) -> SQLite3Result:
        """Register An Aggregate Window Function.

        This function is used to register aggregate window functions. Window
        functions operate over a sliding window of rows and require xValue and
        xInverse callbacks in addition to xStep and xFinal for efficient
        computation of window frames.

        Args:
            db: Database connection handle.
            zFunctionName: Name of the SQL function to create.
            nArg: Number of arguments the function accepts (-1 for variable).
            eTextRep: Text encoding (SQLITE_UTF8, SQLITE_UTF16, etc.).
            pApp: Application data pointer passed to callbacks.
            xStep: Callback invoked for each row entering the window.
            xFinal: Callback invoked to compute the final aggregate value.
            xValue: Callback invoked to get current aggregate value.
            xInverse: Callback invoked for each row leaving the window.
            destructor_callback: Callback invoked when the function is deleted.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_create_window_function[
            app_origin=app_origin,
            step_origin=step_origin,
            inverse_origin=inverse_origin,
        ](
            db,
            zFunctionName.as_c_string_slice().unsafe_ptr(),
            nArg,
            eTextRep,
            pApp,
            xStep,
            xFinal,
            xValue,
            xInverse,
            destructor_callback,
        )

    fn aggregate_count(self, ctx: MutExternalPointer[sqlite3_context]) -> SQLite3Result:
        """Number Of Rows In An Aggregate Context (Deprecated).

        This function returns the number of times that the step function of
        an aggregate has been called. This function is deprecated.

        Args:
            ctx: SQL function context.

        Returns:
            Number of times the aggregate step function has been called.
        """
        return self.lib.sqlite3_aggregate_count(ctx)

    fn expired(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> SQLite3Result:
        """Determine If A Prepared Statement Is Expired (Deprecated).

        This function was used to determine if a prepared statement had been
        expired and needed to be reprepared. It is deprecated and always
        returns 0.

        Args:
            pStmt: Prepared statement handle.

        Returns:
            Always returns 0.
        """
        return self.lib.sqlite3_expired(pStmt)

    fn transfer_bindings(
        self, fromStmt: MutExternalPointer[sqlite3_stmt], toStmt: MutExternalPointer[sqlite3_stmt]
    ) -> SQLite3Result:
        """Transfer Bindings From One Statement To Another (Deprecated).

        This function was used to transfer bindings from one prepared statement
        to another. It is deprecated.

        Args:
            fromStmt: Source statement handle.
            toStmt: Destination statement handle.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_transfer_bindings(fromStmt, toStmt)

    fn global_recover(self) -> SQLite3Result:
        """Attempt To Free Heap Memory (Deprecated).

        This function was used to attempt to recover from allocation failures.
        It is deprecated and always returns SQLITE_OK.

        Returns:
            Always returns SQLITE_OK.
        """
        return self.lib.sqlite3_global_recover()

    fn thread_cleanup(self):
        """Clean Up Thread-Local Storage (Deprecated).

        This function was used to clean up thread-local storage for SQLite.
        It is deprecated and does nothing in modern versions of SQLite.
        """
        self.lib.sqlite3_thread_cleanup()

    fn memory_alarm[
        origin: MutOrigin
    ](
        self,
        callback: fn (MutOpaquePointer[origin], Int64, c_int) -> NoneType,
        arg: MutOpaquePointer[origin],
        n: Int64,
    ) -> SQLite3Result:
        """Register A Callback For Memory Allocation Events (Deprecated).

        This function was used to register a callback that would be invoked
        when memory usage exceeded a threshold. It is deprecated.

        Args:
            callback: Callback function to invoke.
            arg: User data pointer passed to callback.
            n: Memory threshold in bytes.

        Returns:
            SQLITE_OK on success, or an error code on failure.
        """
        return self.lib.sqlite3_memory_alarm(callback, arg, n)

    fn value_blob(self, value: MutExternalPointer[sqlite3_value]) -> MutExternalPointer[NoneType]:
        """Obtaining SQL Values - BLOB.

        This routine extracts a BLOB value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Pointer to the BLOB data.
        """
        return self.lib.sqlite3_value_blob(value)

    fn value_double(self, value: MutExternalPointer[sqlite3_value]) -> Float64:
        """Obtaining SQL Values - REAL.

        This routine extracts a floating point value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a double precision floating point number.
        """
        return self.lib.sqlite3_value_double(value)

    fn value_int64(self, value: MutExternalPointer[sqlite3_value]) -> Int64:
        """Obtaining SQL Values - INTEGER (64-bit).

        This routine extracts a 64-bit signed integer value from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a 64-bit signed integer.
        """
        return self.lib.sqlite3_value_int64(value)

    fn value_pointer(
        self, value: MutExternalPointer[sqlite3_value], mut typeStr: String
    ) -> MutExternalPointer[NoneType]:
        """Obtaining SQL Values - Pointer.

        This routine extracts a pointer value from an sqlite3_value object.
        The pointer must have been set using sqlite3_bind_pointer() or
        sqlite3_result_pointer() with the same type string.

        Args:
            value: Pointer to the sqlite3_value object.
            typeStr: Type identifier string for the pointer.

        Returns:
            The pointer value, or NULL if types don't match.
        """
        return self.lib.sqlite3_value_pointer(value, typeStr.as_c_string_slice().unsafe_ptr())

    fn value_text(self, value: MutExternalPointer[sqlite3_value]) -> ImmutExternalPointer[c_uchar]:
        """Obtaining SQL Values - TEXT.

        This routine extracts a text string from an sqlite3_value object.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The value as a UTF-8 encoded string.
        """
        return self.lib.sqlite3_value_text(value)

    fn value_bytes(self, value: MutExternalPointer[sqlite3_value]) -> SQLite3Result:
        """Size Of A BLOB Or TEXT Value In Bytes.

        This routine returns the number of bytes in a BLOB or TEXT value.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Number of bytes in the value.
        """
        return self.lib.sqlite3_value_bytes(value)

    fn value_type(self, value: MutExternalPointer[sqlite3_value]) -> SQLite3Result:
        """Datatype Code For An sqlite3_value.

        This routine returns the datatype code for the value.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Datatype code (SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, or SQLITE_NULL).
        """
        return self.lib.sqlite3_value_type(value)

    fn value_nochange(self, value: MutExternalPointer[sqlite3_value]) -> SQLite3Result:
        """Detect No-Op Column Updates.

        This function is used within virtual table UPDATE methods to determine
        if a column value is actually being changed.

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            Non-zero if the column is unchanged, zero if it is being updated.
        """
        return self.lib.sqlite3_value_nochange(value)

    fn value_subtype(self, value: MutExternalPointer[sqlite3_value]) -> UInt32:
        """Get Subtype Of An sqlite3_value.

        This routine retrieves the subtype value that was set using
        sqlite3_result_subtype().

        Args:
            value: Pointer to the sqlite3_value object.

        Returns:
            The subtype value.
        """
        return self.lib.sqlite3_value_subtype(value)

    fn aggregate_context(self, ctx: MutExternalPointer[sqlite3_context], nBytes: c_int) -> MutExternalPointer[NoneType]:
        """Get Aggregate Function Context.

        This routine allocates or returns the aggregate context for an aggregate
        function. The first time this is called for a particular aggregate, nBytes
        of zeroed memory is allocated. On subsequent calls, the same pointer is
        returned.

        Args:
            ctx: SQL function context.
            nBytes: Number of bytes to allocate.

        Returns:
            Pointer to the aggregate context.
        """
        return self.lib.sqlite3_aggregate_context(ctx, nBytes)

    fn user_data(self, ctx: MutExternalPointer[sqlite3_context]) -> MutExternalPointer[NoneType]:
        """Get User Data For SQL Functions.

        This routine returns the user data pointer that was passed to
        sqlite3_create_function() when the SQL function was registered.

        Args:
            ctx: SQL function context.

        Returns:
            User data pointer.
        """
        return self.lib.sqlite3_user_data(ctx)

    fn context_db_handle(self, ctx: MutExternalPointer[sqlite3_context]) -> MutExternalPointer[sqlite3_connection]:
        """Get Database Connection Handle From Context.

        This routine returns the database connection handle for the function.

        Args:
            ctx: SQL function context.

        Returns:
            Database connection handle.
        """
        return self.lib.sqlite3_context_db_handle(ctx)

    fn get_auxdata(self, ctx: MutExternalPointer[sqlite3_context], N: c_int) -> MutExternalPointer[NoneType]:
        """Get Metadata For SQL Functions.

        This routine returns metadata that was previously set using
        sqlite3_set_auxdata(). This is useful for caching per-query data.

        Args:
            ctx: SQL function context.
            N: Index of the auxiliary data.

        Returns:
            Previously set auxiliary data pointer, or NULL.
        """
        return self.lib.sqlite3_get_auxdata(ctx, N)

    fn set_auxdata[
        data_origin: MutOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        N: c_int,
        data: MutOpaquePointer[data_origin],
        destructor_callback: ResultDestructorFn,
    ):
        """Set Metadata For SQL Functions.

        This routine saves metadata that can be retrieved later using
        sqlite3_get_auxdata(). This is useful for caching per-query data
        across multiple function calls.

        Args:
            ctx: SQL function context.
            N: Index of the auxiliary data.
            data: Pointer to the data to store.
            destructor_callback: Callback to free the data when no longer needed.
        """
        self.lib.sqlite3_set_auxdata(ctx, N, data, destructor_callback)

    fn result_blob64[
        origin: MutOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        value: MutOpaquePointer[origin],
        n: UInt64,
        destructor_callback: ResultDestructorFn,
    ):
        """Set The Result Of A Function To A BLOB (64-bit).

        This routine sets the result of a SQL function to a BLOB value.

        Args:
            ctx: SQL function context.
            value: Pointer to the BLOB data.
            n: Number of bytes in the BLOB.
            destructor_callback: Callback to free the BLOB data.
        """
        self.lib.sqlite3_result_blob64(ctx, value, n, destructor_callback)

    fn result_double(self, ctx: MutExternalPointer[sqlite3_context], value: Float64):
        """Set The Result Of A Function To A Floating Point Value.

        This routine sets the result of a SQL function to a double precision
        floating point value.

        Args:
            ctx: SQL function context.
            value: The floating point value.
        """
        self.lib.sqlite3_result_double(ctx, value)

    fn result_error(self, ctx: MutExternalPointer[sqlite3_context], mut msg: String, n: c_int):
        """Set The Result Of A Function To An Error.

        This routine sets the result of a SQL function to an error message.

        Args:
            ctx: SQL function context.
            msg: Error message string.
            n: Number of bytes in the error message.
        """
        self.lib.sqlite3_result_error(ctx, msg.as_c_string_slice().unsafe_ptr(), n)

    fn result_error_toobig(self, ctx: MutExternalPointer[sqlite3_context]):
        """Set The Result Of A Function To "Too Big" Error.

        This routine sets the result of a SQL function to SQLITE_TOOBIG error.

        Args:
            ctx: SQL function context.
        """
        self.lib.sqlite3_result_error_toobig(ctx)

    fn result_error_nomem(self, ctx: MutExternalPointer[sqlite3_context]):
        """Set The Result Of A Function To "Out Of Memory" Error.

        This routine sets the result of a SQL function to SQLITE_NOMEM error.

        Args:
            ctx: SQL function context.
        """
        self.lib.sqlite3_result_error_nomem(ctx)

    fn result_error_code(self, ctx: MutExternalPointer[sqlite3_context], code: c_int):
        """Set The Result Of A Function To An Error Code.

        This routine sets the result of a SQL function to a specific error code.

        Args:
            ctx: SQL function context.
            code: The error code.
        """
        self.lib.sqlite3_result_error_code(ctx, code)

    fn result_int64(self, ctx: MutExternalPointer[sqlite3_context], value: Int64):
        """Set The Result Of A Function To A 64-bit Integer.

        This routine sets the result of a SQL function to a 64-bit signed integer.

        Args:
            ctx: SQL function context.
            value: The 64-bit integer value.
        """
        self.lib.sqlite3_result_int64(ctx, value)

    fn result_null(self, ctx: MutExternalPointer[sqlite3_context]):
        """Set The Result Of A Function To NULL.

        This routine sets the result of a SQL function to NULL.

        Args:
            ctx: SQL function context.
        """
        self.lib.sqlite3_result_null(ctx)

    fn result_text64[
        value_origin: ImmutOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        mut value: String,
        n: UInt64,
        encoding: UInt8,
        destructor_callback: ResultDestructorFn,
    ):
        """Set The Result Of A Function To A Text String (64-bit).

        This routine sets the result of a SQL function to a UTF-8 or UTF-16 text string.

        Args:
            ctx: SQL function context.
            value: The text string.
            n: Number of bytes in the string.
            encoding: Text encoding (SQLITE_UTF8 or SQLITE_UTF16).
            destructor_callback: Callback to free the string.
        """
        self.lib.sqlite3_result_text64(ctx, value.as_c_string_slice().unsafe_ptr(), n, encoding, destructor_callback)

    fn result_value(self, ctx: MutExternalPointer[sqlite3_context], value: MutExternalPointer[sqlite3_value]):
        """Set The Result Of A Function To A Copy Of Another Value.

        This routine sets the result of a SQL function to a copy of the given sqlite3_value.

        Args:
            ctx: SQL function context.
            value: The value to copy.
        """
        self.lib.sqlite3_result_value(ctx, value)

    fn result_pointer[
        ptr_origin: MutOrigin,
    ](
        self,
        ctx: MutExternalPointer[sqlite3_context],
        ptr: MutOpaquePointer[ptr_origin],
        mut typeStr: String,
        destructor_callback: ResultDestructorFn,
    ):
        """Set The Result Of A Function To A Pointer.

        This routine sets the result of a SQL function to a typed pointer value.

        Args:
            ctx: SQL function context.
            ptr: The pointer value.
            typeStr: Type identifier string for the pointer.
            destructor_callback: Callback to free the pointer.
        """
        self.lib.sqlite3_result_pointer(ctx, ptr, typeStr.as_c_string_slice().unsafe_ptr(), destructor_callback)

    fn result_zeroblob(self, ctx: MutExternalPointer[sqlite3_context], n: c_int):
        """Set The Result Of A Function To A Zero-filled BLOB.

        This routine sets the result of a SQL function to a BLOB containing n bytes
        of zeros.

        Args:
            ctx: SQL function context.
            n: Number of zero bytes.
        """
        self.lib.sqlite3_result_zeroblob(ctx, n)

    fn result_subtype(self, ctx: MutExternalPointer[sqlite3_context], subtype: UInt32):
        """Set The Subtype Of The Result Of A Function.

        This routine sets the subtype of the result for a SQL function.

        Args:
            ctx: SQL function context.
            subtype: The subtype value.
        """
        self.lib.sqlite3_result_subtype(ctx, subtype)

    fn create_collation_v2[
        arg_origin: MutOrigin,
        compare_origin: MutOrigin,
        compare_origin2: ImmutOrigin,
        compare_origin3: ImmutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zName: String,
        eTextRep: c_int,
        pArg: MutOpaquePointer[arg_origin],
        xCompare: fn (
            MutOpaquePointer[compare_origin],
            c_int,
            ImmutOpaquePointer[compare_origin2],
            c_int,
            ImmutOpaquePointer[compare_origin3],
        ) -> c_int,
        destructor_callback: ResultDestructorFn,
    ) -> SQLite3Result:
        """Define New Collating Sequences.

        This routine creates a new collating sequence for the database connection.

        Args:
            db: Database connection.
            zName: Name of the collating sequence.
            eTextRep: Text encoding (SQLITE_UTF8, SQLITE_UTF16LE, etc.).
            pArg: User data pointer passed to the callback.
            xCompare: Comparison function callback.
            destructor_callback: Callback to free user data.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_create_collation_v2[
            arg_origin=arg_origin,
            compare_origin=compare_origin,
            compare_origin2=compare_origin2,
            compare_origin3=compare_origin3,
        ](db, zName.as_c_string_slice().unsafe_ptr(), eTextRep, pArg, xCompare, destructor_callback)

    fn collation_needed[
        arg_origin: MutOrigin, cb_origin: MutOrigin, cb_origin2: ImmutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        pArg: MutOpaquePointer[arg_origin],
        callback: fn (
            MutOpaquePointer[cb_origin],
            MutExternalPointer[sqlite3_connection],
            c_int,
            ImmutUnsafePointer[c_char, cb_origin2],
        ) -> NoneType,
    ) -> SQLite3Result:
        """Collation Needed Callback.

        This routine registers a callback that is invoked when SQLite needs a collating
        sequence that has not been defined.

        Args:
            db: Database connection.
            pArg: User data pointer passed to the callback.
            callback: Callback function invoked when a collation is needed.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_collation_needed(db, pArg, callback)

    fn soft_heap_limit(self, n: c_int) -> SQLite3Result:
        """Set Soft Heap Memory Limit (Deprecated).

        This routine sets the soft heap memory limit for SQLite. This function is
        deprecated - use soft_heap_limit64 instead.

        Args:
            n: The soft heap limit in bytes.

        Returns:
            The previous soft heap limit.
        """
        return self.lib.sqlite3_soft_heap_limit(n)

    fn soft_heap_limit64(self, n: Int64) -> Int64:
        """Set Soft Heap Memory Limit (64-bit).

        This routine sets the soft heap memory limit for SQLite. A negative value
        disables the limit. Zero returns the current limit without changing it.

        Args:
            n: The soft heap limit in bytes, or a negative value to disable.

        Returns:
            The previous soft heap limit.
        """
        return self.lib.sqlite3_soft_heap_limit64(n)

    fn stmt_status(self, pStmt: MutExternalPointer[sqlite3_stmt], op: c_int, resetFlg: c_int) -> SQLite3Result:
        """Prepared Statement Status.

        This routine retrieves runtime status information about a prepared statement.

        Args:
            pStmt: Prepared statement.
            op: Status parameter to retrieve (SQLITE_STMTSTATUS_*).
            resetFlg: True to reset the counter after reading.

        Returns:
            The current value of the requested counter.
        """
        return self.lib.sqlite3_stmt_status(pStmt, op, resetFlg)

    fn table_column_metadata(
        self,
        db: MutExternalPointer[sqlite3_connection],
        var zDbName: Optional[String],
        mut zTableName: String,
        var zColumnName: Optional[String],
        var pzDataType: Optional[String],
        var pzCollSeq: Optional[String],
        var pNotNull: Optional[c_int],
        var pPrimaryKey: Optional[c_int],
        var pAutoinc: Optional[c_int],
    ) -> SQLite3Result:
        """Extract Metadata About A Column Of A Table.

        This routine retrieves metadata about a specific column of a specific table
        in a database.

        Args:
            db: Database connection.
            zDbName: Database name (e.g., "main", "temp").
            zTableName: Table name.
            zColumnName: Column name.
            pzDataType: Output parameter for the declared data type.
            pzCollSeq: Output parameter for the collating sequence.
            pNotNull: Output parameter for NOT NULL constraint.
            pPrimaryKey: Output parameter for PRIMARY KEY constraint.
            pAutoinc: Output parameter for AUTOINCREMENT property.

        Returns:
            Result code (SQLITE_OK on success).
        """
        var db_ptr = zDbName.value().as_c_string_slice().unsafe_ptr() if zDbName else ImmutExternalPointer[Int8]()
        var col_name_ptr = zColumnName.value().as_c_string_slice().unsafe_ptr() if zColumnName else ImmutExternalPointer[Int8]()
        var dt_ptr = pzDataType.value().as_c_string_slice().unsafe_ptr() if pzDataType else ImmutExternalPointer[Int8]()
        var coll_seq_ptr = pzCollSeq.value().as_c_string_slice().unsafe_ptr() if pzCollSeq else ImmutExternalPointer[
            Int8
        ]()
        var nn_ptr = UnsafePointer(to=pNotNull.value()) if pNotNull else MutExternalPointer[c_int]()
        var pk_ptr = UnsafePointer(to=pPrimaryKey.value()) if pPrimaryKey else MutExternalPointer[c_int]()
        var ai_ptr = UnsafePointer(to=pAutoinc.value()) if pAutoinc else MutExternalPointer[c_int]()

        return self.lib.sqlite3_table_column_metadata[
            dt_origin = origin_of(pzDataType._value),
            dt_origin2 = origin_of(dt_ptr),
            cs_origin = origin_of(pzCollSeq._value),
            cs_origin2 = origin_of(coll_seq_ptr),
        ](
            db,
            db_ptr,
            zTableName.as_c_string_slice().unsafe_ptr(),
            col_name_ptr,
            UnsafePointer(to=dt_ptr),
            UnsafePointer(to=coll_seq_ptr),
            nn_ptr,
            pk_ptr,
            ai_ptr,
        )

    # fn load_extension[
    #     origin: MutOrigin
    # ](
    #     self,
    #     db: MutExternalPointer[sqlite3_connection],
    #     mut zFile: String,
    #     var zProc: Optional[String],
    #     pzErrMsg: MutUnsafePointer[c_char, origin],
    # ) -> SQLite3Result:
    #     """Load An Extension.

    #     This routine loads an SQLite extension library from a file.

    #     Args:
    #         db: Database connection.
    #         zFile: Path to the extension library file.
    #         zProc: Entry point name (NULL to use default).
    #         pzErrMsg: Output parameter for error message.

    #     Returns:
    #         Result code (SQLITE_OK on success).
    #     """
    #     var proc_ptr = zProc.value().as_c_string_slice().unsafe_ptr() if zProc else ImmutExternalPointer[Int8]()
    #     return self.lib.sqlite3_load_extension(db, zFile.as_c_string_slice().unsafe_ptr(), proc_ptr, UnsafePointer(to=pzErrMsg))

    fn enable_load_extension(self, db: MutExternalPointer[sqlite3_connection], onoff: c_int) -> SQLite3Result:
        """Enable Or Disable Extension Loading.

        This routine enables or disables the loading of SQLite extensions.

        Args:
            db: Database connection.
            onoff: 1 to enable, 0 to disable.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_enable_load_extension(db, onoff)

    fn get_autocommit(self, db: MutExternalPointer[sqlite3_connection]) -> Bool:
        """Test For Auto-Commit Mode.

        This routine returns true if the database connection is in autocommit mode.

        Args:
            db: Database connection.

        Returns:
            True if autocommit is enabled, false otherwise.
        """
        return self.lib.sqlite3_get_autocommit(db) != 0

    fn db_handle(self, pStmt: MutExternalPointer[sqlite3_stmt]) -> MutExternalPointer[sqlite3_connection]:
        """Find The Database Handle Of A Prepared Statement.

        This routine returns the database connection handle that owns the
        prepared statement.

        Args:
            pStmt: Prepared statement.

        Returns:
            Database connection handle.
        """
        return self.lib.sqlite3_db_handle(pStmt)

    fn db_name(self, db: MutExternalPointer[sqlite3_connection], N: c_int) -> ImmutExternalPointer[c_char]:
        """Return The Name Of An Attached Database.

        This routine returns the name of the Nth attached database.

        Args:
            db: Database connection.
            N: Database index (0 for main database).

        Returns:
            Database name.
        """
        return self.lib.sqlite3_db_name(db, N)

    fn db_filename(
        self, db: MutExternalPointer[sqlite3_connection], mut zDbName: String
    ) -> ImmutExternalPointer[c_char]:
        """Return The Filename For A Database Connection.

        This routine returns the filename associated with a database connection.

        Args:
            db: Database connection.
            zDbName: Database name (e.g., "main", "temp").

        Returns:
            Filename or None if not available.
        """
        return self.lib.sqlite3_db_filename(db, zDbName.as_c_string_slice().unsafe_ptr())
        # var ptr = self.lib.sqlite3_db_filename(db, zDbName.as_c_string_slice().unsafe_ptr())
        # if not ptr:
        #     return None

        # return StringSlice(unsafe_from_utf8_ptr=ptr).get_immutable()

    fn db_readonly(self, db: MutExternalPointer[sqlite3_connection], mut zDbName: String) -> SQLite3Result:
        """Determine If A Database Is Read-Only.

        This routine returns 1 if the database is read-only, 0 if it is read-write,
        or -1 if the database name is not recognized.

        Args:
            db: Database connection.
            zDbName: Database name (e.g., "main", "temp").

        Returns:
            1 if read-only, 0 if read-write, -1 if unknown.
        """
        return self.lib.sqlite3_db_readonly(db, zDbName.as_c_string_slice().unsafe_ptr())

    fn txn_state(self, db: MutExternalPointer[sqlite3_connection], mut zSchema: String) -> SQLite3Result:
        """Determine The Transaction State Of A Database.

        This routine returns the transaction state for a database connection.

        Args:
            db: Database connection.
            zSchema: Database schema name (e.g., "main", "temp").

        Returns:
            Transaction state (SQLITE_TXN_NONE, SQLITE_TXN_READ, SQLITE_TXN_WRITE).
        """
        return self.lib.sqlite3_txn_state(db, zSchema.as_c_string_slice().unsafe_ptr())

    fn next_stmt(
        self, pDb: MutExternalPointer[sqlite3_connection], pStmt: MutExternalPointer[sqlite3_stmt]
    ) -> MutExternalPointer[sqlite3_stmt]:
        """Find The Next Prepared Statement.

        This routine returns the next prepared statement after pStmt in the list
        of all prepared statements for the database connection.

        Args:
            pDb: Database connection.
            pStmt: Current prepared statement (NULL to get first statement).

        Returns:
            Next prepared statement or NULL.
        """
        return self.lib.sqlite3_next_stmt(pDb, pStmt)

    fn update_hook[
        cb_origin: MutOrigin,
        cb_fn_origin: MutOrigin,
        cb_fn_origin2: MutOrigin,
        cb_fn_origin3: MutOrigin,
        arg_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: MutUnsafePointer[
            fn (
                MutOpaquePointer[cb_fn_origin],
                c_int,
                MutUnsafePointer[c_char, cb_fn_origin2],
                MutUnsafePointer[c_char, cb_fn_origin3],
                Int64,
            ), cb_origin
        ],
        pArg: MutOpaquePointer[arg_origin],
    ) -> None:
        """Register A Callback For Database Updates.

        This routine registers a callback function with the database connection that
        is invoked whenever a row is updated, inserted or deleted in a rowid table.

        Args:
            db: Database connection.
            xCallback: Callback function invoked on updates.
            pArg: User data pointer passed to the callback.
        """
        self.lib.sqlite3_update_hook(db, xCallback, pArg)

    fn commit_hook[
        cb_origin: MutOrigin,
        cb_fn_origin: MutOrigin,
        arg_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: MutUnsafePointer[fn (MutOpaquePointer[cb_fn_origin]) -> c_int, cb_origin],
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Register A Callback For Commit Events.

        This routine registers a callback function to be invoked whenever a transaction
        is committed. If the callback returns non-zero, the commit is converted into a rollback.

        Args:
            db: Database connection.
            xCallback: Callback function invoked before commits.
            pArg: User data pointer passed to the callback.

        Returns:
            Pointer to the previous commit hook data.
        """
        return self.lib.sqlite3_commit_hook(db, xCallback, pArg)

    fn rollback_hook[
        cb_origin: MutOrigin,
        cb_fn_origin: MutOrigin,
        arg_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: MutUnsafePointer[fn (MutOpaquePointer[cb_fn_origin]), cb_origin],
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Register A Callback For Rollback Events.

        This routine registers a callback function to be invoked whenever a transaction
        is rolled back.

        Args:
            db: Database connection.
            xCallback: Callback function invoked on rollback.
            pArg: User data pointer passed to the callback.

        Returns:
            Pointer to the previous rollback hook data.
        """
        return self.lib.sqlite3_rollback_hook(db, xCallback, pArg)

    fn auto_extension(self, xEntryPoint: MutUnsafePointer[fn () -> c_int]) -> SQLite3Result:
        """Register An Auto-Extension.

        This routine registers a statically linked extension that is automatically
        loaded into all new database connections.

        Args:
            xEntryPoint: Entry point function for the extension.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_auto_extension(xEntryPoint)

    fn db_release_memory(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
        """Free Memory Used By A Database Connection.

        This routine attempts to free as much heap memory as possible from the
        database connection.

        Args:
            db: Database connection.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_db_release_memory(db)

    fn cancel_auto_extension(self, xEntryPoint: MutUnsafePointer[fn () -> c_int]) -> SQLite3Result:
        """Cancel An Auto-Extension.

        This routine cancels a prior registration of an auto-extension.

        Args:
            xEntryPoint: Entry point function of the extension to cancel.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_cancel_auto_extension(xEntryPoint)

    fn reset_auto_extension(self) -> SQLite3Result:
        """Reset The Auto-Extension List.

        This routine unregisters all auto-extensions that have been registered.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_reset_auto_extension()

    fn blob_open[
        db_origin: ImmutOrigin, table_origin: ImmutOrigin, column_origin: ImmutOrigin, blob_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zDb: String,
        mut zTable: String,
        mut zColumn: String,
        iRow: Int64,
        flags: c_int,
        ppBlob: MutUnsafePointer[MutExternalPointer[sqlite3_blob], blob_origin],
    ) -> SQLite3Result:
        """Open A BLOB For Incremental I/O.

        This routine opens a handle to the BLOB located in row iRow, column zColumn,
        table zTable in database zDb.

        Args:
            db: Database connection.
            zDb: Database name (e.g., "main", "temp").
            zTable: Table name.
            zColumn: Column name.
            iRow: Row ID.
            flags: SQLITE_OPEN_READONLY or SQLITE_OPEN_READWRITE.
            ppBlob: Output parameter for the BLOB handle.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_blob_open(
            db, zDb.as_c_string_slice().unsafe_ptr(), zTable.as_c_string_slice().unsafe_ptr(), zColumn.as_c_string_slice().unsafe_ptr(), iRow, flags, ppBlob
        )

    fn blob_reopen(self, pBlob: MutExternalPointer[sqlite3_blob], iRow: Int64) -> SQLite3Result:
        """Move A BLOB Handle To A New Row.

        This routine moves an existing BLOB handle to point to a different row
        of the same database table.

        Args:
            pBlob: BLOB handle.
            iRow: New row ID.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_blob_reopen(pBlob, iRow)

    fn blob_close(self, pBlob: MutExternalPointer[sqlite3_blob]) -> SQLite3Result:
        """Close A BLOB Handle.

        This routine closes a BLOB handle that was previously opened.

        Args:
            pBlob: BLOB handle.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_blob_close(pBlob)

    fn blob_bytes(self, pBlob: MutExternalPointer[sqlite3_blob]) -> SQLite3Result:
        """Return The Size Of An Open BLOB.

        This routine returns the size in bytes of the BLOB accessible via the
        BLOB handle.

        Args:
            pBlob: BLOB handle.

        Returns:
            Size of the BLOB in bytes.
        """
        return self.lib.sqlite3_blob_bytes(pBlob)

    fn blob_read[
        origin: MutOrigin
    ](
        self, pBlob: MutExternalPointer[sqlite3_blob], Z: MutOpaquePointer[origin], N: c_int, iOffset: c_int
    ) -> SQLite3Result:
        """Read Data From A BLOB Incrementally.

        This routine reads N bytes of data from the BLOB into buffer Z, starting
        at offset iOffset.

        Args:
            pBlob: BLOB handle.
            Z: Buffer to read data into.
            N: Number of bytes to read.
            iOffset: Offset within the BLOB to start reading.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_blob_read(pBlob, Z, N, iOffset)

    fn blob_write[
        origin: MutOrigin
    ](
        self, pBlob: MutExternalPointer[sqlite3_blob], z: MutOpaquePointer[origin], n: c_int, iOffset: c_int
    ) -> SQLite3Result:
        """Write Data Into A BLOB Incrementally.

        This routine writes N bytes of data from buffer z into the BLOB, starting
        at offset iOffset.

        Args:
            pBlob: BLOB handle.
            z: Buffer containing data to write.
            n: Number of bytes to write.
            iOffset: Offset within the BLOB to start writing.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_blob_write(pBlob, z, n, iOffset)

    fn file_control[
        db_name_origin: ImmutOrigin,
        arg_origin: MutOrigin,
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zDbName: String,
        op: c_int,
        pArg: MutOpaquePointer[arg_origin],
    ) -> SQLite3Result:
        """Low-Level Control Of Database Files.

        This routine provides a direct interface to the VFS layer for low-level
        control of database files.

        Args:
            db: Database connection.
            zDbName: Database name (e.g., "main", "temp").
            op: Operation code.
            pArg: Operation-specific argument.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_file_control(db, zDbName.as_c_string_slice().unsafe_ptr(), op, pArg)

    fn backup_init(
        self,
        pDest: MutExternalPointer[sqlite3_connection],
        mut zDestName: String,
        pSource: MutExternalPointer[sqlite3_connection],
        mut zSourceName: String,
    ) -> MutExternalPointer[sqlite3_backup]:
        """Initialize A Database Backup Operation.

        This routine creates and returns a backup object used to copy the contents
        of one database into another.

        Args:
            pDest: Destination database connection.
            zDestName: Destination database name.
            pSource: Source database connection.
            zSourceName: Source database name.

        Returns:
            Backup handle or NULL on error.
        """
        return self.lib.sqlite3_backup_init(pDest, zDestName.as_c_string_slice().unsafe_ptr(), pSource, zSourceName.as_c_string_slice().unsafe_ptr())

    fn backup_step(self, p: MutExternalPointer[sqlite3_backup], nPage: c_int) -> SQLite3Result:
        """Copy Up To nPage Pages Between Databases.

        This routine copies up to nPage pages from the source database to the
        destination database.

        Args:
            p: Backup handle.
            nPage: Number of pages to copy, or -1 for all remaining pages.

        Returns:
            Result code (SQLITE_OK or SQLITE_DONE on success).
        """
        return self.lib.sqlite3_backup_step(p, nPage)

    fn backup_finish(self, p: MutExternalPointer[sqlite3_backup]) -> SQLite3Result:
        """Finish A Backup Operation.

        This routine finishes a backup operation and releases the backup handle.

        Args:
            p: Backup handle.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_backup_finish(p)

    fn backup_remaining(self, p: MutExternalPointer[sqlite3_backup]) -> SQLite3Result:
        """Get Number Of Pages Still To Be Backed Up.

        This routine returns the number of pages still to be backed up.

        Args:
            p: Backup handle.

        Returns:
            Number of pages remaining.
        """
        return self.lib.sqlite3_backup_remaining(p)

    fn backup_pagecount(self, p: MutExternalPointer[sqlite3_backup]) -> SQLite3Result:
        """Get Total Number Of Pages In Source Database.

        This routine returns the total number of pages in the source database.

        Args:
            p: Backup handle.

        Returns:
            Total number of pages.
        """
        return self.lib.sqlite3_backup_pagecount(p)

    fn unlock_notify[
        notify_origin: MutOrigin,
        notify_origin2: MutOrigin,
        arg_origin: MutOrigin,
    ](
        self,
        pBlocked: MutExternalPointer[sqlite3_connection],
        xNotify: fn (MutUnsafePointer[MutOpaquePointer[notify_origin], notify_origin2], c_int) -> NoneType,
        pNotifyArg: MutOpaquePointer[arg_origin],
    ) -> SQLite3Result:
        """Register An Unlock Notification Callback.

        This routine registers a callback that is invoked when a database connection
        that was previously blocked is able to proceed.

        Args:
            pBlocked: Database connection that is blocked.
            xNotify: Callback function to invoke when unblocked.
            pNotifyArg: User data pointer passed to callback.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_unlock_notify(pBlocked, xNotify, pNotifyArg)

    fn log(self, iErrCode: c_int, mut zFormat: String):
        """Write A Message To The Error Log.

        This routine writes a message to the SQLite error log.

        Args:
            iErrCode: Error code associated with the message.
            zFormat: Printf-style format string for the message.
        """
        self.lib.sqlite3_log(iErrCode, zFormat.as_c_string_slice().unsafe_ptr())

    fn wal_hook[
        cb_origin: MutOrigin, cb_origin2: MutOrigin, arg_origin: MutOrigin
    ](
        self,
        db: MutExternalPointer[sqlite3_connection],
        xCallback: fn (
            MutOpaquePointer[cb_origin],
            MutExternalPointer[sqlite3_connection],
            MutUnsafePointer[c_char, cb_origin2],
            c_int,
        ) -> c_int,
        pArg: MutOpaquePointer[arg_origin],
    ) -> MutExternalPointer[NoneType]:
        """Register A Write-Ahead Log Commit Hook.

        This routine registers a callback function to be invoked whenever data is
        committed to a database in WAL mode.

        Args:
            db: Database connection.
            xCallback: Callback function invoked on WAL commits.
            pArg: User data pointer passed to callback.

        Returns:
            Pointer to the previous WAL hook data.
        """
        return self.lib.sqlite3_wal_hook(db, xCallback, pArg)

    fn wal_autocheckpoint(self, db: MutExternalPointer[sqlite3_connection], N: c_int) -> SQLite3Result:
        """Configure WAL Auto-Checkpoint.

        This routine configures the database connection to automatically checkpoint
        the WAL after N frames have been written.

        Args:
            db: Database connection.
            N: Number of frames between auto-checkpoints (0 to disable).

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_wal_autocheckpoint(db, N)

    fn wal_checkpoint(self, db: MutExternalPointer[sqlite3_connection], var zDb: Optional[String]) -> SQLite3Result:
        """Checkpoint A Database.

        This routine checkpoints database zDb attached to connection db.

        Args:
            db: Database connection.
            zDb: Database name (NULL for all databases).

        Returns:
            Result code (SQLITE_OK on success).
        """
        var db_ptr = zDb.value().as_c_string_slice().unsafe_ptr() if zDb else ImmutExternalPointer[Int8]()
        return self.lib.sqlite3_wal_checkpoint(db, db_ptr)

    fn wal_checkpoint_v2(
        self,
        db: MutExternalPointer[sqlite3_connection],
        var zDb: Optional[String],
        eMode: c_int,
        pnLog: MutUnsafePointer[c_int],
        pnCkpt: MutUnsafePointer[c_int],
    ) -> SQLite3Result:
        """Checkpoint A Database (Version 2).

        This routine checkpoints database zDb with additional control over the
        checkpoint operation and information about the checkpoint.

        Args:
            db: Database connection.
            zDb: Database name (NULL for all databases).
            eMode: Checkpoint mode (PASSIVE, FULL, RESTART, TRUNCATE).
            pnLog: Output parameter for WAL log size.
            pnCkpt: Output parameter for checkpointed frames.

        Returns:
            Result code (SQLITE_OK on success).
        """
        var db_ptr = zDb.value().as_c_string_slice().unsafe_ptr() if zDb else ImmutExternalPointer[Int8]()
        return self.lib.sqlite3_wal_checkpoint_v2(db, db_ptr, eMode, pnLog, pnCkpt)

    fn vtab_config(self, db: MutExternalPointer[sqlite3_connection], op: c_int) -> SQLite3Result:
        """Configure Virtual Table Behavior.

        This routine configures various aspects of virtual table behavior.

        Args:
            db: Database connection.
            op: Configuration operation.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_vtab_config(db, op)

    fn vtab_on_conflict(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
        """Determine The ON CONFLICT Mode For A Virtual Table.

        This routine returns the ON CONFLICT mode for the virtual table update
        that is in progress.

        Args:
            db: Database connection.

        Returns:
            ON CONFLICT mode.
        """
        return self.lib.sqlite3_vtab_on_conflict(db)

    fn vtab_nochange(self, ctx: MutExternalPointer[sqlite3_context]) -> SQLite3Result:
        """Determine If A Column Is Unchanged In An UPDATE.

        This routine returns true if a column in a virtual table UPDATE operation
        has not changed.

        Args:
            ctx: SQL function context.

        Returns:
            Non-zero if the column has not changed.
        """
        return self.lib.sqlite3_vtab_nochange(ctx)

    fn vtab_collation(
        self, pIdxInfo: MutExternalPointer[sqlite3_index_info], iCons: c_int
    ) -> ImmutExternalPointer[c_char]:
        """Get The Collation For A Virtual Table Constraint.

        This routine returns the name of the collation sequence for a constraint
        in a virtual table.

        Args:
            pIdxInfo: Index info structure.
            iCons: Constraint index.

        Returns:
            Collation name.
        """
        return self.lib.sqlite3_vtab_collation(pIdxInfo, iCons)

    fn vtab_distinct(self, pIdxInfo: MutExternalPointer[sqlite3_index_info]) -> SQLite3Result:
        """Determine If A Virtual Table Query Is DISTINCT.

        This routine returns information about whether a query is DISTINCT.

        Args:
            pIdxInfo: Index info structure.

        Returns:
            DISTINCT mode indicator.
        """
        return self.lib.sqlite3_vtab_distinct(pIdxInfo)

    fn db_cacheflush(self, db: MutExternalPointer[sqlite3_connection]) -> SQLite3Result:
        """Flush Dirty Pages To Disk.

        This routine attempts to flush any dirty pages in the pager cache to disk.

        Args:
            db: Database connection.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_db_cacheflush(db)

    fn serialize(
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zSchema: String,
        piSize: MutUnsafePointer[Int64],
        mFlags: UInt32,
    ) -> MutExternalPointer[UInt8]:
        """Serialize A Database.

        This routine serializes a database into a memory buffer that can be
        written to disk or transmitted over a network.

        Args:
            db: Database connection.
            zSchema: Database name to serialize.
            piSize: Output parameter for the size of the serialized database.
            mFlags: Serialization flags.

        Returns:
            Pointer to the serialized database buffer.
        """
        return self.lib.sqlite3_serialize(db, zSchema.as_c_string_slice().unsafe_ptr(), piSize, mFlags)

    fn deserialize(
        self,
        db: MutExternalPointer[sqlite3_connection],
        mut zSchema: String,
        pData: MutUnsafePointer[UInt8],
        szDb: Int64,
        szBuf: Int64,
        mFlags: UInt32,
    ) -> SQLite3Result:
        """Deserialize A Database.

        This routine deserializes a database from a memory buffer, replacing the
        current contents of the database.

        Args:
            db: Database connection.
            zSchema: Database name to deserialize into.
            pData: Pointer to the serialized database buffer.
            szDb: Size of the database in bytes.
            szBuf: Size of the buffer in bytes.
            mFlags: Deserialization flags.

        Returns:
            Result code (SQLITE_OK on success).
        """
        return self.lib.sqlite3_deserialize(db, zSchema.as_c_string_slice().unsafe_ptr(), pData, szDb, szBuf, mFlags)
