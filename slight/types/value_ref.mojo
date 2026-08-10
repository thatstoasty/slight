from std.os import abort
from std.utils import Variant
from slight.c.types import sqlite3_value, MutExternalPointer
from slight.api import sqlite_ffi
from slight.enums import DataType


trait SQLRefType(Copyable):
    """A marker trait for types that represent SQL ValueRef types."""

    pass


@fieldwise_init
struct Null(SQLRefType):
    """Represents a SQL NULL value.

    This is a zero-sized struct that represents the absence of a value
    in SQL contexts. It implements the necessary traits for SQL value
    handling and can be copied and moved efficiently.
    """

    pass


struct Integer(SQLRefType):
    """Represents a SQL INTEGER value.

    This struct wraps a 64-bit signed integer value as used by SQLite.
    SQLite uses 64-bit integers internally for all integer values.
    """

    var value: Int64
    """The underlying integer value."""

    @implicit
    def __init__(out self, value: Int64):
        """Initialize a `Integer` with the given `Int64` value.

        Args:
            value: The value to wrap.
        """
        self.value = value

    @implicit
    def __init__(out self, value: Int):
        """Initialize a `Integer` with the given `Int` value.

        Args:
            value: The value to wrap.
        """
        self.value = Int64(value)


struct Real(SQLRefType):
    """Represents a SQL REAL (floating-point) value.

    This struct wraps a 64-bit floating-point value as used by SQLite.
    SQLite uses double-precision floating-point numbers for all real values.
    """

    var value: Float64
    """The underlying floating-point value."""

    @implicit
    def __init__(out self, value: Float64):
        """Initialize a `Real` with the given `Float64` value.

        Args:
            value: The value to wrap.
        """
        self.value = value


struct Text[stmt: ImmOrigin](SQLRefType):
    """Represents a SQL TEXT value.

    This struct wraps a text string value from SQLite. The text is stored
    as a StringSpan that references memory owned by the SQLite statement,
    so it's only valid for the lifetime of the statement.

    Parameters:
        stmt: The origin of the statement that owns the text memory.
    """

    var value: StringSpan[Self.stmt]
    """The underlying text value."""

    @implicit
    def __init__(out self, value: StringSpan[Self.stmt]):
        """Initialize a `Text` with the given `StringSpan` value.

        Args:
            value: The text value to wrap.
        """
        self.value = value


struct Blob[stmt: ImmOrigin](SQLRefType):
    """Represents a SQL BLOB (binary large object) value.

    This struct wraps binary data from SQLite. The data is stored as a Span
    that references memory owned by the SQLite statement, so it's only valid
    for the lifetime of the statement.

    Parameters:
        stmt: The origin of the statement that owns the blob memory.
    """

    var value: Span[Byte, Self.stmt]
    """The underlying blob value."""

    @implicit
    def __init__(out self, value: Span[Byte, Self.stmt]):
        """Initialize a `Blob` with the given `Span` value.

        Args:
            value: The blob value to wrap.
        """
        self.value = value


struct ValueRef[stmt: ImmOrigin](Movable, Writable):
    """A non-owning dynamic type value. Typically, the memory backing this value is var by SQLite.

    Parameters:
        stmt: The origin of the statement that owns the value memory.
    """

    comptime _type = Variant[Null, Integer, Real, Text[Self.stmt], Blob[Self.stmt]]
    var value: Self._type
    """The actual value stored in the variant."""

    @implicit
    def __init__(out self, var value: Null):
        """Initialize a ValueRef with a NULL value.

        Args:
            value: The Null value to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Integer):
        """Initialize a ValueRef with an INTEGER value.

        Args:
            value: The Integer value to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Real):
        """Initialize a ValueRef with a REAL (floating-point) value.

        Args:
            value: The Real value to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Text[Self.stmt]):
        """Initialize a ValueRef with a TEXT value.

        Args:
            value: The Text value to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Blob[Self.stmt]):
        """Initialize a ValueRef with a BLOB value.

        Args:
            value: The Blob value to store.
        """
        self.value = value^
    
    @staticmethod
    def from_value(value: MutExternalPointer[sqlite3_value]) -> Self:
        """Returns the `idx`th argument as a `ValueRef`.

        This reads the type and value from the raw sqlite3_value pointer.

        Args:
            value: A pointer to the sqlite3_value representing the SQL value.

        Returns:
            A ValueRef containing the argument's value with its appropriate type.
        """
        var value_type = sqlite_ffi()[].value_type(value)

        if DataType.NULL == value_type:
            return Self(Null())
        elif DataType.INTEGER == value_type:
            return Self(Integer(sqlite_ffi()[].value_int64(value)))
        elif DataType.FLOAT == value_type:
            return Self(Real(sqlite_ffi()[].value_double(value)))
        elif DataType.TEXT == value_type:
            var text = sqlite_ffi()[].value_text(value)
            if not text:
                return Self(Null())
            return Self(Text(text.value()))
        elif DataType.BLOB == value_type:
            var blob = sqlite_ffi()[].value_blob(value)
            if not blob:
                return Self(Null())
            return Self(Blob(blob.value()))
        else:
            abort("[UNREACHABLE] sqlite3_value_type returned an invalid value")

    def __init__(out self, value: Self._type):
        """Initialize a ValueRef by copying another ValueRef.

        Args:
            value: The ValueRef to copy.
        """
        if value.isa[Null]():
            self.value = value[Null].copy()
        elif value.isa[Integer]():
            self.value = value[Integer].copy()
        elif value.isa[Real]():
            self.value = value[Real].copy()
        elif value.isa[Text[Self.stmt]]():
            self.value = value[Text[Self.stmt]].copy()
        elif value.isa[Blob[Self.stmt]]():
            self.value = value[Blob[Self.stmt]].copy()
        else:
            abort("UNREACHABLE: invalid variant type for ValueRef initialization")

    def write_to(self, mut writer: Some[Writer]):
        """Write the string representation of the SQL value to the given writer.

        This method provides a way to serialize the SQL value into a human-readable
        format, suitable for logging or debugging purposes.

        Args:
            writer: The writer to which the string representation will be written.
        """
        if self.isa[Null]():
            writer.write_string("NULL")
        elif self.isa[Integer]():
            writer.write(self[Integer].value)
        elif self.isa[Real]():
            writer.write(self[Real].value)
        elif self.isa[Text[Self.stmt]]():
            writer.write("'", self[Text[Self.stmt]].value, "'")
        elif self.isa[Blob[Self.stmt]]():
            # TODO: Improve blob representation
            writer.write("BLOB(")
            writer.write(len(self[Blob[Self.stmt]].value))
            writer.write(" bytes)")

    def isa[T: SQLRefType](self) -> Bool:
        """Check if the value is of the specified type T.

        This method allows runtime type checking of the stored SQL value.

        Parameters:
            T: The type to check against. Must be Copyable and Movable.

        Returns:
            True if the stored value is of type T, False otherwise.
        """
        return self.value.isa[T]()

    def __getitem_param__[T: SQLRefType](self) -> ref[origin_of(self.value)._get_owned_interior["value"]] T:
        """Get the value as the specified type T.

        This method provides type-safe access to the stored SQL value. The type T
        must implement FromSQL trait and be the correct type for the stored value.

        Parameters:
            T: The type to retrieve the value as. Must be Copyable, Movable, and FromSQL.

        Returns:
            A reference to the value cast to type T.
        """
        return self.value[T]

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
        if self.isa[Text[Self.stmt]]():
            return self[Text[Self.stmt]].value

        raise Error("InvalidColumnTypeError: value is not of type TEXT")

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
        if self.isa[Text[Self.stmt]]():
            return self[Text[Self.stmt]].value
        elif self.isa[Null]():
            return None

        raise Error("InvalidColumnTypeError: value is not of type TEXT")

    def as_int64(self) raises -> Int64:
        """Convert the SQL value to its Int64 representation.

        This method provides a way to get the integer representation
        of the stored SQL value, if it is of type INTEGER.

        Returns:
            An Int64 representing the SQL value.

        Raises:
            Error: If the value is not of type INTEGER.
        """
        if self.isa[Integer]():
            return self[Integer].value

        raise Error("InvalidColumnTypeError: value is not of type INTEGER")

    def as_int64_or_null(self) raises -> Optional[Int64]:
        """Convert the SQL value to its Int64 representation.

        This method provides a way to get the integer representation
        of the stored SQL value, if it is of type INTEGER.

        Returns:
            An Int64 representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type INTEGER or NULL.
        """
        if self.isa[Integer]():
            return self[Integer].value
        elif self.isa[Null]():
            return None

        raise Error("InvalidColumnTypeError: value is not of type INTEGER")

    def as_float64(self) raises -> Float64:
        """Convert the SQL value to its Float64 representation.

        This method provides a way to get the floating-point representation
        of the stored SQL value, if it is of type REAL.

        Returns:
            A Float64 representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type REAL.
        """
        if self.isa[Real]():
            return self[Real].value

        raise Error("InvalidColumnTypeError: value is not of type REAL")

    def as_float64_or_null(self) raises -> Optional[Float64]:
        """Convert the SQL value to its Float64 representation.

        This method provides a way to get the floating-point representation
        of the stored SQL value, if it is of type REAL.

        Returns:
            A Float64 representing the SQL value, or None if the value is NULL.

        Raises:
            Error: If the value is not of type REAL or NULL.
        """
        if self.isa[Real]():
            return self[Real].value
        elif self.isa[Null]():
            return None

        raise Error("InvalidColumnTypeError: value is not of type REAL")

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
        if self.isa[Blob[Self.stmt]]():
            return self[Blob[Self.stmt]].value

        raise Error("InvalidColumnTypeError: value is not of type BLOB")

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
        if self.isa[Blob[Self.stmt]]():
            return self[Blob[Self.stmt]].value
        elif self.isa[Null]():
            return None

        raise Error("InvalidColumnTypeError: value is not of type BLOB")

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
        if self.isa[Blob[Self.stmt]]():
            return self[Blob[Self.stmt]].value
        if self.isa[Text[Self.stmt]]():
            return self[Text[Self.stmt]].value.as_bytes()

        raise Error("InvalidColumnTypeError: value is not of type BLOB or TEXT")

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
        if self.isa[Blob[Self.stmt]]():
            return self[Blob[Self.stmt]].value
        if self.isa[Text[Self.stmt]]():
            return self[Text[Self.stmt]].value.as_bytes()
        elif self.isa[Null]():
            return None

        raise Error("InvalidColumnTypeError: value is not of type BLOB or TEXT")
