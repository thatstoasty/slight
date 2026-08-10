from slight.types.value_ref import ValueRef, SQLite3Null
from std.builtin.rebind import downcast


trait FromSQL(Movable):
    """A trait for types that can be constructed from a SQL value."""

    def __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.

        Raises:
            Error: If the value cannot be converted to the type.
        """
        ...


__extension Optional(FromSQL):
    def __init__(out self, value: ValueRef) raises:
        # Assert T conforms to FromSQL at compile time.
        # Then that enables us to safely downcast the value to T and call its FromSQL initializer.
        # We rely on the that initializer to properly construct itself from the sqlite value.
        comptime assert conforms_to(Self.T, FromSQL), String(
            "Optional can only be used with types that implement `FromSQL`. ",
            reflect[Self.T].name(),
            " does not implement `FromSQL`.",
        )
        if value.isa[SQLite3Null]():
            self = Optional[Self.T](None)
        else:
            self = Optional[Self.T](downcast[Self.T, FromSQL](value))


__extension String(FromSQL):
    def __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.

        Raises:
            Error: If the value cannot be converted to the type.
        """
        self = Self(value.unsafe_as_string_slice())


__extension Bool(FromSQL):
    def __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.

        Raises:
            Error: If the value cannot be converted to the type.
        """
        # SQLite has no boolean storage class: any non-zero INTEGER is true.
        self = value.as_int64() != 0


__extension NoneType(FromSQL):
    def __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.

        Raises:
            Error: If the value cannot be converted to the type.
        """
        self = None


__extension SIMD(FromSQL):
    def __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.

        Raises:
            Error: If the value cannot be converted to the type.
        """
        comptime assert Self.length == 1, "Only SIMD vectors of size 1 can be constructed from SQL parameters"
        comptime float_types = [DType.float16, DType.float32, DType.float64]
        comptime int_types = [
            DType.int,
            DType.int8,
            DType.int16,
            DType.int32,
            DType.int64,
            DType.uint,
            DType.uint8,
            DType.uint16,
            DType.uint32,
            DType.uint64,
        ]
        comptime assert (Self.dtype in int_types or Self.dtype in float_types), String("To construct a SIMD type from a ValueRef, it must be one of the int or float dtypes. Received: {Self.dtype}")

        comptime if Self.dtype in (DType.float16, DType.float32, DType.float64):
            self = Scalar[Self.dtype](value.as_float64())
        elif Self.dtype in (
            DType.int,
            DType.int8,
            DType.int16,
            DType.int32,
            DType.int64,
            DType.uint,
            DType.uint8,
            DType.uint16,
            DType.uint32,
            DType.uint64,
        ):
            self = Scalar[Self.dtype](value.as_int64())
        else:
            raise Error("InvalidColumnTypeError: Unsupported value type")


__extension List(FromSQL):
    def __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.

        Raises:
            Error: If the value cannot be converted to the type.
        """
        comptime assert Self.T == Byte, String(
            t"List can only be used with Byte type for `FromSQL`. {reflect[Self.T].name()} is not Byte."
        )
        self = rebind_var[List[Self.T]](List[Byte](value.unsafe_as_blob()))
