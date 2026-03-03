"""ToSQL trait and implementations for converting Mojo types to SQLite values.

This module provides the ToSQL trait which allows converting Mojo types
into SQLite-compatible values for binding to prepared statements.
"""
from std.sys.intrinsics import _type_is_eq_parse_time, _type_is_eq
from std.reflection import get_type_name
from std.utils.variant import Variant
from slight.types.value_ref import SQLType, ValueRef, SQLite3Null, SQLite3Integer, SQLite3Real, SQLite3Text, SQLite3Blob


# @fieldwise_init
# struct Borrowed[origin: ImmutOrigin](Movable):
#     """A borrowed SQLite value reference."""
#     var data: ValueRef[Self.origin]
#     """The underlying SQLite value reference."""

#     fn isa[T: SQLTypeRef](self) -> Bool:
#         return self.data.isa[T]()

#     fn __getitem__[T: SQLTypeRef](self) -> ref [self.data.value] T:
#         return self.data[T]


# @fieldwise_init
# struct Owned(Movable):
#     """An owned SQLite value."""
#     var data: Value
#     """The underlying owned SQLite value."""


# @fieldwise_init
# struct ToSqlOutput[origin: ImmutOrigin](Copyable):
#     """An enum representing the output of a ToSQL conversion."""
#     var value: Variant[
#         # Owned,
#         Borrowed[Self.origin],
#     ]

#     @implicit
#     fn __init__(out self, var value: Owned):
#         self.value = value^
    
#     @implicit
#     fn __init__(out self, var value: Borrowed[Self.origin]):
#         self.value = value^
    
#     fn isa[T: AnyType](self) -> Bool:
#         return self.value.isa[T]()

#     fn __getitem__[T: AnyType](self) -> ref [self.value] T:
#         return self.value[T]


trait ToSQL(Copyable):
    """A trait for types that can be converted into SQLite values.
    
    Types implementing this trait can be used as parameters in SQL queries.
    The conversion may fail, raising an error if the type cannot be properly
    represented as a SQLite value.
    """
    
    # TODO: How can I enforce an immutable origin here? If I don't use ref, then
    # it complains that self might be a register_passable type.
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert this value to a Parameter that can be bound to SQL.
        
        Returns:
            A Parameter containing the SQLite-compatible value.
        
        Raises:
            Error: If the value cannot be converted to a SQLite-compatible value.
        """
        ...


__extension Optional(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert an Optional value to a SQL parameter, handling None as NULL.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert conforms_to(Self.T, ToSQL), String("Optional can only be used with types that implement `ToSQL`. ", get_type_name[Self.T](), " does not implement `ToSQL`.")
        if not self:
            return ValueRef[origin_of(self)](SQLite3Null())

        return ValueRef[origin_of(self)](trait_downcast[ToSQL](self.value()).to_sql().value)


__extension Bool(ToSQL):
    fn to_sql(ref self) -> ValueRef[origin_of(self)]:
        """Convert a Bool to a SQL parameter (as INTEGER 0 or 1).
        
        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](SQLite3Integer(Int64(self)))


__extension Int(ToSQL):
    fn to_sql(ref self) -> ValueRef[origin_of(self)]:
        """Convert an Int to a SQL parameter.
        
        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](SQLite3Integer(Int64(self)))


__extension SIMD(ToSQL):
    # fn to_sql(ref self) raises -> ValueRef[origin_of(self)] where size == 1:
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert a SIMD scalar to a SQL parameter.
        
        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert self.size == 1, "Only SIMD vectors of size 1 can be converted to SQL parameters"
        comptime if dtype in (DType.float16, DType.float32, DType.float64):
            return ValueRef[origin_of(self)](SQLite3Real(Float64(self._refine[self.dtype, 1]())))
        elif dtype in (DType.int, DType.int8, DType.int16, DType.int32, DType.int64,
                       DType.uint, DType.uint8, DType.uint16, DType.uint32, DType.uint64):
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self._refine[self.dtype, 1]())))
        else:
            raise Error("InvalidColumnType: Unsupported SIMD dtype for size 1")


__extension String(ToSQL):
    fn to_sql(ref self) -> ValueRef[origin_of(self)]:
        """Convert a String to a SQL parameter.
        
        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](SQLite3Text(self))


__extension NoneType(ToSQL):
    fn to_sql(ref self) -> ValueRef[origin_of(self)]:
        """Convert None to a SQL NULL parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](SQLite3Null())


__extension List(ToSQL):
    # fn to_sql(ref self) raises -> ValueRef[origin_of(self)] where _type_is_eq_parse_time[
    #     Self.T, Byte
    # ]():
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert Bytes to a SQL Blob parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        return ValueRef[origin_of(self)](SQLite3Blob(rebind[List[Byte]](self)))


__extension Span(ToSQL):
    # fn to_sql(ref self) raises -> ValueRef[origin_of(self)] where _type_is_eq_parse_time[
    #     Self.T, Byte
    # ]():
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert Bytes to a SQL Blob parameter.

        Returns:
            A ValueRef containing the SQLite-compatible value.
        """
        comptime assert _type_is_eq[Self.T, Byte](), String("Span can only be used with Byte type for `ToSQL`. ", get_type_name[Self.T](), " is not Byte.")
        return ValueRef[origin_of(self)](SQLite3Blob(rebind[Span[Byte, self.origin]](self)))
