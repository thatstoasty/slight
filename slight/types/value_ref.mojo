from utils.variant import Variant


trait SQLType:
    """A marker trait for types that represent SQL values."""

    pass


comptime InvalidColumnTypeError = "InvalidColumnType: Unsupported value type"


@fieldwise_init
struct SQLite3Null(Copyable, Movable, SQLType):
    """Represents a SQL NULL value.

    This is a zero-sized struct that represents the absence of a value
    in SQL contexts. It implements the necessary traits for SQL value
    handling and can be copied and moved efficiently.
    """

    pass


@fieldwise_init
struct SQLite3Integer(Copyable, Movable, SQLType):
    """Represents a SQL INTEGER value.

    This struct wraps a 64-bit signed integer value as used by SQLite.
    SQLite uses 64-bit integers internally for all integer values.
    """

    var value: Int64


@fieldwise_init
struct SQLite3Real(Copyable, Movable, SQLType):
    """Represents a SQL REAL (floating-point) value.

    This struct wraps a 64-bit floating-point value as used by SQLite.
    SQLite uses double-precision floating-point numbers for all real values.
    """

    var value: Float64


@fieldwise_init
struct SQLite3Text[stmt: ImmutOrigin](Copyable, Movable, SQLType):
    """Represents a SQL TEXT value.

    This struct wraps a text string value from SQLite. The text is stored
    as a StringSlice that references memory owned by the SQLite statement,
    so it's only valid for the lifetime of the statement.

    Parameters:
        stmt: The origin of the statement that owns the text memory.
    """

    var value: StringSlice[Self.stmt]


@fieldwise_init
struct SQLite3Blob[stmt: ImmutOrigin](Copyable, Movable, SQLType):
    """Represents a SQL BLOB (binary large object) value.

    This struct wraps binary data from SQLite. The data is stored as a Span
    that references memory owned by the SQLite statement, so it's only valid
    for the lifetime of the statement.

    Parameters:
        stmt: The origin of the statement that owns the blob memory.
    """

    var value: Span[Byte, Self.stmt]


struct ValueRef[stmt: ImmutOrigin]:
    """A non-owning dynamic type value. Typically, the memory backing this value is var by SQLite.

    See [`Value`](Value) for an owning dynamic type value.
    """

    comptime _type = Variant[SQLite3Null, SQLite3Integer, SQLite3Real, SQLite3Text[Self.stmt], SQLite3Blob[Self.stmt]]
    """The underlying variant type for the SQL value."""
    var value: Self._type
    """The actual value stored in the variant."""

    fn __init__(out self, var value: SQLite3Null):
        """Initialize a ValueRef with a NULL value.

        Args:
            value: The SQLite3Null value to store.
        """
        self.value = value^

    fn __init__(out self, var value: SQLite3Integer):
        """Initialize a ValueRef with an INTEGER value.

        Args:
            value: The SQLite3Integer value to store.
        """
        self.value = value^

    fn __init__(out self, var value: SQLite3Real):
        """Initialize a ValueRef with a REAL (floating-point) value.

        Args:
            value: The SQLite3Real value to store.
        """
        self.value = value^

    fn __init__(out self, var value: SQLite3Text):
        """Initialize a ValueRef with a TEXT value.

        Args:
            value: The SQLite3Text value to store.
        """
        self.value = value^

    fn __init__(out self, var value: SQLite3Blob):
        """Initialize a ValueRef with a BLOB value.

        Args:
            value: The SQLite3Blob value to store.
        """
        self.value = value^

    fn isa[T: SQLType](self) -> Bool:
        """Check if the value is of the specified type T.

        This method allows runtime type checking of the stored SQL value.

        Parameters:
            T: The type to check against. Must be Copyable and Movable.

        Returns:
            True if the stored value is of type T, False otherwise.
        """
        return self.value.isa[T]()

    fn __getitem__[T: SQLType](self) -> ref [self.value] T:
        """Get the value as the specified type T.

        This method provides type-safe access to the stored SQL value. The type T
        must implement FromSQL trait and be the correct type for the stored value.

        Parameters:
            T: The type to retrieve the value as. Must be Copyable, Movable, and FromSQL.

        Returns:
            A reference to the value cast to type T.
        """
        return self.value[T]

    fn as_string_slice(self) raises -> StringSlice[Self.stmt]:
        """Convert the SQL value to its string representation.

        This method provides a way to get a human-readable string representation
        of the stored SQL value, regardless of its actual type.

        Returns:
            A String representing the SQL value.
        """
        if self.isa[SQLite3Text[Self.stmt]]():
            return self[SQLite3Text[Self.stmt]].value

        raise Error(InvalidColumnTypeError)

    fn as_string_slice_or_null(self) raises -> Optional[StringSlice[Self.stmt]]:
        """Convert the SQL value to its string representation.

        This method provides a way to get a human-readable string representation
        of the stored SQL value, regardless of its actual type.

        Returns:
            A String representing the SQL value, or None if the value is NULL.
        """
        if self.isa[SQLite3Text[Self.stmt]]():
            return self[SQLite3Text[Self.stmt]].value
        elif self.isa[SQLite3Null]():
            return None

        raise Error(InvalidColumnTypeError)

    fn as_int64(self) raises -> Int64:
        """Convert the SQL value to its Int64 representation.

        This method provides a way to get the integer representation
        of the stored SQL value, if it is of type INTEGER.

        Returns:
            An Int64 representing the SQL value.
        """
        if self.isa[SQLite3Integer]():
            return self[SQLite3Integer].value

        raise Error(InvalidColumnTypeError)

    fn as_int64_or_null(self) raises -> Optional[Int64]:
        """Convert the SQL value to its Int64 representation.

        This method provides a way to get the integer representation
        of the stored SQL value, if it is of type INTEGER.

        Returns:
            An Int64 representing the SQL value, or None if the value is NULL.
        """
        if self.isa[SQLite3Integer]():
            return self[SQLite3Integer].value
        elif self.isa[SQLite3Null]():
            return None

        raise Error(InvalidColumnTypeError)

    fn as_float64(self) raises -> Float64:
        """Convert the SQL value to its Float64 representation.

        This method provides a way to get the floating-point representation
        of the stored SQL value, if it is of type REAL.

        Returns:
            A Float64 representing the SQL value, or None if the value is NULL.
        """
        if self.isa[SQLite3Real]():
            return self[SQLite3Real].value

        raise Error(InvalidColumnTypeError)

    fn as_float64_or_null(self) raises -> Optional[Float64]:
        """Convert the SQL value to its Float64 representation.

        This method provides a way to get the floating-point representation
        of the stored SQL value, if it is of type REAL.

        Returns:
            A Float64 representing the SQL value, or None if the value is NULL.
        """
        if self.isa[SQLite3Real]():
            return self[SQLite3Real].value
        elif self.isa[SQLite3Null]():
            return None

        raise Error(InvalidColumnTypeError)

    fn as_blob(self) raises -> Span[Byte, Self.stmt]:
        """Convert the SQL value to its BLOB representation.

        This method provides a way to get the binary data representation
        of the stored SQL value, if it is of type BLOB.

        Returns:
            A Span of Bytes representing the SQL value.
        """
        if self.isa[SQLite3Blob[Self.stmt]]():
            return self[SQLite3Blob[Self.stmt]].value

        raise Error(InvalidColumnTypeError)

    fn as_blob_or_null(self) raises -> Optional[Span[Byte, Self.stmt]]:
        """Convert the SQL value to its BLOB representation.

        This method provides a way to get the binary data representation
        of the stored SQL value, if it is of type BLOB.

        Returns:
            A Span of Bytes representing the SQL value, or None if the value is NULL.
        """
        if self.isa[SQLite3Blob[Self.stmt]]():
            return self[SQLite3Blob[Self.stmt]].value
        elif self.isa[SQLite3Null]():
            return None

        raise Error(InvalidColumnTypeError)

    fn as_bytes(self) raises -> Span[Byte, Self.stmt]:
        """Convert the SQL value to a byte representation.

        This method provides a way to get byte data for either BLOB or TEXT SQL values.

        Returns:
            A Span of Bytes representing the SQL value.
        """
        if self.isa[SQLite3Blob[Self.stmt]]():
            return self[SQLite3Blob[Self.stmt]].value
        if self.isa[SQLite3Text[Self.stmt]]():
            return self[SQLite3Text[Self.stmt]].value.as_bytes()

        raise Error(InvalidColumnTypeError)

    fn as_bytes_or_null(self) raises -> Optional[Span[Byte, Self.stmt]]:
        """Convert the SQL value to a byte representation.

        This method provides a way to get byte data for either BLOB or TEXT SQL values.

        Returns:
            A Span of Bytes representing the SQL value, or None if the value is NULL.
        """
        if self.isa[SQLite3Blob[Self.stmt]]():
            return self[SQLite3Blob[Self.stmt]].value
        if self.isa[SQLite3Text[Self.stmt]]():
            return self[SQLite3Text[Self.stmt]].value.as_bytes()
        elif self.isa[SQLite3Null]():
            return None

        raise Error(InvalidColumnTypeError)
