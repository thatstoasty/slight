"""SQLite Function Evaluation Context."""
from std.ffi import c_int, CStringSlice
from slight.c.types import MutExternalPointer, sqlite3_connection, sqlite3_context, sqlite3_value, ResultDestructorFn
from slight.api import sqlite_ffi
from slight.types import value_ref, value
from slight.types.value_ref import ValueRef
from slight.enums import DataType, DestructorHint, TextEncoding
from slight.types.to_sql import ToSqlOutput


@fieldwise_init
struct Context(Boolable, Movable, Sized):
    """A wrapper for the SQLite function evaluation context.

    Provides convenient access to function arguments and methods to set
    the function result. This struct wraps the raw `sqlite3_context` and
    argument pointers passed to user-defined SQL function callbacks.

    #### Example:

    ```mojo
    from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
    from slight.context import Context

    def my_func(
        raw_ctx: MutExternalPointer[sqlite3_context],
        argc: Int32,
        argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    ):
        var ctx = Context(raw_ctx, argc, argv)
        var value = ctx.get_int64(0)
        ctx.result_int64(value * 2)
    ```
    """

    var _ctx: MutExternalPointer[sqlite3_context]
    """The raw SQLite function context pointer."""
    var _args: List[MutExternalPointer[sqlite3_value]]
    """The number of arguments passed to the function."""

    def __init__(
        out self,
        ctx: MutExternalPointer[sqlite3_context],
    ):
        """Initialize a Context from raw callback arguments.

        Args:
            ctx: The raw SQLite function context pointer.
        """
        self._ctx = ctx
        self._args = []

    def __init__(
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
        self._ctx = ctx
        self._args = [argv[unsafe_offset=i] for i in range(argc)]

    # ===------------------------------------------------------------------=== #
    # Argument Access
    # ===------------------------------------------------------------------=== #

    def unsafe_ptr[
        origin: Origin, address_space: AddressSpace, //
    ](ref[origin, address_space] self) -> Pointer[sqlite3_context, origin, address_space=address_space]:
        """Retrieves a pointer to the underlying memory.

        Parameters:
            origin: The origin of the `Context`.
            address_space: The `AddressSpace` of the `Context`.

        Returns:
            The pointer to the underlying memory.
        """
        return (
            self._ctx.unsafe_mut_cast[origin.mut]()
            .unsafe_origin_cast[origin]()
            .unsafe_address_space_cast[address_space]()
        )

    @always_inline
    def __len__(self) -> Int:
        """Returns the number of arguments to the function.

        Returns:
            The number of arguments.
        """
        return len(self._args)

    @always_inline
    def __bool__(self) -> Bool:
        """Returns True when there are arguments.

        Returns:
            True if there are arguments, False otherwise.
        """
        return len(self._args) > 0

    def get_raw(self, idx: Int) -> ValueRef[origin_of(self)]:
        """Returns the `idx`th argument as a `ValueRef`.

        This reads the type and value from the raw sqlite3_value pointer.

        Args:
            idx: The 0-based argument index.

        Returns:
            A ValueRef containing the argument's value with its appropriate type.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return ValueRef[origin_of(self)](self._args[idx])

    def get_int64(self, idx: Int) -> Int64:
        """Returns the `idx`th argument as an Int64.

        This calls `sqlite3_value_int64` directly, performing SQLite's type
        coercion if the value is not an integer.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a 64-bit integer.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return sqlite_ffi()[].value_int64(self._args[idx])

    def get_double(self, idx: Int) -> Float64:
        """Returns the `idx`th argument as a Float64.

        This calls `sqlite3_value_double` directly, performing SQLite's type
        coercion if the value is not a float.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a 64-bit floating point.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return sqlite_ffi()[].value_double(self._args[idx])

    def get_text(self, idx: Int) -> Optional[CStringSlice[origin_of(self)]]:
        """Returns the `idx`th argument as a CStringSlice.

        This calls `sqlite3_value_text` directly. The returned slice
        references memory managed by SQLite and is valid for the duration
        of the callback.

        Args:
            idx: The 0-based argument index.

        Returns:
            The argument value as a CStringSlice.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        var text = sqlite_ffi()[].value_text(self._args[idx])
        if not text:
            return None

        # We're laundering the origin here. It should be safe because the value should
        # live as long as the context is alive. That conveys more information than using an external origin.
        return CStringSlice(
            unsafe_from_ptr=text.value().unsafe_ptr().unsafe_bitcast[Int8]().unsafe_origin_cast[origin_of(self)](),
        )

    def get_blob(self, idx: Int) -> Optional[Span[Byte, origin_of(self)]]:
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
        var blob = sqlite_ffi()[].value_blob(self._args[idx])
        if not blob:
            return None

        # We're laundering the origin here. It should be safe because the value should
        # live as long as the context is alive. That conveys more information than using an external origin.
        return Span(
            unsafe_ptr=blob.value().unsafe_ptr().unsafe_origin_cast[origin_of(self)](),
            length=len(blob.value()),
        )

    def get_subtype(self, idx: Int) -> UInt32:
        """Returns the subtype of the `idx`th argument.

        Args:
            idx: The 0-based argument index.

        Returns:
            The subtype value.
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return sqlite_ffi()[].value_subtype(self._args[idx])

    def get_value_type(self, idx: Int) -> DataType:
        """Returns the fundamental datatype of the `idx`th argument.

        Args:
            idx: The 0-based argument index.

        Returns:
            The DataType of the argument (INTEGER, FLOAT, TEXT, BLOB, or NULL).
        """
        debug_assert(idx < len(self), "Argument index out of bounds")
        return DataType(sqlite_ffi()[].value_type(self._args[idx]))

    # ===------------------------------------------------------------------=== #
    # Result Setting
    # ===------------------------------------------------------------------=== #

    def result_int64(mut self, value: Int64):
        """Set the result of the function to a 64-bit integer.

        Args:
            value: The integer value to return.
        """
        sqlite_ffi()[].result_int64(self.unsafe_ptr(), value)

    def result_double(mut self, value: Float64):
        """Set the result of the function to a floating-point value.

        Args:
            value: The floating-point value to return.
        """
        sqlite_ffi()[].result_double(self.unsafe_ptr(), value)

    def result_text(mut self, var value: String):
        """Set the result of the function to a text string.

        SQLite makes its own copy of the string (uses SQLITE_TRANSIENT).

        Args:
            value: The text string to return.
        """
        sqlite_ffi()[].result_text64(
            self.unsafe_ptr(),
            value,
            UInt64(value.byte_length()),
            TextEncoding.UTF8.value,
            DestructorHint.transient_destructor(),
        )

    def result_null(mut self):
        """Set the result of the function to NULL."""
        sqlite_ffi()[].result_null(self.unsafe_ptr())

    def result_blob[origin: ImmOrigin, //](mut self, data: Span[Byte, origin]):
        """Set the result of the function to a BLOB value.

        SQLite makes its own copy of the data (uses SQLITE_TRANSIENT).

        Args:
            data: The blob data to return.
        """
        sqlite_ffi()[].result_blob64(
            self.unsafe_ptr(),
            data.unsafe_ptr().unsafe_bitcast[NoneType](),
            UInt64(len(data)),
            DestructorHint.transient_destructor(),
        )

    def result_error(mut self, msg: Some[Writable]):
        """Set the result of the function to an error.

        Args:
            msg: The error message string.
        """
        var msg_copy = String(msg)
        sqlite_ffi()[].result_error(self.unsafe_ptr(), msg_copy, c_int(-1))

    def result_error_code(mut self, code: Int32):
        """Set the result of the function to an error code.

        Args:
            code: The SQLite error code.
        """
        sqlite_ffi()[].result_error_code(self.unsafe_ptr(), code)

    def result_error_no_mem(mut self):
        """Set the result of the function to SQLITE_NOMEM (out of memory)."""
        sqlite_ffi()[].result_error_nomem(self.unsafe_ptr())

    def result_error_too_big(mut self):
        """Set the result of the function to SQLITE_TOOBIG (too big)."""
        sqlite_ffi()[].result_error_toobig(self.unsafe_ptr())

    def result_value(mut self, value: MutExternalPointer[sqlite3_value]):
        """Set the result of the function to a copy of another sqlite3_value.

        Args:
            value: The value to copy as the result.
        """
        sqlite_ffi()[].result_value(self.unsafe_ptr(), value)

    def result_zero_blob(mut self, n: Int32):
        """Set the result of the function to a zero-filled BLOB.

        Args:
            n: The number of zero-filled bytes.
        """
        sqlite_ffi()[].result_zeroblob(self.unsafe_ptr(), n)

    def result_subtype(mut self, subtype: UInt32):
        """Set the subtype of the function result.

        Args:
            subtype: The subtype value.
        """
        sqlite_ffi()[].result_subtype(self.unsafe_ptr(), subtype)

    def set_result[origin: ImmOrigin, //](mut self, result: ValueRef[origin]):
        """Set the function result based on a ValueRef.

        This is a convenience method that checks the type of the ValueRef and
        calls the appropriate result-setting method.

        Args:
            result: The ValueRef containing the value to set as the function result.
        """
        if result.isa[value_ref.Null]():
            self.result_null()
        elif result.isa[value_ref.Integer]():
            self.result_int64(result[value_ref.Integer].value)
        elif result.isa[value_ref.Real]():
            self.result_double(result[value_ref.Real].value)
        elif result.isa[value_ref.Text[origin_of(result)]]():
            self.result_text(String(result[value_ref.Text[origin_of(result)]].value))
        elif result.isa[value_ref.Blob[origin_of(result)]]():
            ref value = result[value_ref.Blob[origin_of(result)]].value
            if len(value) == 0:
                self.result_zero_blob(0)
            else:
                self.result_blob(result[value_ref.Blob[origin_of(result)]].value)
        else:
            self.result_error("Unsupported return type from function.")
        return

    def set_result_output[origin: ImmOrigin, //](mut self, output: ToSqlOutput[origin]):
        """Set the function result from a `ToSqlOutput`.

        Handles both arms: a borrowed `ValueRef` is forwarded to `set_result`,
        while an owned `Value` has its payload read directly. Every
        result-setting call below copies into SQLite, so the owned buffers may
        be released as soon as this returns.

        Args:
            output: The `ToSqlOutput` produced by a `ToSQL` conversion.
        """
        if output.isa[value.Value]():
            ref owned = output[value.Value]
            if owned.isa[value.Null]():
                self.result_null()
            elif owned.isa[value.Integer]():
                self.result_int64(owned[value.Integer].value)
            elif owned.isa[value.Real]():
                self.result_double(owned[value.Real].value)
            elif owned.isa[value.Text]():
                self.result_text(owned[value.Text].value.copy())
            elif owned.isa[value.Blob]():
                ref b = owned[value.Blob].value
                if len(b) == 0:
                    self.result_zero_blob(0)
                else:
                    self.result_blob(Span(b))
            else:
                self.result_error("Unsupported return type from function.")
            return

        self.set_result(output[ValueRef[origin_of(output)]])

    # ===------------------------------------------------------------------=== #
    # Aggregate Helpers
    # ===------------------------------------------------------------------=== #

    def aggregate_context[A: Movable](mut self, n_bytes: Int) -> Optional[MutExternalPointer[A]]:
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
        var ptr = sqlite_ffi()[].aggregate_context(self.unsafe_ptr(), c_int(n_bytes))
        if not ptr:
            return None
        return ptr.take().unsafe_bitcast[A]()

    def user_data(self) -> Optional[MutExternalPointer[NoneType]]:
        """Get the user data pointer that was passed to `create_scalar_function`,
        `create_aggregate_function`, or `create_window_function`.

        This is the `pApp` pointer that was passed when registering the function.

        Returns:
            The user data pointer, or None if none was set.
        """
        return sqlite_ffi()[].user_data(self.unsafe_ptr())

    def context_db_handle(mut self) -> Optional[MutExternalPointer[sqlite3_connection]]:
        """Get the database connection handle from the function context.

        Returns:
            The database connection handle, or None if an error occurred in SQLite.
            It may error if:
                * Context is modified: If you use a sqlite3_context pointer that has been altered, corrupted, or passed incorrectly to the function.
                * Invalid context passed: If the context being evaluated is not associated with an active, valid database connection (such as during unassociated test setups or specific internal sqlite3 sub-routines).
        """
        return sqlite_ffi()[].context_db_handle(self.unsafe_ptr())

    def get_auxdata(self, arg: Int) -> Optional[MutExternalPointer[NoneType]]:
        """Get the auxiliary data associated with a particular parameter.

        Returns the auxiliary data that was previously set using `set_auxdata`.
        This is useful for caching per-query data across multiple function calls.

        Args:
            arg: The argument index for the auxiliary data.

        Returns:
            Previously set auxiliary data pointer, or null if none exists.
        """
        return sqlite_ffi()[].get_auxdata(self.unsafe_ptr(), c_int(arg))

    def set_auxdata[
        data_origin: MutOrigin, //
    ](mut self, arg: Int, data: MutOpaquePointer[data_origin], destructor: ResultDestructorFn):
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
        sqlite_ffi()[].set_auxdata(self.unsafe_ptr(), c_int(arg), data, destructor)
