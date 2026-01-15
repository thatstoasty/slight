from utils.variant import Variant
from sys.intrinsics import _type_is_eq, _type_is_eq_parse_time
from builtin.constrained import _constrained_conforms_to
from slight.statement import Statement


trait Params:

    fn bind(self, stmt: Statement) raises:
        ...


__extension List(Params):

    fn bind(self, stmt: Statement) raises where conforms_to(Self.T, ToSQL):
        _constrained_conforms_to[
            conforms_to(T, ToSQL),
            Parent=Self,
            Element=T,
            ParentConformsTo="Params",
            ElementConformsTo="ToSQL",
        ]()
        
        # stmt.bind_parameters(self)
        var expected = Int(stmt.stmt.bind_parameter_count())
        var index = 0
        for i in range(len(self)):
            ref elem = trait_downcast[ToSQL](self[i])
            index += 1  # The leftmost SQL parameter has an index of 1.
            if index > expected:
                break
            stmt.bind_parameter(elem, UInt(index))
        if index != expected:
            raise Error("Invalid parameter count: ", index, ", expected: ", expected)


__extension Dict(Params):

    fn bind(self, stmt: Statement) raises:
        _constrained_conforms_to[
            conforms_to(V, ToSQL),
            Parent=Self,
            Element=V,
            ParentConformsTo="Params",
            ElementConformsTo="ToSQL",
        ]()
        
        for kv in self.items():
            ref key = rebind[String](kv.key)
            var i = stmt.parameter_index(key)
            if not i:
                raise Error("ParameterNotFoundError: Invalid parameter name: ", key)

            ref value = trait_downcast[ToSQL](kv.value)
            stmt.bind_parameter(value, i[])


# __extension List(Params):

#     fn bind(self, stmt: Statement) raises where _type_is_eq_parse_time(Self.T, ToSQL):
#         _constrained_conforms_to[
#             conforms_to(V, ToSQL),
#             Parent=Self,
#             Element=V,
#             ParentConformsTo="Params",
#             ElementConformsTo="ToSQL",
#         ]()
        
#         for kv in self:
#             ref key = rebind[String](kv[0])
#             var i = stmt.parameter_index(key)
#             if not i:
#                 raise Error("ParameterNotFoundError: Invalid parameter name: ", key)

#             ref value = trait_downcast[ToSQL](kv[1])
#             stmt.bind_parameter(value, i[])


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
        List[Byte],
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
    
    @implicit
    fn __init__(out self, value: Span[Byte]):
        self.value = List[Byte](value)

    fn copy(self) -> Self:
        return Self(self.value.copy())

    fn isa[T: AnyType](self) -> Bool:
        return self.value.isa[T]()

    fn __getitem__[T: AnyType](self) -> ref [self.value] T:
        return self.value[T]
