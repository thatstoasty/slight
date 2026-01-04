from utils.variant import Variant


@fieldwise_init
struct Parameter(Copyable):
    """A parameter for a SQLite3 prepared statement."""

    var value: Variant[
        String,
        Int,
        Int8,
        Int16,
        Int32,
        Int64,
        UInt,
        UInt8,
        UInt16,
        UInt32,
        UInt64,
        Float16,
        Float32,
        Float64,
        Bool,
        NoneType,
    ]
    """The actual value of the parameter."""

    @implicit
    fn __init__(out self, value: NoneType = None):
        self.value = value

    @implicit
    fn __init__(out self, value: String):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Int):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Int8):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Int16):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Int32):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Int64):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: UInt):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: UInt8):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: UInt16):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: UInt32):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: UInt64):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Float16):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Float32):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Float64):
        self.value = value.copy()

    @implicit
    fn __init__(out self, value: Bool):
        self.value = value.copy()

    fn copy(self) -> Self:
        return Self(self.value.copy())

    fn isa[T: Copyable & Movable](self) -> Bool:
        return self.value.isa[T]()

    fn __getitem__[T: Copyable & Movable](self) -> ref [self.value] T:
        return self.value[T]
