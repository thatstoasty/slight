# """ToSQL and FromSQL trait implementations for emberjson's Value type.

# This module provides conversions between SQLite values and emberjson Values,
# enabling JSON data to be stored and retrieved from SQLite databases.

# ToSQL mapping (JSON → SQLite):

# | JSON    | SQLite  |
# |---------|---------|
# | Null    | NULL    |
# | Int64   | INTEGER |
# | UInt64  | INTEGER |
# | Float64 | REAL    |
# | String  | TEXT    |
# | Bool    | INTEGER |
# | Object  | Error   |
# | Array   | Error   |

# Note: JSON Object and Array cannot be directly bound as SQL parameters in the
# current trait design. Serialize them to a string with `emberjson.to_string()`
# before binding.

# FromSQL mapping (SQLite → JSON):

# | SQLite  | JSON             |
# |---------|------------------|
# | NULL    | Null             |
# | INTEGER | Int64 number     |
# | REAL    | Float64 number   |
# | TEXT    | Parsed JSON Value (e.g. null, true, 1, "str", [...], {...}) |
# | BLOB    | Parsed JSON Value (UTF-8 JSON bytes) |
# """
# from emberjson import Value
# from slight.types.from_sql import FromSQL
# from slight.types.to_sql import ToSQL
# from slight.types.value_ref import (
#     SQLite3Blob,
#     SQLite3Integer,
#     SQLite3Null,
#     SQLite3Real,
#     SQLite3Text,
#     ValueRef,
# )


# __extension Value(ToSQL):
#     def to_sql(ref self) raises -> ValueRef[origin_of(self)]:
#         """Convert a JSON Value to a SQLite parameter.

#         Returns:
#             A ValueRef containing the SQLite-compatible value.

#         Raises:
#             Error: If the value is a JSON Object or Array, which cannot be
#                 directly bound. Use `emberjson.to_string(value)` first.
#         """
#         if self.is_null():
#             return ValueRef[origin_of(self)](SQLite3Null())
#         elif self.is_int():
#             return ValueRef[origin_of(self)](SQLite3Integer(self.int()))
#         elif self.is_uint():
#             return ValueRef[origin_of(self)](SQLite3Integer(Int64(self.uint())))
#         elif self.is_float():
#             return ValueRef[origin_of(self)](SQLite3Real(self.float()))
#         elif self.is_string():
#             return ValueRef[origin_of(self)](SQLite3Text(self.string()))
#         elif self.is_bool():
#             return ValueRef[origin_of(self)](SQLite3Integer(Int64(Int(self.bool()))))
#         else:
#             raise Error(
#                 "ToSQLError: JSON Object and Array cannot be directly bound as SQL parameters. "
#                 "Use `emberjson.to_string(value)` to serialize to a JSON string first."
#             )


# __extension Value(FromSQL):
#     def __init__(out self, value: ValueRef) raises:
#         """Initialize a JSON Value from a SQLite value.

#         Args:
#             value: The SQLite value to construct the JSON Value from.

#         Raises:
#             Error: If the TEXT or BLOB value is not valid JSON.
#         """
#         if value.isa[SQLite3Null]():
#             self = Self(None)
#         elif value.isa[SQLite3Integer]():
#             self = Self(value.as_int64())
#         elif value.isa[SQLite3Real]():
#             self = Self(value.as_float64())
#         elif value.isa[SQLite3Text[value.stmt]]():
#             self = Self(parse_string=String(value.as_string_slice()))
#         elif value.isa[SQLite3Blob[value.stmt]]():
#             self = Self(parse_bytes=value.as_blob())
#         else:
#             raise Error("InvalidColumnTypeError: Unsupported ValueRef type for JSON Value conversion")
