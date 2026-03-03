"""Create or redefine SQL functions.

Ported from rusqlite's `functions.rs`. This module provides the ability to
create user-defined scalar, aggregate, and window functions for SQLite.

# Example

Adding a `halve` scalar function to a connection:

```mojo
from slight import Connection
from slight.functions import (
    FunctionFlags,
    Context,
)
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from std.ffi import c_int

fn halve_impl(
    raw_ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutUnsafePointer[MutExternalPointer[sqlite3_value]],
):
    var ctx = Context(raw_ctx, argc, argv)
    var value = ctx.get_double(0)
    ctx.result_double(value / 2.0)

fn main() raises:
    var conn = Connection.open_in_memory()
    conn.create_scalar_function(
        "halve",
        n_arg=1,
        flags=FunctionFlags.UTF8 | FunctionFlags.DETERMINISTIC,
        x_func=halve_impl,
    )
```
"""

from std.ffi import c_int, c_uint, c_char, c_uchar
from std.memory import MutUnsafePointer, MutOpaquePointer
from std.os import abort

from slight.c.api import sqlite_ffi
from slight.c.types import (
    MutExternalPointer,
    ImmutExternalPointer,
    ResultDestructorFn,
    DataType,
    TextEncoding,
    DestructorHint,
    sqlite3_connection,
    sqlite3_context,
    sqlite3_value,
)
from slight.c.raw_bindings import sqlite3_connection as _sqlite3_connection
from slight.result import SQLite3Result
from slight.error import raise_if_error, decode_error
from slight.types.value_ref import (
    ValueRef,
    SQLite3Null,
    SQLite3Integer,
    SQLite3Real,
    SQLite3Text,
    SQLite3Blob,
)


# ===----------------------------------------------------------------------=== #
# FunctionFlags
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct FunctionFlags(ImplicitlyCopyable):
    """Function Flags for `sqlite3_create_function`.

    See [sqlite3_create_function](https://sqlite.org/c3ref/create_function.html)
    and [Function Flags](https://sqlite.org/c3ref/c_deterministic.html) for details.
    """

    var value: Int32
    """The integer value of the flags."""

    comptime UTF8 = Self(1)
    """Specifies UTF-8 as the text encoding this SQL function prefers for its parameters."""
    comptime UTF16LE = Self(2)
    """Specifies UTF-16 using little-endian byte order as the text encoding."""
    comptime UTF16BE = Self(3)
    """Specifies UTF-16 using big-endian byte order as the text encoding."""
    comptime UTF16 = Self(4)
    """Specifies UTF-16 using native byte order as the text encoding."""
    comptime DETERMINISTIC = Self(0x000000800)
    """Means that the function always gives the same output when the input parameters are the same."""
    comptime DIRECTONLY = Self(0x000080000)
    """Means that the function may only be invoked from top-level SQL."""
    comptime SUBTYPE = Self(0x000100000)
    """Indicates to SQLite that a function may call `sqlite3_value_subtype()` to inspect the subtypes of its arguments."""
    comptime INNOCUOUS = Self(0x000200000)
    """Means that the function is unlikely to cause problems even if misused."""
    comptime RESULT_SUBTYPE = Self(0x001000000)
    """Indicates to SQLite that a function might call `sqlite3_result_subtype()` to cause a subtype to be associated with its result."""
    comptime SELFORDER1 = Self(0x002000000)
    """Indicates that the function is an aggregate that internally orders the values provided to the first argument."""

    fn __or__(self, other: Self) -> Self:
        """Combines two FunctionFlags using a bitwise OR operation.

        This allows multiple flags to be set at once when creating a SQL function.

        Args:
            other: The second FunctionFlags to combine with the first.

        Returns:
            A new FunctionFlags that is the result of combining the two flags with a bitwise OR operation.
        """
        return Self(self.value | other.value)



# ===----------------------------------------------------------------------=== #
# Context
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct Context(Movable, Sized):
    """A wrapper for the SQLite function evaluation context.

    Provides convenient access to function arguments and methods to set
    the function result. This struct wraps the raw `sqlite3_context` and
    argument pointers passed to user-defined SQL function callbacks.

    #### Example:

    ```mojo
    from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
    from slight.functions import Context

    fn my_func(
        raw_ctx: MutExternalPointer[sqlite3_context],
        argc: Int32,
        argv: MutUnsafePointer[MutExternalPointer[sqlite3_value]],
    ):
        var ctx = Context(raw_ctx, argc, argv)
        var value = ctx.get_int64(0)
        ctx.result_int64(value * 2)
    ```
    """

    var ctx: MutExternalPointer[sqlite3_context]
    """The raw SQLite function context pointer."""
    var args: List[MutExternalPointer[sqlite3_value]]
    """The number of arguments passed to the function."""

    fn __init__[argv_origin: MutOrigin](
        out self,
        ctx: MutExternalPointer[sqlite3_context],
        argc: c_int,
        argv: MutUnsafePointer[MutExternalPointer[sqlite3_value], argv_origin],
    ):
        """Initialize a Context from raw callback arguments.

        Parameters:
            argv_origin: The origin of the argv pointer.

        Args:
            ctx: The raw SQLite function context pointer.
            argc: The number of arguments.
            argv: A pointer to the array of argument value pointers.
        """
        self.ctx = ctx
        self.args = [argv[i] for i in range(argc)]

    # ===------------------------------------------------------------------=== #
    # Argument Access
    # ===------------------------------------------------------------------=== #

    @always_inline
    fn __len__(self) -> Int:
        """Returns the number of arguments to the function.

        Returns:
            The number of arguments.
        """
        return len(self.args)

    @always_inline
    fn is_empty(self) -> Bool:
        """Returns True when there are no arguments.

        Returns:
            True if there are no arguments, False otherwise.
        """
        return len(self.args) == 0

    fn get_raw(self, idx: Int) -> ValueRef[origin_of(self)]:
        """Returns the `idx`th argument as a `ValueRef`.

        This reads the type and value from the raw sqlite3_value pointer.

        Args:
            idx: The 0-based argument index.

        Returns:
            A ValueRef containing the argument's value with its appropriate type.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        var value = self.args[idx]
        var value_type = sqlite_ffi()[].value_type(value)

        if DataType.NULL.value == value_type.value:
            return ValueRef[origin_of(self)](SQLite3Null())
        elif DataType.INTEGER.value == value_type.value:
            return ValueRef[origin_of(self)](
                SQLite3Integer(sqlite_ffi()[].value_int64(value))
            )
        elif DataType.FLOAT.value == value_type.value:
            return ValueRef[origin_of(self)](
                SQLite3Real(sqlite_ffi()[].value_double(value))
            )
        elif DataType.TEXT.value == value_type.value:
            var text_ptr = sqlite_ffi()[].value_text(value)
            return ValueRef[origin_of(self)](
                SQLite3Text(
                    StringSlice(
                        unsafe_from_utf8_ptr=text_ptr.unsafe_origin_cast[
                            origin_of(self)
                        ]()
                    )
                )
            )
        # elif DataType.BLOB.value == value_type.value:
        #     var blob_ptr = sqlite_ffi()[].value_blob(value)
        #     var n_bytes = Int(sqlite_ffi()[].value_bytes(value).value)
        #     return ValueRef[origin_of(self)](
        #         SQLite3Blob(
        #             Span[Byte, origin_of(self)](
        #                 ptr=blob_ptr.bitcast[Byte]()
        #                 .unsafe_origin_cast[origin_of(self)](),
        #                 length=n_bytes,
        #             )
        #         )
        #     )
        else:
            abort(
                "[UNREACHABLE] sqlite3_value_type returned an invalid value"
            )

    fn get_int64(self, idx: Int) -> Int64:
        """Returns the `idx`th argument as an Int64.

        This calls `sqlite3_value_int64` directly, performing SQLite's type
        coercion if the value is not an integer.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a 64-bit integer.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return sqlite_ffi()[].value_int64(self.args[idx])

    fn get_double(self, idx: Int) -> Float64:
        """Returns the `idx`th argument as a Float64.

        This calls `sqlite3_value_double` directly, performing SQLite's type
        coercion if the value is not a float.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a 64-bit floating point.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return sqlite_ffi()[].value_double(self.args[idx])

    fn get_text(self, idx: Int) -> StringSlice[origin_of(self)]:
        """Returns the `idx`th argument as a StringSlice.

        This calls `sqlite3_value_text` directly. The returned slice
        references memory managed by SQLite and is valid for the duration
        of the callback.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a string slice.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        var text_ptr = sqlite_ffi()[].value_text(self.args[idx])
        return StringSlice(
            unsafe_from_utf8_ptr=text_ptr.unsafe_origin_cast[
                origin_of(self)
            ]()
        )

    fn get_blob(mut self, idx: Int) -> Span[Byte, origin_of(self)]:
        """Returns the `idx`th argument as a Span of bytes (BLOB).

        This calls `sqlite3_value_blob` and `sqlite3_value_bytes` directly.
        The returned span references memory managed by SQLite and is valid
        for the duration of the callback.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a span of bytes.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        var value = self.args[idx]
        var blob_ptr = sqlite_ffi()[].value_blob(value)
        var n_bytes = Int(sqlite_ffi()[].value_bytes(value).value)
        return Span[Byte, origin_of(self)](
            ptr=blob_ptr.bitcast[Byte]().unsafe_origin_cast[origin_of(self)](),
            length=n_bytes,
        )

    fn get_subtype(self, idx: Int) -> UInt32:
        """Returns the subtype of the `idx`th argument.

        Args:
            idx: The 0-based argument index.

        Returns:
            The subtype value.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return sqlite_ffi()[].value_subtype(self.args[idx])

    fn get_value_type(self, idx: Int) -> DataType:
        """Returns the fundamental datatype of the `idx`th argument.

        Args:
            idx: The 0-based argument index.

        Returns:
            The DataType of the argument (INTEGER, FLOAT, TEXT, BLOB, or NULL).
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return DataType(sqlite_ffi()[].value_type(self.args[idx]).value)

    # ===------------------------------------------------------------------=== #
    # Result Setting
    # ===------------------------------------------------------------------=== #

    fn result_int64(self, value: Int64):
        """Set the result of the function to a 64-bit integer.

        Args:
            value: The integer value to return.
        """
        sqlite_ffi()[].result_int64(self.ctx, value)

    fn result_double(self, value: Float64):
        """Set the result of the function to a floating-point value.

        Args:
            value: The floating-point value to return.
        """
        sqlite_ffi()[].result_double(self.ctx, value)

    fn result_text(self, var value: String):
        """Set the result of the function to a text string.

        SQLite makes its own copy of the string (uses SQLITE_TRANSIENT).

        Args:
            value: The text string to return.
        """
        sqlite_ffi()[].result_text64(
            self.ctx,
            value,
            UInt64(len(value)),
            TextEncoding.UTF8.value,
            DestructorHint.transient_destructor(),
        )

    fn result_null(self):
        """Set the result of the function to NULL."""
        sqlite_ffi()[].result_null(self.ctx)

    # fn result_blob(self, data: Span[Byte]):
    #     """Set the result of the function to a BLOB value.

    #     SQLite makes its own copy of the data (uses SQLITE_TRANSIENT).

    #     Args:
    #         data: The blob data to return.
    #     """
    #     sqlite_ffi()[].result_blob64(
    #         self.ctx,
    #         data.unsafe_ptr().bitcast[NoneType]().unsafe_origin_cast[MutExternalOrigin](),
    #         UInt64(len(data)),
    #         DestructorHint.transient_destructor(),
    #     )

    fn result_error(self, mut msg: String):
        """Set the result of the function to an error.

        Args:
            msg: The error message string.
        """
        sqlite_ffi()[].result_error(self.ctx, msg, c_int(-1))

    fn result_error_code(self, code: Int32):
        """Set the result of the function to an error code.

        Args:
            code: The SQLite error code.
        """
        sqlite_ffi()[].result_error_code(self.ctx, code)

    fn result_error_nomem(self):
        """Set the result of the function to SQLITE_NOMEM (out of memory)."""
        sqlite_ffi()[].result_error_nomem(self.ctx)

    fn result_error_toobig(self):
        """Set the result of the function to SQLITE_TOOBIG (too big)."""
        sqlite_ffi()[].result_error_toobig(self.ctx)

    fn result_value(self, value: MutExternalPointer[sqlite3_value]):
        """Set the result of the function to a copy of another sqlite3_value.

        Args:
            value: The value to copy as the result.
        """
        sqlite_ffi()[].result_value(self.ctx, value)

    fn result_zeroblob(self, n: Int32):
        """Set the result of the function to a zero-filled BLOB.

        Args:
            n: The number of zero-filled bytes.
        """
        sqlite_ffi()[].result_zeroblob(self.ctx, n)

    fn result_subtype(self, subtype: UInt32):
        """Set the subtype of the function result.

        Args:
            subtype: The subtype value.
        """
        sqlite_ffi()[].result_subtype(self.ctx, subtype)

    # ===------------------------------------------------------------------=== #
    # Aggregate Helpers
    # ===------------------------------------------------------------------=== #

    fn aggregate_context(self, n_bytes: Int) -> MutExternalPointer[NoneType]:
        """Get or allocate the aggregate function context.

        On the first call for a particular aggregate instance, `n_bytes` of
        zeroed memory is allocated. On subsequent calls, the same pointer is
        returned.

        For the finalize callback, pass `n_bytes=0` to avoid pointless
        allocations.

        Args:
            n_bytes: Number of bytes to allocate (0 to query existing context).

        Returns:
            A pointer to the aggregate context, or a null pointer on allocation failure.
        """
        return sqlite_ffi()[].aggregate_context(self.ctx, c_int(n_bytes))

    fn user_data(self) -> MutExternalPointer[NoneType]:
        """Get the user data pointer that was passed to `create_scalar_function`,
        `create_aggregate_function`, or `create_window_function`.

        This is the `pApp` pointer that was passed when registering the function.

        Returns:
            The user data pointer, or null if none was set.
        """
        return sqlite_ffi()[].user_data(self.ctx)

    fn context_db_handle(self) -> MutExternalPointer[sqlite3_connection]:
        """Get the database connection handle from the function context.

        Returns:
            The database connection handle.
        """
        return sqlite_ffi()[].context_db_handle(self.ctx)

    fn get_auxdata(self, arg: Int) -> MutExternalPointer[NoneType]:
        """Get the auxiliary data associated with a particular parameter.

        Returns the auxiliary data that was previously set using `set_auxdata`.
        This is useful for caching per-query data across multiple function calls.

        Args:
            arg: The argument index for the auxiliary data.

        Returns:
            Previously set auxiliary data pointer, or null if none exists.
        """
        return sqlite_ffi()[].get_auxdata(self.ctx, c_int(arg))

    fn set_auxdata[data_origin: MutOrigin](
        self,
        arg: Int,
        data: MutOpaquePointer[data_origin],
        destructor: ResultDestructorFn,
    ):
        """Set the auxiliary data associated with a particular parameter.

        This saves metadata that can be retrieved later using `get_auxdata`.
        Useful for caching per-query data (e.g., compiled regex patterns).

        Parameters:
            data_origin: The origin of the data pointer.

        Args:
            arg: The argument index for the auxiliary data.
            data: Pointer to the data to store.
            destructor: Callback to free the data when no longer needed.
        """
        sqlite_ffi()[].set_auxdata(self.ctx, c_int(arg), data, destructor)
