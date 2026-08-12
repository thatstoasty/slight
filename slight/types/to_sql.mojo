"""ToSQL trait and implementations for converting Mojo types to SQLite values.

This module provides the ToSQL trait which allows converting Mojo types
into SQLite-compatible values for binding to prepared statements.
"""
from slight.types import value_ref
from slight.types import value
from slight.types.value_ref import ValueRef
from slight.types.value import Value
from std.utils.variant import Variant


struct ToSqlOutput[origin: ImmOrigin](Movable):
    """What a `ToSQL` implementation returns: either a borrow or an owned value.

    Return a `ValueRef` when the SQL representation already exists in memory —
    the bytes of a `String`, the elements of a `List[Byte]`, or a scalar — so no
    allocation is needed.

    Return a `Value` when the representation must be *computed* and therefore
    has nowhere to be borrowed from: a date formatted as ISO text, a UUID, an
    enum rendered as a string. Returning a `ValueRef` view of a local temporary
    in those cases would dangle, and the compiler rejects it.

    Parameters:
        origin: The origin of the borrowed value, when borrowing.
    """

    comptime _type = Variant[ValueRef[Self.origin], Value]
    var value: Self._type
    """The borrowed-or-owned payload."""

    @implicit
    def __init__(out self, value: ValueRef[Self.origin]):
        """Initialize from a borrowed value.

        Args:
            value: The borrowed value.
        """
        self.value = value

    @implicit
    def __init__(out self, var value: Value):
        """Initialize from an owned value.

        Args:
            value: The owned value.
        """
        self.value = value^

    def isa[T: Movable](self) -> Bool:
        """Check which arm this output holds.

        Parameters:
            T: The arm to test for.

        Returns:
            True if the output holds a `T`.
        """
        return self.value.isa[T]()

    def __getitem_param__[T: Movable](self) -> ref[origin_of(self.value)._get_owned_interior["value"]] T:
        """Access the payload as a `T`.

        Parameters:
            T: The arm to read.

        Returns:
            A reference to the payload.
        """
        return self.value[T]


trait ToSQL(Movable):
    """A trait for types that can be converted into SQLite values.

    Types implementing this trait can be used as parameters in SQL queries.
    The conversion may fail, raising an error if the type cannot be properly
    represented as a SQLite value.
    """

    # TODO: How can I enforce an immutable origin here? If I don't use ref, then
    # it complains that self might be a register_passable type.
    def to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert this value into something bindable to SQL.

        Return a `ValueRef` when the SQL representation already exists in
        memory, or a `Value` when it has to be computed and therefore has no
        buffer to borrow from.

        Returns:
            A `ToSqlOutput` containing the SQLite-compatible value.

        Raises:
            Error: If the value cannot be converted to a SQLite-compatible value.
        """
        ...


# TODO: Probably need to handle the interior origin of the Optional correctly here.
__extension Optional(ToSQL):
    def to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert an Optional value to a SQL parameter, handling None as NULL.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert conforms_to(Self.T, ToSQL), String(
            "Optional can only be used with types that implement `ToSQL`. ",
            reflect[Self.T].name(),
            " does not implement `ToSQL`.",
        )
        if not self:
            return ValueRef[origin_of(self)](value_ref.Null())

        # Delegate to the wrapped value. The borrowed arms still have to be
        # unwrapped and re-wrapped to re-origin the ValueRef, but an owned
        # inner value now passes straight through instead of being dropped.
        var inner = self.value().to_sql()
        if inner.isa[Value]():
            return inner[Value].copy()

        comptime inner_origin = origin_of(self.value())
        ref vr = inner[ValueRef[inner_origin]]
        if vr.isa[value_ref.Integer]():
            return ValueRef[origin_of(self)](vr[value_ref.Integer])
        elif vr.isa[value_ref.Real]():
            return ValueRef[origin_of(self)](vr[value_ref.Real])
        elif vr.isa[value_ref.Text[inner_origin]]():
            return ValueRef[origin_of(self)](vr[value_ref.Text[inner_origin]])
        elif vr.isa[value_ref.Blob[inner_origin]]():
            return ValueRef[origin_of(self)](vr[value_ref.Blob[inner_origin]])
        elif vr.isa[value_ref.Null]():
            return ValueRef[origin_of(self)](value_ref.Null())
        else:
            raise Error("Unsupported type in Optional for ToSQL conversion")


__extension Bool(ToSQL):
    def to_sql(ref self) -> ToSqlOutput[origin_of(self)]:
        """Convert a Bool to a SQL parameter (as INTEGER 0 or 1).

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](value_ref.Integer(Int64(self)))


__extension SIMD(ToSQL):
    def to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert a SIMD scalar to a SQL parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert Self.length == 1, "Only SIMD vectors of size 1 can be converted to SQL parameters"
        comptime if Self.dtype in (DType.float16, DType.float32, DType.float64):
            return ValueRef[origin_of(self)](value_ref.Real(Float64(self._refine[self.dtype, 1]())))
        elif Self.dtype in (
            DType.int,
            DType.int8,
            DType.int16,
            DType.int32,
            DType.int64,
            DType.uint,
            DType.uint8,
            DType.uint16,
            DType.uint32,
            DType.uint64,
        ):
            return ValueRef[origin_of(self)](value_ref.Integer(Int64(self._refine[self.dtype, 1]())))
        else:
            raise Error("InvalidColumnType: Unsupported SIMD dtype for size 1")


__extension String(ToSQL):
    def to_sql(ref self) -> ToSqlOutput[origin_of(self)]:
        """Convert a String to a SQL parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](value_ref.Text(self))


__extension NoneType(ToSQL):
    def to_sql(ref self) -> ToSqlOutput[origin_of(self)]:
        """Convert None to a SQL NULL parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](value_ref.Null())


__extension List(ToSQL):
    def to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert Bytes to a SQL Blob parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert Self.T == Byte, String(
            t"List can only be used with Byte type for `ToSQL`. {reflect[Self.T].name()} is not Byte."
        )
        return ValueRef[origin_of(self)](value_ref.Blob(rebind[List[Byte]](self)))


__extension Span(ToSQL):
    def to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert Bytes to a SQL Blob parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert Self.T == Byte, String(
            t"Span can only be used with Byte type for `ToSQL`. {reflect[Self.T].name()} is not Byte."
        )
        return ValueRef[origin_of(self)](value_ref.Blob(rebind[Span[Byte, self.origin]](self)))
