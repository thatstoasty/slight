from reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
    is_struct_type,
)
from memory import Pointer
from slight.statement import Statement
from slight.types.value_ref import (
    ValueRef,
    SQLite3Blob,
    SQLite3Integer,
    SQLite3Null,
    SQLite3Real,
    SQLite3Text,
)


trait RowIndex:
    fn idx(self, stmt: Statement) raises -> UInt:
        ...


__extension Int(RowIndex):
    fn idx(self, stmt: Statement) raises -> UInt:
        if self < 0 or UInt(self) >= stmt.column_count():
            raise Error("Invalid column index: ", self)

        return UInt(self)


__extension String(RowIndex):
    fn idx(self, stmt: Statement) raises -> UInt:
        return stmt.column_index(self)


__extension StringSlice(RowIndex):
    fn idx(self, stmt: Statement) raises -> UInt:
        return stmt.column_index(self)


@fieldwise_init
struct Row[conn: ImmutOrigin, statement: ImmutOrigin](Copyable, Writable):
    """Represents a single row in the result set of a SQL query."""

    var stmt: Pointer[Statement[Self.conn], Self.statement]
    """A pointer to the statement that produced this row."""

    fn write_to[W: Writer, //](self, mut writer: W):
        writer.write_string("(")
        var column_count = self.stmt[].column_count()
        for i in range(column_count):
            if i > 0:
                writer.write_string(", ")
            writer.write(self.stmt[].value_ref(i))
        writer.write_string(")")
        
    fn get_int64(self, idx: Some[RowIndex]) raises -> Optional[Int]:
        """Gets an Int64 value from the specified column.

        Args:
            idx: The column index (0-based).

        Returns:
            An Optional containing the Int value, or None if the column is NULL.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            InvalidColumnTypeError: If the column does not contain an integer.
        """
        var i = idx.idx(self.stmt[])
        if i >= self.stmt[].column_count():
            raise Error("Invalid column index: ", i)

        var value = self.stmt[].value_ref(i)
        if value.isa[SQLite3Null]():
            return None
        elif value.isa[SQLite3Integer]():
            return Int(value[SQLite3Integer].value)
        raise Error("InvalidColumnTypeError: column is not of type INTEGER")

    fn get_int(self, idx: Some[RowIndex]) raises -> Optional[Int]:
        """Gets an Int value from the specified column.

        Args:
            idx: The column index (0-based).

        Returns:
            An Optional containing the Int value, or None if the column is NULL.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            InvalidColumnTypeError: If the column does not contain an integer.
        """
        var result = self.get_int64(idx)
        if result:
            return Int(result.value())
        return None

    fn get_bool(self, idx: Some[RowIndex]) raises -> Optional[Bool]:
        """Gets a UInt value from the specified column.

        Args:
            idx: The column index (0-based).

        Returns:
            An Optional containing the UInt value, or None if the column is NULL.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            InvalidColumnTypeError: If the column does not contain an integer.
        """
        var result = self.get_int64(idx)
        if result:
            return True if result.value() == 1 else False
        return None

    fn get_float64(self, idx: Some[RowIndex]) raises -> Optional[Float64]:
        """Gets a Float64 value from the specified column.

        Args:
            idx: The column index (0-based).

        Returns:
            An Optional containing the Float64 value, or None if the column is NULL.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            InvalidColumnTypeError: If the column does not contain a real number.
        """
        var i = idx.idx(self.stmt[])
        if i >= self.stmt[].column_count():
            raise Error("InvalidColumnIndexError: column index out of bounds: ", i)

        var value = self.stmt[].value_ref(i)
        if value.isa[SQLite3Null]():
            return None
        elif value.isa[SQLite3Real]():
            return Float64(value[SQLite3Real].value)
        
        raise Error("InvalidColumnTypeError: column is not of type REAL")

    fn get_string_slice(self, idx: Some[RowIndex]) raises -> Optional[StringSlice[Self.conn]]:
        """Gets a StringSlice value from the specified column.

        Args:
            idx: The column index (0-based).

        Returns:
            An Optional containing the StringSlice value, or None if the column is NULL.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            InvalidColumnTypeError: If the column does not contain text.
        """
        var i = idx.idx(self.stmt[])
        if i >= self.stmt[].column_count():
            raise Error("InvalidColumnIndexError: column index out of bounds: ", i)

        var value = self.stmt[].value_ref(i)
        if value.isa[SQLite3Null]():
            return None
        elif value.isa[SQLite3Text[Self.conn]]():
            return value[SQLite3Text[Self.conn]].value
    
        raise Error("InvalidColumnTypeError: column is not of type TEXT")

    # TODO: Parameter inference breaks if I try to put RowIndex first in the parameter list.
    fn get[S: FromSQL, I: RowIndex](self, idx: I) raises -> S:
        """Gets a value of type S from the specified column using generic type conversion.

        This is a generic method that can retrieve values of any supported type,
        making the API more ergonomic by eliminating the need for type-specific methods.

        Parameters:
            S: The type to convert the column value to. Supported types are:
               Int, Float64, String, and Bool.
            I: The type used to specify the column index (0-based). Can be Int, UInt, String, or StringSlice.

        Args:
            idx: The column index (0-based).

        Returns:
            An Optional containing the value of type T, or None if the column is NULL.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
            Error: If the column value cannot be converted to type T.
        """
        var i = idx.idx(self.stmt[])
        return S(self.stmt[].value_ref(i))


@fieldwise_init
struct Rows[conn: ImmutOrigin, statement: ImmutOrigin](Copyable, Iterator):
    """An iterator over rows returned by a SQL query."""

    comptime Element = Row[Self.conn, Self.statement]

    var stmt: Pointer[Statement[Self.conn], Self.statement]
    """A pointer to the statement that produces rows."""
    
    fn __next__(
        mut self,
    ) raises StopIteration -> Self.Element:
        try:
            if self.stmt[].step():
                return Row(self.stmt)
            else:
                self.reset()
                raise StopIteration()
        except:
            raise StopIteration()

    fn __iter__(self) -> Self:
        """Returns an iterator over the rows.

        Returns:
            Self as an iterator.
        """
        return self.copy()

    fn reset(self) -> None:
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
    
    fn map[T: Movable, //, transform: fn (Row) raises -> T](
        self,
    ) -> MappedRows[Self.conn, Self.statement, transform]:
        """Returns an iterator that transforms each row using the provided function.

        Parameters:
            T: The target type to map each row to.
            transform: A function that takes a Row and returns a value of type T.

        Returns:
            An iterator that yields transformed rows.
        """
        return MappedRows[Self.conn, Self.statement, transform](self)
    
    fn as_type[T: Movable & Defaultable](
        self,
    ) -> TypedRows[Self.conn, Self.statement, T]:
        """Returns an iterator that transforms each row using the provided function.

        Parameters:
            T: The target struct type to map each row to.

        Returns:
            An iterator that yields transformed rows.
        """
        return TypedRows[Self.conn, Self.statement, T](self)


struct MappedRows[T: Movable, //, conn: ImmutOrigin, statement: ImmutOrigin, transform: fn (Row) raises -> T](
    Copyable, Iterator
):
    """An iterator that transforms rows using a mapping function."""

    comptime Element = Self.T

    var rows: Rows[Self.conn, Self.statement]
    """The underlying rows iterator."""

    fn __init__(out self, rows: Rows[Self.conn, Self.statement]):
        """Initializes a new MappedRows iterator.

        Args:
            rows: The underlying rows iterator to transform.
        """
        self.rows = rows.copy()

    fn __next__(mut self) raises StopIteration -> Self.T:
        """Returns the next transformed row.

        Returns:
            The next row transformed by the mapping function.
        """
        var result = self.rows.__next__()
        try:
            return Self.transform(result)
        except e:
            raise StopIteration()

    fn __iter__(self) -> Self:
        """Returns an iterator over the transformed rows.

        Returns:
            Self as an iterator.
        """
        return self.copy()

    fn reset(self) -> None:
        """Resets the underlying rows iterator.

        This method resets the underlying rows iterator so that iteration
        can begin again from the first row.
        """
        self.rows.reset()


struct TypedRows[conn: ImmutOrigin, statement: ImmutOrigin, T: Movable & Defaultable](
    Copyable, Iterator
):
    """An iterator that transforms rows using a mapping function."""

    comptime Element = Self.T

    var rows: Rows[Self.conn, Self.statement]
    """The underlying rows iterator."""

    fn __init__(out self, rows: Rows[Self.conn, Self.statement]):
        """Initializes a new MappedRows iterator.

        Args:
            rows: The underlying rows iterator to transform.
        """
        self.rows = rows.copy()
    
    fn _transform(self, row: Row[Self.conn, Self.statement], out result: Self.T) raises:
        """Transforms a Row into the target type T.

        Args:
            row: The Row to transform.

        Returns:
            The transformed value of type T.

        Raises:
            Error: If the transformation fails.
        """
        __comptime_assert is_struct_type[Self.T](), "TypedRows can only transform to struct types."

        comptime field_count = struct_field_count[Self.T]()
        comptime field_names = struct_field_names[Self.T]()
        comptime field_types = struct_field_types[Self.T]()

        var column_count = self.rows.stmt[].column_count()
        if field_count != Int(column_count):
            raise Error(
                "Field count mismatch: struct '",
                get_type_name[Self.T](),
                "' has ",
                Int(field_count),
                " fields, but query returned ",
                Int(column_count),
                " columns."
            )

        result = Self.T()
        try:
            @parameter
            for i in range(field_count):
                comptime field_name = field_names[i]
                comptime field_type = field_types[i]
                if not conforms_to(field_type, FromSQL):
                    raise Error(
                        "Field '",
                        field_name,
                        "' of struct '",
                        get_type_name[Self.T](),
                        "' does not implement FromSQL."
                    )
                ref field = __struct_field_ref(i, result)
                field = row.get[type_of(trait_downcast[FromSQL](field))](i)
        except e:
            # TODO: We capture and print the error here because an extension bug swallows errors.
            print(e)
            raise e^

    fn __next__(mut self) raises StopIteration -> Self.T:
        """Returns the next transformed row.

        Returns:
            The next row transformed by the mapping function.
        """
        var result = self.rows.__next__()
        try:
            return self._transform(result)
        except e:
            raise StopIteration()

    fn __iter__(self) -> Self:
        """Returns an iterator over the transformed rows.

        Returns:
            Self as an iterator.
        """
        return self.copy()

    fn reset(self) -> None:
        """Resets the underlying rows iterator.

        This method resets the underlying rows iterator so that iteration
        can begin again from the first row.
        """
        self.rows.reset()
