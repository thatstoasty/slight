"""Result rows."""
from std.builtin.rebind import downcast
from slight.types.from_sql import FromSQL
from slight.statement import InvalidColumnIndexError, Statement
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
            raise Error(InvalidColumnIndexError(Int(self), Int(stmt.column_count())))

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
struct Row[conn: MutOrigin, statement: MutOrigin](ImplicitlyCopyable, Writable):
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

    A `Row` returned by `Rows.next()` (or a `for` loop over a named `Rows`)
    carries the origin of the `Rows` it came from, so the compiler keeps that
    `Rows` alive — and the statement un-reset — for as long as the `Row` is in
    use.

    Parameters:
        conn: The connection that produced this row.
        statement: The origin the row borrows from: the `Rows` that produced
            it, or the statement itself inside `MappedRows`/`TypedRows`.
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
            raise Error(InvalidColumnIndexError(Int(i), Int(self.stmt[].column_count())))

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


trait FallibleIterator(Deinitable, Movable):
    """An iterator whose `next()` raises the errors it encounters.

    Mojo `for` loops treat any error raised from `__next__` as the end of
    iteration, so a `for` loop cannot surface a failed `sqlite3_step` or a
    failed row conversion. Types implementing this trait expose a raising
    `next()`, and their `for`-loop iterators store the error that ended
    iteration so it can be re-raised afterwards with `raise_if_error()`.
    """

    comptime Element: Movable
    """The type of elements produced by this iterator."""

    def _advance(mut self) raises -> Bool:
        """Moves to the next element.

        Split from `_current()` so callers never hold an empty
        `Optional[Element]`, which cannot be dropped when `Element` is a
        linear type.

        Returns:
            True if there is a next element, False when iteration is complete.

        Raises:
            Error: If advancing fails.
        """
        ...

    def _current(mut self) raises -> Self.Element:
        """Produces the element that `_advance()` just moved to.

        Returns:
            The current element.

        Raises:
            Error: If producing the element fails.
        """
        ...

    def _set_error(mut self, var error: Error):
        """Stores the error that ended a `for` loop over this iterator.

        Args:
            error: The error raised by `next()`.
        """
        ...


struct BorrowedIterator[I: FallibleIterator, origin: MutOrigin](Iterator, Movable):
    """A `for`-loop iterator over a `FallibleIterator` that is borrowed, not consumed.

    Returned by `__iter__` when looping over a named variable, so the variable
    is still available after the loop for `raise_if_error()`.

    Parameters:
        I: The underlying fallible iterator type.
        origin: The origin of the borrowed iterator.
    """

    comptime Element = Self.I.Element
    """The type of elements produced by this iterator."""

    var inner: Pointer[Self.I, Self.origin]
    """The borrowed fallible iterator."""

    def __init__(out self, inner: Pointer[Self.I, Self.origin]):
        """Initializes the iterator.

        Args:
            inner: The fallible iterator to borrow.
        """
        self.inner = inner

    def __next__(mut self) raises StopIteration -> Self.Element:
        """Returns the next element.

        If the underlying `next()` raises, the error is stored on the borrowed
        iterator and iteration stops.

        Returns:
            The next element.

        Raises:
            StopIteration: When there are no more elements, or an error occurred.
        """
        try:
            if self.inner[]._advance():
                return self.inner[]._current()
        except e:
            self.inner[]._set_error(e^)
        raise StopIteration()


struct OwnedIterator[I: FallibleIterator](Iterator, Movable):
    """A `for`-loop iterator that takes ownership of a `FallibleIterator`.

    Returned by `__iter__` when looping over a temporary (for example
    `for x in stmt.query[T]():`). An error that ends such a loop cannot be
    observed afterwards; loop over a named variable, or call `next()` or
    `collect()`, when errors matter.

    Parameters:
        I: The underlying fallible iterator type.
    """

    comptime Element = Self.I.Element
    """The type of elements produced by this iterator."""

    var inner: Self.I
    """The owned fallible iterator."""

    def __init__(out self, var inner: Self.I):
        """Initializes the iterator.

        Args:
            inner: The fallible iterator to take ownership of.
        """
        self.inner = inner^

    def __next__(mut self) raises StopIteration -> Self.Element:
        """Returns the next element.

        Returns:
            The next element.

        Raises:
            StopIteration: When there are no more elements, or an error occurred.
        """
        try:
            if self.inner._advance():
                return self.inner._current()
        except e:
            self.inner._set_error(e^)
        raise StopIteration()


struct Rows[conn: MutOrigin, statement: MutOrigin](Movable):
    """The rows produced by executing a query.

    Use the raising `next()` to step through rows one at a time, or iterate
    with a `for` loop. Because a `for` loop cannot raise, a failure while
    stepping (a constraint violation, an I/O error, an interrupted query, ...)
    ends the loop and is stored instead. To check for it, loop over a named
    `Rows` and call `raise_if_error()` afterwards:

    ```mojo
    from slight import Connection

    def main() raises:
        var db = Connection.open_in_memory()
        var stmt = db.prepare("SELECT 1 UNION ALL SELECT 2")
        var rows = stmt.query()
        for row in rows:
            print(row.get[Int](0))
        rows.raise_if_error()
    ```

    Destroying a `Rows` resets the statement, so stopping early (`break`,
    `one_row()`, `exists()`, ...) does not leave the statement mid-query
    holding a read lock. The one exception is a `for` loop over a temporary
    (`for row in stmt.query():`) that exits early: see `OwnedRowsIterator`.
    Either way, `query()` and `execute()` reset the statement before binding,
    so it can always be queried again straight away.

    Parameters:
        conn: The connection that produced these rows.
        statement: The statement that produces these rows.
    """

    var stmt: Pointer[Statement[Self.conn], Self.statement]
    """A pointer to the statement that produces rows."""
    var error: Optional[Error]
    """The error that ended a `for` loop over these rows, if any."""
    var _done: Bool
    """Whether the statement has finished (or failed), so it must not be stepped again."""
    var _reset_on_destroy: Bool
    """Whether destroying this `Rows` resets the statement. See `OwnedRowsIterator` for the one exception."""

    def __init__(out self, stmt: Pointer[Statement[Self.conn], Self.statement]):
        """Initializes the rows for a statement that has already had its parameters bound.

        Args:
            stmt: A pointer to the statement to step through.
        """
        self.stmt = stmt
        self.error = None
        self._done = False
        self._reset_on_destroy = True

    def __deinit__(deinit self):
        """Resets the statement so it is ready to be queried or executed again."""
        if self._reset_on_destroy:
            _ = self.stmt[].stmt.reset()

    def _finish(mut self):
        """Marks the rows as exhausted and resets the statement.

        Resetting now, rather than when `Rows` is destroyed, releases the
        statement's read lock as soon as iteration is over. Stepping a
        finished statement would silently re-run the query, so `_done` stops
        that from happening.
        """
        self._done = True
        _ = self.stmt[].stmt.reset()

    def _step(mut self) raises -> Bool:
        """Advances the statement to the next row.

        Returns:
            True if the statement is positioned on a new row, False when done.

        Raises:
            Error: If stepping the statement fails.
        """
        if self._done:
            return False

        var has_row: Bool
        try:
            has_row = self.stmt[].step()
        except e:
            self._finish()
            raise e^

        if not has_row:
            self._finish()
        return has_row

    def next(mut self) raises -> Optional[Row[Self.conn, origin_of(self)]]:
        """Advances to the next row.

        The returned `Row` borrows from this `Rows`, which therefore stays
        alive (and the statement stays on that row) while the `Row` is in use.

        Returns:
            The next row, or `None` once every row has been returned.

        Raises:
            Error: If stepping the statement fails.
        """
        if self._step():
            return Row(rebind[Pointer[Statement[Self.conn], origin_of(self)]](self.stmt))
        return None

    def raise_if_error(self) raises:
        """Re-raises the error that ended a `for` loop over these rows, if there was one.

        Raises:
            Error: The error that stopped iteration.
        """
        if self.error:
            raise self.error.value().copy()

    def reset(mut self):
        """Resets the statement so iteration starts again from the first row.

        Bound parameters are kept, and any stored error is cleared.
        """
        _ = self.stmt[].stmt.reset()
        self._done = False
        self.error = None

    def __iter__(mut self) -> RowsIterator[Self.conn, Self.statement, origin_of(self)]:
        """Returns an iterator that borrows these rows.

        Used when looping over a named `Rows`, which remains usable after the
        loop (for example to call `raise_if_error()`).

        Returns:
            An iterator over the rows.
        """
        return RowsIterator(Pointer(to=self))

    def __iter__(var self) -> OwnedRowsIterator[Self.conn, Self.statement]:
        """Returns an iterator that takes ownership of these rows.

        Used when looping over a temporary, such as `for row in stmt.query():`.

        Returns:
            An iterator over the rows.
        """
        self._reset_on_destroy = False
        return OwnedRowsIterator(self^)

    def map[T: Movable, //, transform: RowTransformFn[T]](var self) -> MappedRows[transform[Self.conn, Self.statement]]:
        """Returns an iterator that transforms each row using the provided function.

        Parameters:
            T: The target type to map each row to.
            transform: A function that takes a Row and returns a value of type T.

        Returns:
            An iterator that yields transformed rows.
        """
        return MappedRows[transform[Self.conn, Self.statement]](self^)

    def as_type[T: MoveDestructible](var self) -> TypedRows[Self.conn, Self.statement, T]:
        """Returns an iterator that converts each row into the struct `T`.

        Parameters:
            T: The target struct type to map each row to.

        Returns:
            An iterator that yields transformed rows.
        """
        return TypedRows[Self.conn, Self.statement, T](self^)


struct RowsIterator[conn: MutOrigin, statement: MutOrigin, origin: MutOrigin](Iterator, Movable):
    """A `for`-loop iterator over a borrowed `Rows`.

    Parameters:
        conn: The connection that produced the rows.
        statement: The statement that produces the rows.
        origin: The origin of the borrowed `Rows`.
    """

    comptime Element = Row[Self.conn, Self.origin]
    """The type of elements produced by this iterator."""

    var rows: Pointer[Rows[Self.conn, Self.statement], Self.origin]
    """The borrowed rows."""

    def __init__(out self, rows: Pointer[Rows[Self.conn, Self.statement], Self.origin]):
        """Initializes the iterator.

        Args:
            rows: The rows to borrow.
        """
        self.rows = rows

    def __next__(mut self) raises StopIteration -> Self.Element:
        """Returns the next row.

        If stepping fails, the error is stored on the borrowed `Rows` (see
        `Rows.raise_if_error()`) and iteration stops.

        Returns:
            The next row.

        Raises:
            StopIteration: When there are no more rows, or an error occurred.
        """
        try:
            if self.rows[]._step():
                return Row(rebind[Pointer[Statement[Self.conn], Self.origin]](self.rows[].stmt))
        except e:
            self.rows[].error = e^
        raise StopIteration()


struct OwnedRowsIterator[conn: MutOrigin, statement: MutOrigin](Iterator, Movable):
    """A `for`-loop iterator that owns its `Rows`.

    Unlike other `Rows`, this one does not reset the statement when it is
    destroyed. The rows it yields borrow the statement, not the iterator, so
    after a `break` the compiler may destroy the iterator before the loop body
    has finished reading the current row; resetting at that point would
    invalidate the row. The statement is still reset once iteration completes
    or fails, and before its next `query()` or `execute()`. After an early
    `break` it holds its read lock until then (or until it is finalized).

    Parameters:
        conn: The connection that produced the rows.
        statement: The statement that produces the rows.
    """

    comptime Element = Row[Self.conn, Self.statement]
    """The type of elements produced by this iterator."""

    var rows: Rows[Self.conn, Self.statement]
    """The owned rows."""

    def __init__(out self, var rows: Rows[Self.conn, Self.statement]):
        """Initializes the iterator.

        Args:
            rows: The rows to take ownership of.
        """
        self.rows = rows^

    def __next__(mut self) raises StopIteration -> Self.Element:
        """Returns the next row.

        Returns:
            The next row.

        Raises:
            StopIteration: When there are no more rows, or an error occurred.
        """
        try:
            if self.rows._step():
                return Row(self.rows.stmt)
        except e:
            self.rows.error = e^
        raise StopIteration()


struct MappedRows[
    T: Movable, conn: MutOrigin, statement: MutOrigin, //, transform: BoundRowTransformFn[T, conn, statement]
](FallibleIterator):
    """An iterator that transforms rows using a mapping function.

    Errors from stepping the statement or from `transform` are raised by
    `next()` and `collect()`. A `for` loop stops on the first error instead;
    see `Rows` for how to check for it afterwards.

    Parameters:
        T: The target type to map each row to.
        conn: The connection that produced these rows.
        statement: The statement that produces these rows.
        transform: The function to apply to each row.
    """

    comptime Element = Self.T
    """The type of elements produced by this iterator."""

    var rows: Rows[Self.conn, Self.statement]
    """The underlying rows."""

    def __init__(out self, var rows: Rows[Self.conn, Self.statement]):
        """Initializes a new MappedRows iterator.

        Args:
            rows: The underlying rows to transform.
        """
        self.rows = rows^

    def next(mut self) raises -> Optional[Self.T]:
        """Returns the next transformed row.

        Returns:
            The next row transformed by the mapping function, or `None` once
            every row has been returned.

        Raises:
            Error: If stepping the statement or the transformation fails.
        """
        if not self._advance():
            return None
        return self._current()

    def _advance(mut self) raises -> Bool:
        """Steps the statement to the next row.

        Returns:
            True if the statement is positioned on a new row, False when done.

        Raises:
            Error: If stepping the statement fails.
        """
        return self.rows._step()

    def _current(mut self) raises -> Self.T:
        """Transforms the row the statement is positioned on.

        Returns:
            The transformed row.

        Raises:
            Error: If the transformation fails.
        """
        return Self.transform(Row[Self.conn, Self.statement](self.rows.stmt))

    def _set_error(mut self, var error: Error):
        """Stores the error that ended a `for` loop.

        Args:
            error: The error raised by `next()`.
        """
        self.rows.error = error^

    def raise_if_error(self) raises:
        """Re-raises the error that ended a `for` loop, if there was one.

        Raises:
            Error: The error that stopped iteration.
        """
        self.rows.raise_if_error()

    def reset(mut self):
        """Resets the statement so iteration starts again from the first row."""
        self.rows.reset()

    def __iter__(mut self) -> BorrowedIterator[Self, origin_of(self)]:
        """Returns an iterator that borrows these rows.

        Returns:
            An iterator over the transformed rows.
        """
        return BorrowedIterator(Pointer(to=self))

    def __iter__(var self) -> OwnedIterator[Self]:
        """Returns an iterator that takes ownership of these rows.

        Returns:
            An iterator over the transformed rows.
        """
        return OwnedIterator(self^)

    def collect(mut self) raises -> List[Self.T] where conforms_to(Self.T, Deinitable):
        """Collects the remaining transformed rows into a `List`.

        Returns:
            A `List` containing every remaining transformed row.

        Raises:
            Error: If stepping the statement or the transformation fails.
        """
        var result = List[Self.T]()
        while self._advance():
            result.append(self._current())
        return result^

    def collect(var self) raises -> List[Self.T] where conforms_to(Self.T, Deinitable):
        """Collects the remaining transformed rows into a `List`.

        Returns:
            A `List` containing every remaining transformed row.

        Raises:
            Error: If stepping the statement or the transformation fails.
        """
        var result = List[Self.T]()
        while self._advance():
            result.append(self._current())
        return result^


def __all_dtors_are_trivial[T: AnyType]() -> Bool:
    comptime r = reflect[T]
    comptime for i in range(r.field_count()):
        comptime type = r.field_types()[i]
        if not downcast[type, Deinitable].__del__is_trivial:
            return False
    return True


struct TypedRows[conn: MutOrigin, statement: MutOrigin, T: MoveDestructible](FallibleIterator):
    """An iterator that converts each row into the struct `T`, field by field.

    Errors from stepping the statement or converting a column are raised by
    `next()` and `collect()`. A `for` loop stops on the first error instead;
    see `Rows` for how to check for it afterwards.

    Parameters:
        conn: The connection that produced these rows.
        statement: The statement that produces these rows.
        T: The target struct type to map each row to. Must be a struct type where each field implements FromSQL.
    """

    comptime Element = Self.T
    """The type of elements produced by this iterator."""

    var rows: Rows[Self.conn, Self.statement]
    """The underlying rows."""

    def __init__(out self, var rows: Rows[Self.conn, Self.statement]):
        """Initializes a new TypedRows iterator.

        Args:
            rows: The underlying rows to convert.
        """
        self.rows = rows^

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

    def next(mut self) raises -> Optional[Self.T]:
        """Returns the next converted row.

        Returns:
            The next row converted to `T`, or `None` once every row has been
            returned.

        Raises:
            Error: If stepping the statement or the conversion fails.
        """
        if not self._advance():
            return None
        return self._current()

    def _advance(mut self) raises -> Bool:
        """Steps the statement to the next row.

        Returns:
            True if the statement is positioned on a new row, False when done.

        Raises:
            Error: If stepping the statement fails.
        """
        return self.rows._step()

    def _current(mut self) raises -> Self.T:
        """Converts the row the statement is positioned on.

        Returns:
            The converted row.

        Raises:
            Error: If the conversion fails.
        """
        return Self._transform(Row[Self.conn, Self.statement](self.rows.stmt))

    def _set_error(mut self, var error: Error):
        """Stores the error that ended a `for` loop.

        Args:
            error: The error raised by `next()`.
        """
        self.rows.error = error^

    def raise_if_error(self) raises:
        """Re-raises the error that ended a `for` loop, if there was one.

        Raises:
            Error: The error that stopped iteration.
        """
        self.rows.raise_if_error()

    def reset(mut self):
        """Resets the statement so iteration starts again from the first row."""
        self.rows.reset()

    def __iter__(mut self) -> BorrowedIterator[Self, origin_of(self)]:
        """Returns an iterator that borrows these rows.

        Returns:
            An iterator over the converted rows.
        """
        return BorrowedIterator(Pointer(to=self))

    def __iter__(var self) -> OwnedIterator[Self]:
        """Returns an iterator that takes ownership of these rows.

        Returns:
            An iterator over the converted rows.
        """
        return OwnedIterator(self^)

    def collect(mut self) raises -> List[Self.T]:
        """Collects the remaining converted rows into a `List`.

        Returns:
            A `List` containing every remaining converted row.

        Raises:
            Error: If stepping the statement or the conversion fails.
        """
        var result = List[Self.T]()
        while self._advance():
            result.append(self._current())
        return result^

    def collect(var self) raises -> List[Self.T]:
        """Collects the remaining converted rows into a `List`.

        Returns:
            A `List` containing every remaining converted row.

        Raises:
            Error: If stepping the statement or the conversion fails.
        """
        var result = List[Self.T]()
        while self._advance():
            result.append(self._current())
        return result^
