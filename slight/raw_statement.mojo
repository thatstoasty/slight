from slight.c.api import sqlite_ffi
from slight.result import SQLite3Result
from slight.c.types import sqlite3_stmt, ResultDestructorFn, TextEncoding, MutExternalPointer
from slight.c.sqlite_string import SQLiteMallocString


@fieldwise_init
@explicit_destroy("RawStatement must be explicitly destroyed. Use self.finalize() to destroy.")
struct RawStatement(Movable):
    """A raw SQL statement wrapper around a pointer to a `sqlite3_stmt`."""

    var stmt: MutExternalPointer[sqlite3_stmt]
    """A pointer to the `sqlite3_stmt` that represents this statement."""

    fn __init__(out self):
        """Creates an empty RawStatement.

        Returns:
            A new `RawStatement` instance with a null pointer.
        """
        self.stmt = MutExternalPointer[sqlite3_stmt]()

    fn __bool__(self) -> Bool:
        """Returns True if the statement is valid (i.e., the stmt pointer is not null)."""
        return Bool(self.stmt)

    fn column_int64(self, idx: UInt) -> Int64:
        """Returns the value of the specified column as a 64-bit integer.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a 64-bit integer.
        """
        return sqlite_ffi()[].column_int64(self.stmt, Int32(idx))

    fn column_double(self, idx: UInt) -> Float64:
        """Returns the value of the specified column as a double-precision float.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a Float64.
        """
        return sqlite_ffi()[].column_double(self.stmt, Int32(idx))

    fn column_text(self, idx: UInt) raises -> StringSlice[origin_of(self)]:
        """Returns the value of the specified column as a text string.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a StringSlice.

        Raises:
            Error: If the column contains NULL data unexpectedly.
        """
        var ptr = sqlite_ffi()[].column_text(self.stmt, Int32(idx))
        if not ptr:
            raise Error("unexpected SQLITE_TEXT column type with NULL data")

        # Ptr should be valid for the lifetime of the statement. So we use that instead of external origin.
        return StringSlice(unsafe_from_utf8_ptr=ptr.unsafe_origin_cast[origin_of(self)]())

    fn column_blob(self, idx: UInt) raises -> Span[Byte, origin_of(self)]:
        """Returns the value of the specified column as binary data.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a Span of bytes.

        Raises:
            Error: If the column contains NULL data or has negative length.
        """
        var ptr = sqlite_ffi()[].column_blob(self.stmt, Int32(idx)).bitcast[Byte]()
        if not ptr:
            raise Error("unexpected SQLITE_BLOB column type with NULL data")

        var length = sqlite_ffi()[].column_bytes(self.stmt, Int32(idx))
        if length < 0:
            raise Error("unexpected SQLITE_BLOB column type with negative length: ", length)

        # Ptr should be valid for the lifetime of the statement. So we use that instead of external origin.
        return Span(ptr=ptr.unsafe_origin_cast[origin_of(self)](), length=Int(length))

    fn column_type(self, idx: UInt) -> Int32:
        """Returns the data type of the specified column.

        Args:
            idx: The index of the column to retrieve the type for.

        Returns:
            The SQLite data type constant for the column.
        """
        return sqlite_ffi()[].column_type(self.stmt, Int32(idx))

    fn column_count(self) -> Int32:
        """Returns the number of columns in the result set.

        Returns:
            The number of columns returned by the prepared statement.
        """
        return sqlite_ffi()[].column_count(self.stmt)

    fn bind_parameter_index(self, var name: String) -> Optional[UInt]:
        """Returns the index of the parameter with the given name.

        Args:
            name: The name of the parameter (e.g., ":param", "@param", "$param").

        Returns:
            The 1-based index of the parameter, or 0 if not found.
        """
        var result = sqlite_ffi()[].bind_parameter_index(self.stmt, name)
        if result == 0:
            return None

        return UInt(result)

    fn bind_parameter_count(self) -> Int32:
        """Returns the number of parameters in the prepared statement.

        Returns:
            The number of SQL parameters (?, ?NNN, :VVV, @VVV, $VVV) in the statement.
        """
        return sqlite_ffi()[].bind_parameter_count(self.stmt)

    fn bind_null(self, index: UInt) -> SQLite3Result:
        """Binds a NULL value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
        """
        return sqlite_ffi()[].bind_null(self.stmt, Int32(index))

    fn bind_int64(self, index: UInt, value: Int64) -> SQLite3Result:
        """Binds a 64-bit integer value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The integer value to bind.
        """
        return sqlite_ffi()[].bind_int64(self.stmt, Int32(index), value)

    fn bind_double(self, index: UInt, value: Float64) -> SQLite3Result:
        """Binds a double-precision float value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The float value to bind.
        """
        return sqlite_ffi()[].bind_double(self.stmt, Int32(index), value)

    fn bind_text(self, index: UInt, var value: String, destructor_callback: ResultDestructorFn) -> SQLite3Result:
        """Binds a text string value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The string value to bind.
            destructor_callback: The destructor function to call when SQLite is done with the text.
        """
        return sqlite_ffi()[].bind_text64(
            self.stmt, Int32(index), value, len(value), TextEncoding.UTF8, destructor_callback
        )
    
    fn bind_blob(self, index: UInt, value: Span[Byte], destructor_callback: ResultDestructorFn) -> SQLite3Result:
        """Binds a blob value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The blob value to bind.
            destructor_callback: The destructor function to call when SQLite is done with the blob.
        """
        return sqlite_ffi()[].bind_blob64(
            self.stmt, Int32(index), value.unsafe_ptr().bitcast[NoneType](), len(value), destructor_callback
        )

    fn sql(self) -> Optional[StringSlice[origin_of(self)]]:
        """Returns the original SQL text of the prepared statement.

        Returns:
            The original SQL statement used to prepare this statement.
        """
        if not self.stmt:
            return None

        # We don't really know the origin of this string, it's a pointer returned by SQLite.
        # But it should be valid as long as the statement is valid, so we use the same origin as the statement.
        return StringSlice(
            unsafe_from_utf8_ptr=sqlite_ffi()[].sql(self.stmt).unsafe_origin_cast[origin_of(self)]()
        )

    fn expanded_sql(self) -> Optional[SQLiteMallocString]:
        """Returns the SQL text of the prepared statement with bound parameters expanded.

        Returns:
            The SQL statement with parameter values substituted.
        """
        if not self.stmt:
            return None

        # We don't really know the origin of this string, it's a pointer returned by SQLite.
        # But it should be valid as long as the statement is valid, so we use the same origin as the statement.
        return sqlite_ffi()[].expanded_sql(self.stmt)

    fn finalize(deinit self) -> SQLite3Result:
        """Destroys the prepared statement and releases its resources.

        After calling this method, the statement should not be used again.

        Returns:
            The SQLite result code from finalizing the statement.
        """
        return sqlite_ffi()[].finalize(self.stmt)

    fn step(self) -> SQLite3Result:
        """Executes the prepared statement and advances to the next result row.

        Returns:
            SQLITE_ROW if a new row is available, SQLITE_DONE if execution is complete,
            or another SQLite result code.
        """
        return sqlite_ffi()[].step(self.stmt)

    fn reset(self) -> SQLite3Result:
        """Resets the prepared statement back to its initial state.

        This allows the statement to be re-executed with the same or different
        bound parameter values.

        Returns:
            The SQLite result code.
        """
        return sqlite_ffi()[].reset(self.stmt)

    fn clear_bindings(self) -> SQLite3Result:
        """Clears all bound parameter values from the prepared statement.

        This allows the statement to be re-executed with new parameter values.

        Returns:
            The SQLite result code.
        """
        return sqlite_ffi()[].clear_bindings(self.stmt)

    fn column_name(self, idx: UInt) -> Optional[StringSlice[origin_of(self)]]:
        """Returns the name of the specified column.

        Args:
            idx: The index of the column.

        Returns:
            The name of the column as a CStr, or None if the index is out of bounds.
        """
        var i = Int32(idx)
        if i < 0 or i >= self.column_count():
            return None

        # Null ptr indicates an OOM, which we treat as None here.
        var ptr = sqlite_ffi()[].column_name(self.stmt, i)
        if not ptr:
            return None

        return StringSlice(unsafe_from_utf8_ptr=ptr.unsafe_origin_cast[origin_of(self)]())

    fn is_explain(self) -> Int32:
        """Returns whether the prepared statement is an EXPLAIN statement.

        * 1 if the prepared statement is an EXPLAIN statement,
        * 2 if the statement is an EXPLAIN QUERY PLAN,
        * 0 if it is an ordinary statement or a NULL pointer.
        """
        return sqlite_ffi()[].stmt_isexplain(self.stmt)

    fn is_read_only(self) -> Bool:
        """Returns whether the prepared statement is read-only."""
        return sqlite_ffi()[].stmt_readonly(self.stmt) != 0
