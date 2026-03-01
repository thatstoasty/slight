from std.sys.intrinsics import _type_is_eq
from slight.types.value_ref import ValueRef


trait FromSQL(Copyable):
    """A trait for types that can be constructed from a SQL value."""

    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        ...


__extension Int(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        self = Self(value.as_int64())


# __extension Optional(FromSQL):
#     fn __init__(out self: Self, value: ValueRef) raises:
#         self = Self(T(value.as_int64()))


__extension String(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        self = Self(value.as_string_slice())


# __extension StringSlice(FromSQL):
#     fn __init__(out self, value: ValueRef[Self.origin]) raises:
#         var val = value.as_string_slice()
#         self = val


__extension Bool(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        self = value.as_int64() == 1


__extension NoneType(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        self = None


__extension SIMD(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        comptime if dtype in (DType.float16, DType.float32, DType.float64):
            self = Scalar[dtype](value.as_float64())
        elif dtype in (DType.int8, DType.int16, DType.int32, DType.int64,
                       DType.uint, DType.uint8, DType.uint16, DType.uint32, DType.uint64):
            self = Scalar[dtype](value.as_int64())
        else:
            raise Error("InvalidColumnTypeError: Unsupported value type")


__extension List(FromSQL):
    # fn __init__(out self, value: ValueRef) raises where _type_is_eq_parse_time[
    #     Self.T, Byte
    # ]():
    fn __init__(out self, value: ValueRef) raises:
        """Initializes the type from a SQL value.

        Args:
            value: The SQL value to construct the type from.
        
        Raises:
            Error: If the value cannot be converted to the type.
        """
        comptime assert _type_is_eq[Self.T, Byte]()
        self = rebind_var[List[Self.T]](
            List[Byte](value.as_blob())
        )
