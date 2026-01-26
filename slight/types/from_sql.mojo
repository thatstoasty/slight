from sys.intrinsics import _type_is_eq_parse_time
from utils.variant import Variant
from slight.types.value_ref import ValueRef, InvalidColumnTypeError


@fieldwise_init
struct FromSQLConversionError(Movable, Writable):
    var err: Variant[InvalidColumnTypeError]

    @implicit
    fn __init__(out self, e: InvalidColumnTypeError):
        self.err = e


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


# __extension StringSlice(FromSQL):
#     fn __init__(out self, value: ValueRef[Self.origin]) raises:
#         var val = value.as_string_slice()
#         self = val


__extension Bool(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        self = value.as_int64() == 1


__extension NoneType(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        self = None


__extension SIMD(FromSQL):
    fn __init__(out self, value: ValueRef) raises:
        @parameter
        if dtype in (DType.float16, DType.float32, DType.float64):
            self = Scalar[dtype](value.as_float64())
        elif dtype in (DType.int8, DType.int16, DType.int32, DType.int64,
                       DType.uint, DType.uint8, DType.uint16, DType.uint32, DType.uint64):
            self = Scalar[dtype](value.as_int64())
        else:
            raise InvalidColumnTypeError()


__extension List(FromSQL):
    fn __init__(out self, value: ValueRef) raises where _type_is_eq_parse_time[
        Self.T, Byte
    ]():
        self = Self(value.as_blob())
