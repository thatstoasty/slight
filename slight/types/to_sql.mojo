"""ToSQL trait and implementations for converting Mojo types to SQLite values.

This module provides the ToSQL trait which allows converting Mojo types
into SQLite-compatible values for binding to prepared statements.
"""

from utils.variant import Variant
from slight.types.value_ref import SQLTypeRef, ValueRef, SQLite3Null, SQLite3Integer, SQLite3Real, SQLite3Text
from slight.types.value import Value
from slight.params import Parameter


@fieldwise_init
struct Borrowed[origin: ImmutOrigin](Movable):
    """A borrowed SQLite value reference."""
    var data: ValueRef[Self.origin]
    """The underlying SQLite value reference."""

    fn isa[T: SQLTypeRef](self) -> Bool:
        return self.data.isa[T]()

    fn __getitem__[T: SQLTypeRef](self) -> ref [self.data.value] T:
        return self.data[T]


@fieldwise_init
struct Owned(Movable):
    """An owned SQLite value."""
    var data: Value
    """The underlying owned SQLite value."""


@fieldwise_init
struct ToSqlOutput[origin: ImmutOrigin](Copyable):
    """An enum representing the output of a ToSQL conversion."""
    var value: Variant[
        # Owned,
        Borrowed[Self.origin],
    ]

    @implicit
    fn __init__(out self, var value: Owned):
        self.value = value^
    
    @implicit
    fn __init__(out self, var value: Borrowed[Self.origin]):
        self.value = value^
    
    fn isa[T: AnyType](self) -> Bool:
        return self.value.isa[T]()

    fn __getitem__[T: AnyType](self) -> ref [self.value] T:
        return self.value[T]


trait ToSQL(Copyable):
    """A trait for types that can be converted into SQLite values.
    
    Types implementing this trait can be used as parameters in SQL queries.
    The conversion may fail, raising an error if the type cannot be properly
    represented as a SQLite value.
    """
    
    fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert this value to a Parameter that can be bound to SQL.
        
        Returns:
            A Parameter containing the SQLite-compatible value.
        """
        ...


__extension Bool(ToSQL):
    fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert a Bool to a SQL parameter (as INTEGER 0 or 1)."""
        return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self)))))


__extension Int(ToSQL):
    fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert an Int to a SQL parameter."""
        return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self)))))


__extension SIMD(ToSQL):
    fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)] where size == 1:
        @parameter
        if dtype == DType.int8:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.int16:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.int32:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.int64:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.uint8:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.uint16:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.uint32:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.uint64:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Integer(Int64(self[0])))))
        elif dtype == DType.float16:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Real(Float64(self[0])))))
        elif dtype == DType.float32:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Real(Float64(self[0])))))
        elif dtype == DType.float64:
            return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Real(Float64(self[0])))))
        else:
            raise Error("InvalidColumnType: Unsupported SIMD dtype")


__extension String(ToSQL):
    fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert a String to a SQL parameter."""
        return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Text(self))))


__extension NoneType(ToSQL):
    fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
        """Convert None to a SQL NULL parameter."""
        return ToSqlOutput(Borrowed(ValueRef[origin_of(self)](SQLite3Null())))


# Optional support - convert Some(value) to value, None to NULL
# __extension Optional(ToSQL) where T: ToSQL:
#     fn to_sql(ref self) raises -> ToSqlOutput[origin_of(self)]:
#         """Convert an Optional to a SQL parameter.
        
#         If the Optional contains a value, converts that value to SQL.
#         If the Optional is None, returns a SQL NULL.
#         """
#         if self:
#             return self.value().to_sql()
#         else:
#             return Parameter(None)


# Note: In Rust, ToSQL is also implemented for references (&T), Box<T>, Rc<T>, Arc<T>,
# Cow<T>, etc. In Mojo, we don't need these since we have different ownership semantics.
# The Parameter type and implicit conversions handle most of these cases.

# The Rust implementation also has special handling for:
# - Vec<u8> and [u8] slices (BLOB data)
# - Value and ValueRef types
# - u64/usize with fallible conversion (feature-gated)
# - NonZero types
# - i128 (feature-gated)
# - UUID (feature-gated)
#
# For Mojo, we focus on the core types that Parameter already supports.
# Additional types like BLOB support would need to be added to Parameter first.
