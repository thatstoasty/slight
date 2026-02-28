from slight.bind import BindIndex
from slight.statement import Statement
from std.builtin.constrained import _constrained_conforms_to
from std.reflection import get_type_name


trait Params(Movable):
    """A trait for types that can be used as parameters in SQL queries."""

    fn bind(self, stmt: Statement) raises:
        """Binds the parameters to the given statement.

        Args:
            stmt: The statement to bind the parameters to.

        Raises:
            Error: If the parameters cannot be bound to the statement.
        """
        ...


__extension List(Params):
    fn bind(self, stmt: Statement) raises:
        """Binds the parameters to the given statement.

        Args:
            self: Temporary docstring due to extension bug.
            stmt: The statement to bind the parameters to.

        Raises:
            Error: If the parameters cannot be bound to the statement.
        """
        _constrained_conforms_to[
            conforms_to(Self.T, ToSQL),
            Parent=Self,
            Element = Self.T,
            ParentConformsTo="Params",
            ElementConformsTo="ToSQL",
        ]()

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
        """Binds the parameters to the given statement.

        Args:
            self: Temporary docstring due to extension bug.
            stmt: The statement to bind the parameters to.

        Raises:
            Error: If the parameters cannot be bound to the statement.
        """
        _constrained_conforms_to[
            conforms_to(Self.K, BindIndex),
            Parent=Self,
            Element = Self.K,
            ParentConformsTo="Params",
            ElementConformsTo="BindIndex",
        ]()
        _constrained_conforms_to[
            conforms_to(Self.V, ToSQL) and conforms_to(Self.K, BindIndex),
            Parent=Self,
            Element = Self.V,
            ParentConformsTo="Params",
            ElementConformsTo="ToSQL",
        ]()

        for kv in self.items():
            ref value = trait_downcast[ToSQL](kv.value)
            stmt.bind_parameter(value, trait_downcast[BindIndex](kv.key).bind_idx(stmt))


__extension Tuple(Params):
    fn bind(self, stmt: Statement) raises:
        """Binds the parameters to the given statement.

        Args:
            self: Temporary docstring due to extension bug.
            stmt: The statement to bind the parameters to.

        Raises:
            Error: If the parameters cannot be bound to the statement.
        """
        comptime parameter_count = Variadic.size(Self.element_types)
        comptime if parameter_count == 0:
            return  # No parameters to bind

        var expected = Int(stmt.stmt.bind_parameter_count())
        var index = 0
        comptime for i in range(Variadic.size(Self.element_types)):
            comptime assert conforms_to(Self.element_types[i], ToSQL), String(
                "All elements of the tuple must conform to `ToSQL`. Element at index ",
                i,
                "of type ",
                get_type_name[Self.element_types[i]](),
                " does not conform to `ToSQL`",
            )
            index += 1  # The leftmost SQL parameter has an index of 1.
            if index > expected:
                break
            stmt.bind_parameter(trait_downcast[ToSQL](self[i]), UInt(index))
        if index != expected:
            raise Error("Invalid parameter count: ", index, ", expected: ", expected)
