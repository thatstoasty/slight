from sys.intrinsics import _type_is_eq, _type_is_eq_parse_time
from slight.types.value_ref import ValueRef


trait FromSQL(Copyable):
    """A trait for types that can be constructed from a SQL value."""

    fn __init__(out self, value: ValueRef) raises:
        ...


__extension Int(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        self = Self(value.as_int64())


# __extension Optional(FromSQL):
#     fn __init__(out self: Self, value: ValueRef) raises:
#         self = Self(T(value.as_int64()))


__extension String(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        self = Self(value.as_string_slice())


__extension Bool(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        self = value.as_int64() == 1


__extension NoneType(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        self = None


__extension SIMD(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        @parameter
        if dtype == DType.int8:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.int16:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.int32:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.int64:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.uint8:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.uint16:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.uint32:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.uint64:
            self = Scalar[dtype](value.as_int64())
        elif dtype == DType.float16:
            self = Scalar[dtype](value.as_float64())
        elif dtype == DType.float32:
            self = Scalar[dtype](value.as_float64())
        elif dtype == DType.float64:
            self = Scalar[dtype](value.as_float64())
        else:
            raise Error("InvalidColumnType: Unsupported SIMD dtype")


__extension List(FromSQL):
    fn __init__(out self, value: ValueRef) raises where _type_is_eq_parse_time[
        Self.T, Byte
    ]():
        self = Self(value.as_blob())
