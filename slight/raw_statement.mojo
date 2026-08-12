"""Raw SQLite statment wrapper."""
from std.ffi import c_int, CStringSlice
from std.os import abort
from slight.c.types import ImmExternalPointer, MutExternalPointer, ResultDestructorFn, sqlite3_stmt
from slight.api import sqlite_ffi
from slight.sqlite_string import SQLiteMallocString
from slight.result import SQLite3Result
from slight.enums import TextEncoding
from slight.trace import StatementStatus


@fieldwise_init
@explicit_destroy("RawStatement must be explicitly destroyed. Use self.finalize() to destroy.")
struct RawStatement(Deinitable where False, Movable):
    """A raw SQL statement wrapper around a pointer to a `sqlite3_stmt`."""

    var stmt: MutExternalPointer[sqlite3_stmt]
    """A pointer to the `sqlite3_stmt` that represents this statement."""

    def unsafe_ptr[
        origin: Origin, address_space: AddressSpace, //
    ](ref[origin, address_space] self) -> Pointer[sqlite3_stmt, origin, address_space=address_space]:
        """Retrieves a pointer to the underlying memory.

        Parameters:
            origin: The origin of the `RawStatement`.
            address_space: The `AddressSpace` of the `RawStatement`.

        Returns:
            The pointer to the underlying memory.
        """
        return (
            self.stmt.unsafe_mut_cast[origin.mut]()
            .unsafe_origin_cast[origin]()
            .unsafe_address_space_cast[address_space]()
        )

    def column_int64(self, idx: UInt) -> Int64:
        """Returns the value of the specified column as a 64-bit integer.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a 64-bit integer.
        """
        return sqlite_ffi()[].column_int64(self.unsafe_ptr(), Int32(idx))

    def column_double(self, idx: UInt) -> Float64:
        """Returns the value of the specified column as a double-precision float.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a Float64.
        """
        return sqlite_ffi()[].column_double(self.unsafe_ptr(), Int32(idx))

    def unsafe_column_text(self, idx: UInt) raises -> StringSpan[origin_of(self)]:
        """Returns the value of the specified column as a borrowed text string.

        **Unsafe: the returned span borrows memory owned by SQLite.** SQLite
        invalidates the underlying pointer on the *next* `step()`, `reset()` or
        `finalize()` of this statement, and also when a different type accessor
        is called for the same column (which may convert the value in place).
        Reading the span after any of those is a use-after-free.

        The returned origin is the statement's, because the true bound — "until
        the next step" — is not expressible today, and Mojo does not currently
        enforce borrow exclusivity. **The compiler will not catch misuse here.**
        Copy the value (or use `Row.get[String]()`) before advancing the
        statement.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a StringSpan borrowing SQLite memory.

        Raises:
            Error: If the column contains NULL data.
        """
        var text = sqlite_ffi()[].column_text(self.unsafe_ptr(), Int32(idx))
        if not text:
            raise Error("Unexpected SQLITE_TEXT column type with NULL data.")

        return StringSpan(
            unsafe_from_utf8=CStringSlice(
                unsafe_from_ptr=text.take().unsafe_ptr().unsafe_origin_cast[origin_of(self)]()
            )
        )

    def unsafe_column_blob(self, idx: UInt) raises -> Span[Byte, origin_of(self)]:
        """Returns the value of the specified column as borrowed binary data.

        **Unsafe: the returned span borrows memory owned by SQLite.** See
        `unsafe_column_text` for the full invalidation rules — the same ones
        apply here. Copy the bytes before advancing the statement.

        Args:
            idx: The index of the column to retrieve.

        Returns:
            The value of the specified column as a Span of bytes borrowing SQLite memory.

        Raises:
            Error: If the column contains NULL data or has negative length.
        """
        var ptr = sqlite_ffi()[].column_blob(self.unsafe_ptr(), Int32(idx))
        if not ptr:
            raise Error("unexpected SQLITE_BLOB column type with NULL data")

        var length = sqlite_ffi()[].column_bytes(self.unsafe_ptr(), Int32(idx))
        if length < 0:
            raise Error("unexpected SQLITE_BLOB column type with negative length: ", length)

        # Widest bound we can express: the statement. The real bound is "until
        # the next step/reset/finalize or type conversion on this column".
        return Span(
            unsafe_ptr=ptr.value().unsafe_bitcast[Byte]().unsafe_origin_cast[origin_of(self)](), length=Int(length)
        )

    def column_type(self, idx: UInt) -> Int32:
        """Returns the data type of the specified column.

        Args:
            idx: The index of the column to retrieve the type for.

        Returns:
            The SQLite data type constant for the column.
        """
        return sqlite_ffi()[].column_type(self.unsafe_ptr(), Int32(idx))

    def column_count(self) -> Int32:
        """Returns the number of columns in the result set.

        Returns:
            The number of columns returned by the prepared statement.
        """
        return sqlite_ffi()[].column_count(self.unsafe_ptr())

    def bind_parameter_index(self, var name: String) -> Optional[UInt]:
        """Returns the index of the parameter with the given name.

        Args:
            name: The name of the parameter (e.g., ":param", "@param", "$param").

        Returns:
            The 1-based index of the parameter, or 0 if not found.
        """
        var result = sqlite_ffi()[].bind_parameter_index(self.unsafe_ptr(), name)
        if result == 0:
            return None

        return UInt(result)

    def bind_parameter_count(self) -> Int32:
        """Returns the number of parameters in the prepared statement.

        Returns:
            The number of SQL parameters (?, ?NNN, :VVV, @VVV, $VVV) in the statement.
        """
        return sqlite_ffi()[].bind_parameter_count(self.unsafe_ptr())

    def bind_null(mut self, index: UInt) -> SQLite3Result:
        """Binds a NULL value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.

        Returns:
            The SQLite result code from binding the NULL value.
        """
        return sqlite_ffi()[].bind_null(self.unsafe_ptr(), Int32(index))

    def bind_int64(mut self, index: UInt, value: Int64) -> SQLite3Result:
        """Binds a 64-bit integer value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The integer value to bind.

        Returns:
            The SQLite result code from binding the integer value.
        """
        return sqlite_ffi()[].bind_int64(self.unsafe_ptr(), Int32(index), value)

    def bind_double(mut self, index: UInt, value: Float64) -> SQLite3Result:
        """Binds a double-precision float value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The float value to bind.

        Returns:
            The SQLite result code from binding the float value.
        """
        return sqlite_ffi()[].bind_double(self.unsafe_ptr(), Int32(index), value)

    def bind_text[
        origin: ImmOrigin, //
    ](mut self, index: UInt, value: StringSpan[origin], destructor_callback: ResultDestructorFn) -> SQLite3Result:
        """Binds a text string value to the specified parameter.

        The text is borrowed, not copied: SQLite is given a pointer and an
        explicit byte count, so `value` need not be NUL-terminated. Whether
        SQLite takes its own copy is decided by `destructor_callback`
        (`SQLITE_TRANSIENT` copies; `SQLITE_STATIC` does not and requires the
        caller to keep the buffer alive).

        Parameters:
            origin: The origin of the borrowed text.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The string value to bind. Need not be NUL-terminated.
            destructor_callback: The destructor function to call when SQLite is done with the text.

        Returns:
            The SQLite result code from binding the text value.
        """
        return sqlite_ffi()[].bind_text64(
            self.unsafe_ptr(), Int32(index), value, UInt64(len(value.as_bytes())), TextEncoding.UTF8, destructor_callback
        )

    def bind_blob[
        origin: ImmOrigin, //
    ](mut self, index: UInt, value: Span[Byte, origin], destructor_callback: ResultDestructorFn) -> SQLite3Result:
        """Binds a blob value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The blob value to bind.
            destructor_callback: The destructor function to call when SQLite is done with the blob.

        Returns:
            The SQLite result code from binding the blob value.
        """
        return sqlite_ffi()[].bind_blob64(
            self.unsafe_ptr(),
            Int32(index),
            value.unsafe_ptr().unsafe_bitcast[NoneType](),
            UInt64(len(value)),
            destructor_callback,
        )

    def sql(self) -> Optional[StringSpan[origin_of(self)]]:
        """Returns the original SQL text of the prepared statement.

        Returns:
            The original SQL statement used to prepare this statement.
        """
        # We don't really know the origin of this string, it's a pointer returned by SQLite.
        # But it should be valid as long as the statement is valid, so we use the same origin as the statement.
        var sql_ptr = sqlite_ffi()[].sql(self.unsafe_ptr())
        if not sql_ptr:
            return None
        return StringSpan(
            unsafe_from_utf8=CStringSlice(unsafe_from_ptr=sql_ptr.value().unsafe_origin_cast[origin_of(self)]())
        )

    def expanded_sql(self) raises -> Optional[SQLiteMallocString]:
        """Returns the SQL text of the prepared statement with bound parameters expanded.

        Returns:
            The SQL statement with parameter values substituted, or None if
            the statement has already been finalized.

        Raises:
            Error: If the expanded SQL string cannot be allocated due to an OOM error.
        """
        # We don't really know the origin of this string, it's a pointer returned by SQLite.
        # But it should be valid as long as the statement is valid, so we use the same origin as the statement.
        return sqlite_ffi()[].expanded_sql(self.unsafe_ptr())

    def finalize(deinit self) -> SQLite3Result:
        """Destroys the prepared statement and releases its resources.

        After calling this method, the statement should not be used again.

        Returns:
            The SQLite result code from finalizing the statement.
        """
        return sqlite_ffi()[].finalize(self.unsafe_ptr())

    def step(mut self) -> SQLite3Result:
        """Executes the prepared statement and advances to the next result row.

        Returns:
            SQLITE_ROW if a new row is available, SQLITE_DONE if execution is complete,
            or another SQLite result code.
        """
        return sqlite_ffi()[].step(self.unsafe_ptr())

    def reset(mut self) -> SQLite3Result:
        """Resets the prepared statement back to its initial state.

        This allows the statement to be re-executed with the same or different
        bound parameter values.

        Returns:
            The SQLite result code.
        """
        return sqlite_ffi()[].reset(self.unsafe_ptr())

    def clear_bindings(mut self) -> SQLite3Result:
        """Clears all bound parameter values from the prepared statement.

        This allows the statement to be re-executed with new parameter values.

        Returns:
            The SQLite result code.
        """
        return sqlite_ffi()[].clear_bindings(self.unsafe_ptr())

    def column_name(self, idx: UInt) -> Optional[ImmExternalPointer[Int8]]:
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
        var ptr = sqlite_ffi()[].column_name(self.unsafe_ptr(), i)
        if not ptr:
            return None

        return ptr

    def is_explain(self) -> Int32:
        """Returns whether the prepared statement is an EXPLAIN statement.

        Returns:
            * 0 if it is an ordinary statement or a NULL pointer.
            * 1 if the prepared statement is an EXPLAIN statement.
            * 2 if the statement is an EXPLAIN QUERY PLAN.
        """
        return sqlite_ffi()[].stmt_isexplain(self.unsafe_ptr())

    def is_read_only(self) -> Bool:
        """Returns whether the prepared statement is read-only.

        A read-only statement is one that does not modify the database (e.g., a SELECT statement).

        Returns:
            True if the statement is read-only, False otherwise.
        """
        return sqlite_ffi()[].stmt_readonly(self.unsafe_ptr()) != 0

    def get_status(self, status: StatementStatus) -> Int32:
        """Returns the current value of a status counter for this statement.

        The counter is left unchanged. Use `reset_status` to read and reset it
        in one call.

        Args:
            status: Which counter to read.

        Returns:
            The current value of the requested counter.
        """
        return sqlite_ffi()[].stmt_status(self.unsafe_ptr(), c_int(status.value), c_int(0))

    def reset_status(mut self, status: StatementStatus) -> Int32:
        """Returns the current value of a status counter, then resets it to zero.

        Args:
            status: Which counter to read and reset.

        Returns:
            The value of the counter before it was reset.
        """
        return sqlite_ffi()[].stmt_status(self.unsafe_ptr(), c_int(status.value), c_int(1))
