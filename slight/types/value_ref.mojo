"""`ValueRef` — a borrowed reference to a SQLite value.

Used for scalar/aggregate function arguments and other places that read a
SQLite-owned value without copying it.
"""
from slight.c.types import sqlite3_value, MutExternalPointer
from slight.api import sqlite_ffi
from slight.enums import DataType


__enum ValueRef[stmt: ImmOrigin](ImplicitlyCopyable, Writable):
    """A non-owning dynamic type value. Typically, the memory backing this value is owned by SQLite.

    Parameters:
        stmt: The origin of the statement that owns the value memory.
    """

    case null
    """A SQL NULL value."""
    case integer(Int64)
    """A SQL INTEGER value. SQLite stores all integers as 64-bit signed values."""
    case real(Float64)
    """A SQL REAL value. SQLite stores all reals as double-precision floats."""
    case text(StringSpan[Self.stmt])
    """A SQL TEXT value, borrowing memory owned by the statement."""
    case blob(Span[Byte, Self.stmt])
    """A SQL BLOB value, borrowing memory owned by the statement."""

    def __init__(out self, value: MutExternalPointer[sqlite3_value]):
        """Reads a `ValueRef` from a raw `sqlite3_value` pointer.

        This reads the type and value from the raw `sqlite3_value` pointer.
        Blob and Text types reference SQLite owned data and may be invalidated.

        Args:
            value: A pointer to the sqlite3_value representing the SQL value.
        """
        match DataType(sqlite_ffi()[].value_type(value)):
            case .null:
                self = Self.null
            case .integer:
                self = Self.integer(sqlite_ffi()[].value_int64(value))
            case .float:
                self = Self.real(sqlite_ffi()[].value_double(value))
            case .text:
                var text = sqlite_ffi()[].value_text(value)
                if not text:
                    self = Self.null
                    return
                self = ValueRef[ImmUntrackedOrigin].text(text.value()).unsafe_origin_cast[Self.stmt]()
            case .blob:
                var blob = sqlite_ffi()[].value_blob(value)
                if not blob:
                    self = Self.null
                    return
                self = ValueRef[ImmUntrackedOrigin].blob(blob.value()).unsafe_origin_cast[Self.stmt]()

    def unsafe_origin_cast[target: ImmOrigin](self) -> ValueRef[target]:
        """Re-labels the origin of the borrowed TEXT or BLOB memory.

        **Unsafe: the compiler cannot check this.** The caller must guarantee the
        memory stays valid for as long as `target` is live. NULL, INTEGER and REAL
        values hold no borrowed memory and are copied as-is.

        Parameters:
            target: The origin to attach to the borrowed memory.

        Returns:
            The same value, borrowing from `target`.
        """
        match self:
            case .null:
                return ValueRef[target].null
            case .integer(value):
                return ValueRef[target].integer(value)
            case .real(value):
                return ValueRef[target].real(value)
            case .text(value):
                return ValueRef[target].text(
                    StringSpan(
                        unsafe_from_utf8=Span(
                            unsafe_ptr=value.unsafe_ptr().unsafe_origin_cast[target](), length=value.byte_length()
                        )
                    )
                )
            case .blob(value):
                return ValueRef[target].blob(
                    Span(unsafe_ptr=value.unsafe_ptr().unsafe_origin_cast[target](), length=len(value))
                )

    def type_name(self) -> StaticString:
        """Returns the SQLite storage class of this value.

        Returns:
            One of `NULL`, `INTEGER`, `REAL`, `TEXT` or `BLOB`.
        """
        match self:
            case .null:
                return "NULL"
            case .integer:
                return "INTEGER"
            case .real:
                return "REAL"
            case .text:
                return "TEXT"
            case .blob:
                return "BLOB"

    def _type_error(self, expected: StaticString) -> Error:
        """Builds the error raised when this value is not of the requested type.

        Args:
            expected: The storage class(es) the caller asked for.

        Returns:
            An `InvalidColumnTypeError` naming both the expected and the actual type.
        """
        return Error(t"InvalidColumnTypeError: value is {self.type_name()}, expected {expected}")

    def is_null(self) -> Bool:
        """Checks whether this value is SQL NULL.

        Returns:
            True if the value is NULL, False otherwise.
        """
        match self:
            case .null:
                return True
            case _:
                return False

    def write_to(self, mut writer: Some[Writer]):
        """Write the string representation of the SQL value to the given writer.

        This method provides a way to serialize the SQL value into a human-readable
        format, suitable for logging or debugging purposes.

        Args:
            writer: The writer to which the string representation will be written.
        """
        match self:
            case .null:
                writer.write("NULL")
            case .integer(value):
                writer.write(value)
            case .real(value):
                writer.write(value)
            case .text(value):
                writer.write(value)
            case .blob(value):
                # TODO: Improve blob representation
                writer.write("BLOB(", len(value), " bytes)")

    def unsafe_as_string_slice(self) raises -> StringSpan[Self.stmt]:
        """Convert the SQL value to a borrowed string slice.

        **Unsafe: the returned span borrows memory owned by SQLite.** It is
        only valid for the current row — SQLite invalidates the pointer on the
        next `step()`, `reset()` or `finalize()` of the statement, and on a
        type conversion of the same column. The compiler will not catch misuse:
        the origin here is the statement's, which is wider than the real bound.

        Copy into an owned `String` before advancing the statement.

        Returns:
            A StringSpan borrowing SQLite memory for the current row.

        Raises:
            Error: If the value is not of type TEXT.
        """
        match self:
            case .text(value):
                return value
            case _:
                raise self._type_error("TEXT")

    def unsafe_as_string_slice_or_null(self) raises -> Optional[StringSpan[Self.stmt]]:
        """Convert the SQL value to a borrowed string slice, or None if NULL.

        **Unsafe: the returned span borrows memory owned by SQLite.** See
        `unsafe_as_string_slice` for the full invalidation rules — the same
        ones apply here.

        Returns:
            A StringSpan borrowing SQLite memory, or None if the value is NULL.

        Raises:
            Error: If the value is not of type TEXT or NULL.
        """
        match self:
            case .text(value):
                return value
            case .null:
                return None
            case _:
                raise self._type_error("TEXT")

    def as_int64(self) raises -> Int64:
        """Convert the SQL value to its Int64 representation.

        This method provides a way to get the integer representation
        of the stored SQL value, if it is of type INTEGER.

        Returns:
            An Int64 representing the SQL value.

        Raises:
            Error: If the value is not of type INTEGER.
        """
        match self:
            case .integer(value):
                return value
            case _:
                raise self._type_error("INTEGER")

    def as_int64_or_null(self) raises -> Optional[Int64]:
        """Convert the SQL value to its Int64 representation.

        This method provides a way to get the integer representation
        of the stored SQL value, if it is of type INTEGER.

        Returns:
            An Int64 representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type INTEGER or NULL.
        """
        match self:
            case .integer(value):
                return value
            case .null:
                return None
            case _:
                raise self._type_error("INTEGER")

    def as_float64(self) raises -> Float64:
        """Convert the SQL value to its Float64 representation.

        REAL values are returned as-is. INTEGER values are converted, since SQLite
        freely returns integers for numeric expressions (e.g. `sum()` over an INTEGER
        column, or a REAL-affinity column holding a whole number).

        Returns:
            A Float64 representing the SQL value.

        Raises:
            Error: If the value is not of type REAL or INTEGER.
        """
        match self:
            case .real(value):
                return value
            case .integer(value):
                return Float64(value)
            case _:
                raise self._type_error("REAL")

    def as_float64_or_null(self) raises -> Optional[Float64]:
        """Convert the SQL value to its Float64 representation.

        REAL values are returned as-is and INTEGER values are converted; see `as_float64()`.

        Returns:
            A Float64 representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type REAL, INTEGER or NULL.
        """
        match self:
            case .real(value):
                return value
            case .integer(value):
                return Float64(value)
            case .null:
                return None
            case _:
                raise self._type_error("REAL")

    def unsafe_as_blob(self) raises -> Span[Byte, Self.stmt]:
        """Convert the SQL value to its BLOB representation.

        **Unsafe: the returned span borrows memory owned by SQLite.** It is
        only valid for the current row — SQLite invalidates the pointer on the
        next `step()`, `reset()` or `finalize()` of the statement, and on a
        type conversion of the same column. The compiler will not catch misuse.
        Prefer `Row.get[List[Byte]]()` for an owned copy.

        This method provides a way to get the binary data representation
        of the stored SQL value, if it is of type BLOB.

        Returns:
            A Span of Bytes representing the SQL value.

        Raises:
            Error: If the value is not of type BLOB.
        """
        match self:
            case .blob(value):
                return value
            case _:
                raise self._type_error("BLOB")

    def unsafe_as_blob_or_null(self) raises -> Optional[Span[Byte, Self.stmt]]:
        """Convert the SQL value to its BLOB representation.

        **Unsafe: the returned span borrows memory owned by SQLite.** It is
        only valid for the current row — SQLite invalidates the pointer on the
        next `step()`, `reset()` or `finalize()` of the statement, and on a
        type conversion of the same column. The compiler will not catch misuse.
        Prefer `Row.get[List[Byte]]()` for an owned copy.

        This method provides a way to get the binary data representation
        of the stored SQL value, if it is of type BLOB.

        Returns:
            A Span of Bytes representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type BLOB or NULL.
        """
        match self:
            case .blob(value):
                return value
            case .null:
                return None
            case _:
                raise self._type_error("BLOB")

    def unsafe_as_bytes(self) raises -> Span[Byte, Self.stmt]:
        """Convert the SQL value to a byte representation.

        **Unsafe: the returned span borrows memory owned by SQLite.** It is
        only valid for the current row — SQLite invalidates the pointer on the
        next `step()`, `reset()` or `finalize()` of the statement, and on a
        type conversion of the same column. The compiler will not catch misuse.
        Prefer `Row.get[List[Byte]]()` for an owned copy.

        This method provides a way to get byte data for either BLOB or TEXT SQL values.

        Returns:
            A Span of Bytes representing the SQL value.

        Raises:
            Error: If the value is not of type BLOB or TEXT.
        """
        match self:
            case .blob(value):
                return value
            case .text(value):
                return value.as_bytes()
            case _:
                raise self._type_error("BLOB or TEXT")

    def unsafe_as_bytes_or_null(self) raises -> Optional[Span[Byte, Self.stmt]]:
        """Convert the SQL value to a byte representation.

        **Unsafe: the returned span borrows memory owned by SQLite.** It is
        only valid for the current row — SQLite invalidates the pointer on the
        next `step()`, `reset()` or `finalize()` of the statement, and on a
        type conversion of the same column. The compiler will not catch misuse.
        Prefer `Row.get[List[Byte]]()` for an owned copy.

        This method provides a way to get byte data for either BLOB or TEXT SQL values.

        Returns:
            A Span of Bytes representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type BLOB, TEXT, or NULL.
        """
        match self:
            case .blob(value):
                return value
            case .text(value):
                return value.as_bytes()
            case .null:
                return None
            case _:
                raise self._type_error("BLOB or TEXT")
