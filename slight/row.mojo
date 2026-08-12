"""Result rows."""
from std.builtin.rebind import downcast
from slight.types.from_sql import FromSQL
from slight.statement import Statement
from slight.types.value_ref import ValueRef
from slight.util import MoveDestructible


trait RowIndex:
    """A trait for types that can be used to index columns in a Row."""

    def idx(self, stmt: Statement) raises -> UInt:
        """Convert this index type to a UInt column index.

        Args:
            stmt: The statement to index into.

        Returns:
            A UInt representing the column index (0-based).

        Raises:
            Error: If the index cannot be converted to a valid column index.
        """
        ...


__extension SIMD(RowIndex):
    def idx(self, stmt: Statement) raises -> UInt:
        """Convert this index type to a UInt column index.

        Args:
            self: Temporary docstring due to extension bug.
            stmt: The statement to index into.

        Returns:
            A UInt representing the column index (0-based).

        Raises:
            Error: If the index cannot be converted to a valid column index.
        """
        comptime assert Self.length == 1, "RowIndex must be a scalar SIMD value (length == 1)."
        if self < 0 or UInt(self) >= stmt.column_count():
            raise Error("Invalid column index: ", self)

        return UInt(self)


__extension String(RowIndex):
    def idx(self, stmt: Statement) raises -> UInt:
        """Convert this index type to a UInt column index.

        Args:
            self: Temporary docstring due to extension bug.
            stmt: The statement to index into.

        Returns:
            A UInt representing the column index (0-based).

        Raises:
            Error: If the index cannot be converted to a valid column index.
        """
        return stmt.column_index(self)


__extension StringSpan(RowIndex):
    def idx(self, stmt: Statement) raises -> UInt:
        """Convert this index type to a UInt column index.

        Args:
            self: Temporary docstring due to extension bug.
            stmt: The statement to index into.

        Returns:
            A UInt representing the column index (0-based).

        Raises:
            Error: If the index cannot be converted to a valid column index.
        """
        return stmt.column_index(self)


# comptime RowTransformFn[T: Movable, conn: MutOrigin, statement: MutOrigin] = def(Row[conn, statement]) raises -> T
# """A type alias for a function that transforms a Row into a value of type T.

# Parameters:
#     T: The target type to transform the Row into.
#     conn: The connection associated with the Row.
#     statement: The statement associated with the Row.
# """

# TODO: I tried to include the connection and statement origins in the RowTransformFn type alias,
# but it causes parameter binding issues in the connection class.
# And I don't want to constrain functionality more.
comptime RowTransformFn[T: Movable] = def[conn: MutOrigin, statement: MutOrigin](Row[conn, statement]) raises thin -> T
"""A type alias for a function that transforms a Row into a value of type T.

Parameters:
    T: The target type to transform the Row into.
"""
comptime BoundRowTransformFn[T: Movable, conn: MutOrigin, statement: MutOrigin] = def(
    Row[conn, statement]
) raises thin -> T
"""A type alias for a function that transforms a Row into a value of type T.

Parameters:
    T: The target type to transform the Row into.
    conn: The connection associated with the Row.
    statement: The statement associated with the Row.
"""


@fieldwise_init
struct Row[conn: MutOrigin, statement: MutOrigin](Copyable, Writable):
    """Represents a single row in the result set of a SQL query.

    A `Row` is only meaningful while the statement is positioned on it.
    Advancing the iterator (or calling `reset()`/`finalize()`) moves the
    statement to the next row and invalidates the SQLite-owned memory backing
    the current one.

    Use `get[T]()` — `get[String]()`, `get[List[Byte]]()`, `get[Int64]()`,
    `get[Optional[Int64]]()` for nullable columns — which copies out of
    SQLite's buffers and stays valid for as long as you hold it.

    `get_ref()` is the zero-copy escape hatch: it returns a `ValueRef`
    borrowing SQLite memory, valid only while the statement stays on this row.
    The compiler does not enforce that bound, which is why its accessors are
    `unsafe_`-prefixed.

    Parameters:
        conn: The connection that produced this row.
        statement: The statement that produced this row.
    """

    var stmt: Pointer[Statement[Self.conn], Self.statement]
    """A pointer to the statement that produced this row."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes a string representation of the row to the provided writer.

        Args:
            writer: A mutable reference to a Writer where the row representation will be written.
        """
        writer.write_string("(")
        var column_count = self.stmt[].column_count()
        for i in range(column_count):
            if i > 0:
                writer.write_string(", ")
            writer.write(self.stmt[].value_ref(i))
        writer.write_string(")")

    def get_ref(self, idx: Some[RowIndex]) raises -> type_of(self.stmt[].value_ref(0)):
        """Gets a borrowed `ValueRef` view of the specified column.

        This is the zero-copy escape hatch. The returned `ValueRef` borrows
        memory owned by SQLite: it is only valid while the statement stays on
        the current row. Its `unsafe_*` accessors document the exact
        invalidation rules.

        For almost all uses prefer `get[T]()`, which copies the value out and
        stays valid independently of the statement.

        Args:
            idx: The column index (0-based).

        Returns:
            A `ValueRef` borrowing the column's value for the current row.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
        """
        var i = idx.idx(self.stmt[])
        if i >= self.stmt[].column_count():
            raise Error("InvalidColumnIndexError: column index out of bounds: ", i)

        return self.stmt[].value_ref(i)

    def get[S: Movable, I: AnyType](self, idx: I) raises -> S:
        """Gets a value of type S from the specified column using generic type conversion.

        This is a generic method that can retrieve values of any supported type,
        making the API more ergonomic by eliminating the need for type-specific methods.

        Parameters:
            S: The type to convert the column value to. Supported types are:
               Int, SIMD types (Int8/UInt8 to Int64/UInt64, Float16 to Float64, Int), String, Bool, and NoneType.
            I: The type used to specify the column index (0-based). Can be Int, UInt, String, or StringSpan.

        Args:
            idx: The column index (0-based).

        Returns:
            An object of type `S`.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            Error: If the column value cannot be converted to type `S`.
        """
        comptime assert conforms_to(S, FromSQL), String(
            t"S must implement `FromSQL`. {reflect[S].name()} does not implement `FromSQL`."
        )
        comptime assert conforms_to(I, RowIndex), String(
            t"I must implement `RowIndex`. {reflect[I].name()} does not implement `RowIndex`."
        )

        var i = idx.idx(self.stmt[])
        return downcast[S, FromSQL](self.stmt[].value_ref(i))


@fieldwise_init
struct Rows[conn: MutOrigin, statement: MutOrigin](Copyable, Iterator):
    """An iterator over rows returned by a SQL query.

    Parameters:
        conn: The connection that produced these rows.
        statement: The statement that produces these rows.
    """

    comptime Element = Row[Self.conn, Self.statement]
    """The type of elements produced by this iterator."""

    var stmt: Pointer[Statement[Self.conn], Self.statement]
    """A pointer to the statement that produces rows."""

    def __next__(
        mut self,
    ) raises StopIteration -> Self.Element:
        """Returns the next row in the result set.

        Returns:
            The next Row in the result set.

        Raises:
            StopIteration: If there are no more rows to return.
        """
        try:
            if self.stmt[].step():
                return Row(self.stmt)
            else:
                self.reset()
                raise StopIteration()
        except:
            raise StopIteration()

    def __iter__(self) -> Self:
        """Returns an iterator over the rows.

        Returns:
            Self as an iterator.
        """
        return self.copy()

    def reset(self) -> None:
        """Resets the statement to allow re-iteration.

        This method resets the underlying statement so that iteration
        can begin again from the first row.
        """
        try:
            self.stmt[].reset()
        except e:
            print("Error resetting statement:", e)
            # TODO: come back to resetting this to avoid infinite loops
            # raise

    def map[
        T: Movable, //, transform: RowTransformFn[T]
    ](self,) -> MappedRows[transform[Self.conn, Self.statement]]:
        """Returns an iterator that transforms each row using the provided function.

        Parameters:
            T: The target type to map each row to.
            transform: A function that takes a Row and returns a value of type T.

        Returns:
            An iterator that yields transformed rows.
        """
        return MappedRows[transform[Self.conn, Self.statement]](self)

    def as_type[
        T: MoveDestructible
    ](self,) -> TypedRows[Self.conn, Self.statement, T]:
        """Returns an iterator that transforms each row using the provided function.

        Parameters:
            T: The target struct type to map each row to.

        Returns:
            An iterator that yields transformed rows.
        """
        return TypedRows[Self.conn, Self.statement, T](self)


struct MappedRows[
    T: Movable, conn: MutOrigin, statement: MutOrigin, //, transform: BoundRowTransformFn[T, conn, statement]
](Copyable, Iterator):
    """An iterator that transforms rows using a mapping function.

    Parameters:
        T: The target type to map each row to.
        conn: The connection that produced these rows.
        statement: The statement that produces these rows.
        transform: The function to apply to each row.
    """

    comptime Element = Self.T
    """The type of elements produced by this iterator."""

    var rows: Rows[Self.conn, Self.statement]
    """The underlying rows iterator."""

    def __init__(out self, rows: Rows[Self.conn, Self.statement]):
        """Initializes a new MappedRows iterator.

        Args:
            rows: The underlying rows iterator to transform.
        """
        self.rows = rows.copy()

    def __next__(mut self) raises StopIteration -> Self.T:
        """Returns the next transformed row.

        Returns:
            The next row transformed by the mapping function.

        Raises:
            StopIteration: If there are no more rows to return or if the transformation fails.
        """
        var result = self.rows.__next__()
        try:
            return Self.transform(result)
        except e:
            raise StopIteration()

    def __iter__(self) -> Self:
        """Returns an iterator over the transformed rows.

        Returns:
            Self as an iterator.
        """
        return self.copy()

    def reset(self) -> None:
        """Resets the underlying rows iterator.

        This method resets the underlying rows iterator so that iteration
        can begin again from the first row.
        """
        self.rows.reset()

    def collect(self) -> List[Self.T]:
        """Collects the remaining transformed rows into a `List`.

        Returns:
            A `List` containing every remaining transformed row.
        """
        var result = List[Self.T]()
        for var item in self:
            result.append(item^)
        return result^


def __all_dtors_are_trivial[T: AnyType]() -> Bool:
    comptime r = reflect[T]
    comptime for i in range(r.field_count()):
        comptime type = r.field_types()[i]
        if not downcast[type, Deinitable].__del__is_trivial:
            return False
    return True


struct TypedRows[conn: MutOrigin, statement: MutOrigin, T: MoveDestructible](Copyable, Iterator):
    """An iterator that transforms rows using a mapping function.

    Parameters:
        conn: The connection that produced these rows.
        statement: The statement that produces these rows.
        T: The target struct type to map each row to. Must be a struct type where each field implements FromSQL.
    """

    comptime Element = Self.T
    """The type of elements produced by this iterator."""

    var rows: Rows[Self.conn, Self.statement]
    """The underlying rows iterator."""

    def __init__(out self, rows: Rows[Self.conn, Self.statement]):
        """Initializes a new MappedRows iterator.

        Args:
            rows: The underlying rows iterator to transform.
        """
        self.rows = rows.copy()

    @staticmethod
    def _transform(row: Row[Self.conn, Self.statement], out result: Self.T) raises:
        """Transforms a Row into the target type T.

        Args:
            row: The Row to transform.

        Returns:
            The transformed value of type T.

        Raises:
            Error: If the transformation fails.
        """
        comptime if conforms_to(Self.T, Defaultable):
            result = Self.T()
        else:
            # If we use mark_initialized with a struct that has something like a pointer
            # field that doesn't become initialized it will cause a crash if parsing fails.
            comptime assert __all_dtors_are_trivial[
                Self.T
            ](), "Cannot deserialize non-Defaultable struct containing fields with non-trivial destructors"
            __mlir_op.`lit.ownership.mark_initialized`(__get_mvalue_as_litref(result))

        comptime r = reflect[Self.T]
        comptime assert r.is_struct(), "TypedRows can only transform to struct types."

        comptime field_count = r.field_count()
        comptime field_names = r.field_names()
        comptime field_types = r.field_types()

        var column_count = row.stmt[].column_count()
        if field_count != Int(column_count):
            raise Error(
                (
                    t"Field count mismatch: struct '{r.name()}' has {Int(field_count)} fields, but query"
                    t" returned {Int(column_count)} columns."
                ),
            )

        try:
            comptime for i in range(field_count):
                comptime field_name = field_names[i]
                comptime field_type = field_types[i]
                comptime assert conforms_to(field_type, FromSQL), String(
                    t"Field '{field_name}' of struct '{r.name()}' does not implement FromSQL."
                )

                ref field = __struct_field_ref(i, result)
                comptime assert conforms_to(type_of(field), MoveDestructible), String(
                    t"Field '{field_name}' of struct '{r.name()}' does not conform to `Movable & Deinitable`."
                )
                field = row.get[type_of(field)](i)
        except e:
            # TODO: We capture and print the error here because an extension bug swallows errors.
            print(e)
            raise e^

    def __next__(mut self) raises StopIteration -> Self.T:
        """Returns the next transformed row.

        Returns:
            The next row transformed by the mapping function.

        Raises:
            StopIteration: If there are no more rows to return or if the transformation fails.
        """
        var result = self.rows.__next__()
        try:
            return Self._transform(result)
        except e:
            raise StopIteration()

    def __iter__(self) -> Self:
        """Returns an iterator over the transformed rows.

        Returns:
            Self as an iterator.
        """
        return self.copy()

    def reset(self) -> None:
        """Resets the underlying rows iterator.

        This method resets the underlying rows iterator so that iteration
        can begin again from the first row.
        """
        self.rows.reset()

    def collect(self) -> List[Self.T]:
        """Collects the remaining transformed rows into a `List`.

        Returns:
            A `List` containing every remaining transformed row.
        """
        var result = List[Self.T]()
        for var item in self:
            result.append(item^)
        return result^
