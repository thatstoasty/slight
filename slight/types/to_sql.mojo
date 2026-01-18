"""ToSQL trait and implementations for converting Mojo types to SQLite values.

This module provides the ToSQL trait which allows converting Mojo types
into SQLite-compatible values for binding to prepared statements.
"""
from sys.intrinsics import _type_is_eq_parse_time
from utils.variant import Variant
from slight.types.value_ref import SQLTypeRef, ValueRef, SQLite3Null, SQLite3Integer, SQLite3Real, SQLite3Text, SQLite3Blob
from slight.types.value import Value


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
    # fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert this value to a Parameter that can be bound to SQL.
        
        Returns:
            A Parameter containing the SQLite-compatible value.
        """
        ...


__extension Bool(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert a Bool to a SQL parameter (as INTEGER 0 or 1)."""
        return ValueRef[origin_of(self)](SQLite3Integer(Int64(self)))


__extension Int(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert an Int to a SQL parameter."""
        return ValueRef[origin_of(self)](SQLite3Integer(Int64(self)))


__extension SIMD(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)] where size == 1:
        @parameter
        if dtype == DType.int8:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.int16:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.int32:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.int64:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.uint8:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.uint16:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.uint32:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.uint64:
            return ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))
        elif dtype == DType.float16:
            return ValueRef[origin_of(self)](SQLite3Real(Float64(self[0])))
        elif dtype == DType.float32:
            return ValueRef[origin_of(self)](SQLite3Real(Float64(self[0])))
        elif dtype == DType.float64:
            return ValueRef[origin_of(self)](SQLite3Real(Float64(self[0])))
        else:
            raise Error("InvalidColumnType: Unsupported SIMD dtype")


__extension String(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert a String to a SQL parameter."""
        return ValueRef[origin_of(self)](SQLite3Text(self))


__extension NoneType(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)]:
        """Convert None to a SQL NULL parameter."""
        return ValueRef[origin_of(self)](SQLite3Null())


__extension List(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)] where _type_is_eq_parse_time[
        Self.T, Byte
    ]():
        """Convert Bytes to a SQL Blob parameter."""
        return ValueRef[origin_of(self)](SQLite3Blob(rebind[List[Byte]](self)))


__extension Span(ToSQL):
    fn to_sql(ref self) raises -> ValueRef[origin_of(self)] where _type_is_eq_parse_time[
        Self.T, Byte
    ]():
        """Convert Bytes to a SQL Blob parameter."""
        return ValueRef[origin_of(self)](SQLite3Blob(rebind[Span[Byte, self.origin]](self)))
