"""Bind parameter indexing for SQLite statements.

This module provides the BindIndex trait and implementations for types that can
be used to index into parameters of a SQL statement. It allows parameters to be
referenced by position (Int/UInt) or by name (String/StringSlice).
"""

from slight.statement import Statement


@fieldwise_init
struct BindIndexError(Movable, Writable):
    var msg: String

    fn write_to[W: Writer, //](self, mut writer: W):
        writer.write_string(self.msg)



trait BindIndex(Movable):
    """A trait implemented by types that can index into parameters of a statement.

    This trait is implemented for Int, UInt, String, and StringSlice types.
    """

    fn idx(self, stmt: Statement) raises BindIndexError -> UInt:
        """Returns the index of the associated parameter.

        Args:
            stmt: The statement to index into.

        Returns:
            The 1-based index of the parameter.

        Raises:
            Error: If no such parameter exists or the parameter name is invalid.
        """
        ...


__extension Int(BindIndex):
    fn idx(self, stmt: Statement) -> UInt:
        """Returns the index directly without validation.

        Args:
            stmt: The statement (unused for Int indexing).

        Returns:
            The parameter index as a UInt.
        """
        # No validation - direct conversion
        return UInt(self)


__extension String(BindIndex):
    fn idx(self, stmt: Statement) raises BindIndexError -> UInt:
        """Returns the index of the parameter with the given name.

        Args:
            stmt: The statement to search for the parameter name.

        Returns:
            The 1-based index of the parameter.

        Raises:
            Error: If the parameter name is not found in the statement.
        """
        var result = stmt.parameter_index(self)
        if not result:
            raise BindIndexError(String("Received an invalid parameter name: ", self))
        return result.value()


__extension StringSlice(BindIndex):
    fn idx(self, stmt: Statement) raises BindIndexError -> UInt:
        """Returns the index of the parameter with the given name.

        Args:
            stmt: The statement to search for the parameter name.

        Returns:
            The 1-based index of the parameter.

        Raises:
            Error: If the parameter name is not found in the statement.
        """
        var name = String(self)
        var result = stmt.parameter_index(name)
        if not result:
            raise BindIndexError(String("Received an invalid parameter name: ", name))
        return result.value()
