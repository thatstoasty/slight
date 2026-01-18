from sys.intrinsics import _type_is_eq_parse_time
from builtin.constrained import _constrained_conforms_to
from slight.statement import Statement
from slight.bind import BindIndex


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
            conforms_to(Self.K, BindIndex),
            Parent=Self,
            Element=Self.K,
            ParentConformsTo="Params",
            ElementConformsTo="BindIndex",
        ]()
        _constrained_conforms_to[
            conforms_to(Self.V, ToSQL) and conforms_to(Self.K, BindIndex),
            Parent=Self,
            Element=Self.V,
            ParentConformsTo="Params",
            ElementConformsTo="ToSQL",
        ]()
        
        for kv in self.items():
            ref value = trait_downcast[ToSQL](kv.value)
            stmt.bind_parameter(value, trait_downcast[BindIndex](kv.key).idx(stmt))


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
