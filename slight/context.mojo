from slight.c.types import MutExternalPointer, sqlite3_connection, sqlite3_context, sqlite3_value, DataType, DestructorHint, TextEncoding, ResultDestructorFn
from slight.c.api import sqlite_ffi
from slight.types.value_ref import (
    ValueRef,
    SQLite3Null,
    SQLite3Integer,
    SQLite3Real,
    SQLite3Text,
    SQLite3Blob,
)

from std.ffi import c_int
from std.os import abort
from std.memory import ImmutSpan

@fieldwise_init
struct Context(Movable, Sized):
    """A wrapper for the SQLite function evaluation context.

    Provides convenient access to function arguments and methods to set
    the function result. This struct wraps the raw `sqlite3_context` and
    argument pointers passed to user-defined SQL function callbacks.

    #### Example:

    ```mojo
    from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
    from slight.context import Context

    fn my_func(
        raw_ctx: MutExternalPointer[sqlite3_context],
        argc: Int32,
        argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
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

    fn __init__(
        out self,
        ctx: MutExternalPointer[sqlite3_context],
    ):
        """Initialize a Context from raw callback arguments.

        Args:
            ctx: The raw SQLite function context pointer.
        """
        self.ctx = ctx
        self.args = []

    fn __init__(
        out self,
        ctx: MutExternalPointer[sqlite3_context],
        argc: c_int,
        argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    ):
        """Initialize a Context from raw callback arguments.

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
            return ValueRef[origin_of(self)](SQLite3Integer(sqlite_ffi()[].value_int64(value)))
        elif DataType.FLOAT.value == value_type.value:
            return ValueRef[origin_of(self)](SQLite3Real(sqlite_ffi()[].value_double(value)))
        elif DataType.TEXT.value == value_type.value:
            var text_ptr = sqlite_ffi()[].value_text(value)
            return ValueRef[origin_of(self)](
                SQLite3Text(StringSlice(unsafe_from_utf8_ptr=text_ptr.unsafe_origin_cast[origin_of(self)]()))
            )
        elif DataType.BLOB.value == value_type.value:
            var blob_ptr = sqlite_ffi()[].value_blob(value)
            var n_bytes = Int(sqlite_ffi()[].value_bytes(value).value)
            return ValueRef[origin_of(self)](
                SQLite3Blob(
                    Span[Byte, origin_of(self)](
                        ptr=blob_ptr.bitcast[Byte]().unsafe_origin_cast[origin_of(self)](),
                        length=n_bytes,
                    )
                )
            )
        else:
            abort("[UNREACHABLE] sqlite3_value_type returned an invalid value")

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
        return StringSlice(unsafe_from_utf8_ptr=text_ptr.unsafe_origin_cast[origin_of(self)]())

    fn get_blob(self, idx: Int) -> Span[Byte, origin_of(self)]:
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
        return Span(
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

    fn result_blob(self, data: ImmutSpan[Byte, ...]):
        """Set the result of the function to a BLOB value.

        SQLite makes its own copy of the data (uses SQLITE_TRANSIENT).

        Args:
            data: The blob data to return.
        """
        sqlite_ffi()[].result_blob64(
            self.ctx,
            data.unsafe_ptr().bitcast[NoneType](),
            UInt64(len(data)),
            DestructorHint.transient_destructor(),
        )

    fn result_error(self, msg: String):
        """Set the result of the function to an error.

        Args:
            msg: The error message string.
        """
        var msg_copy = msg.copy()
        sqlite_ffi()[].result_error(self.ctx, msg_copy, c_int(-1))

    fn result_error_code(self, code: Int32):
        """Set the result of the function to an error code.

        Args:
            code: The SQLite error code.
        """
        sqlite_ffi()[].result_error_code(self.ctx, code)

    fn result_error_no_mem(self):
        """Set the result of the function to SQLITE_NOMEM (out of memory)."""
        sqlite_ffi()[].result_error_nomem(self.ctx)

    fn result_error_too_big(self):
        """Set the result of the function to SQLITE_TOOBIG (too big)."""
        sqlite_ffi()[].result_error_toobig(self.ctx)

    fn result_value(self, value: MutExternalPointer[sqlite3_value]):
        """Set the result of the function to a copy of another sqlite3_value.

        Args:
            value: The value to copy as the result.
        """
        sqlite_ffi()[].result_value(self.ctx, value)

    fn result_zero_blob(self, n: Int32):
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
    
    fn set_result(self, result: ValueRef[_]):
        """Set the function result based on a ValueRef.

        This is a convenience method that checks the type of the ValueRef and
        calls the appropriate result-setting method.

        Args:
            result: The ValueRef containing the value to set as the function result.
        """
        if result.isa[SQLite3Null]():
            self.result_null()
        elif result.isa[SQLite3Integer]():
            self.result_int64(result[SQLite3Integer].value)
        elif result.isa[SQLite3Real]():
            self.result_double(result[SQLite3Real].value)
        elif result.isa[SQLite3Text[origin_of(result)]]():
            self.result_text(String(result[SQLite3Text[origin_of(result)]].value))
        elif result.isa[SQLite3Blob[origin_of(result)]]():
            ref value = result[SQLite3Blob[origin_of(result)]].value
            if len(value) == 0:
                self.result_zero_blob(0)
            else:
                self.result_blob(result[SQLite3Blob[origin_of(result)]].value)
        else:
            self.result_error("Unsupported return type from function.")
        return

    # ===------------------------------------------------------------------=== #
    # Aggregate Helpers
    # ===------------------------------------------------------------------=== #

    fn aggregate_context[A: Movable](self, n_bytes: Int) -> Optional[MutExternalPointer[A]]:
        """Get or allocate the aggregate function context.

        On the first call for a particular aggregate instance, `n_bytes` of
        zeroed memory is allocated. On subsequent calls, the same pointer is
        returned.

        For the finalize callback, pass `n_bytes=0` to avoid pointless
        allocations.

        Parameters:
            A: The type of the aggregate context. This is the type that will be returned as a pointer.

        Args:
            n_bytes: Number of bytes to allocate (0 to query existing context).

        Returns:
            An optional pointer to the aggregate context. None is returned if a null pointer is returned (allocation failure).
        """
        var ptr = sqlite_ffi()[].aggregate_context(self.ctx, c_int(n_bytes))
        if not ptr:
            return None
        return ptr.bitcast[A]()

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

    fn set_auxdata[
        data_origin: MutOrigin
    ](self, arg: Int, data: MutOpaquePointer[data_origin], destructor: ResultDestructorFn):
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
