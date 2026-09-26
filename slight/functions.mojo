"""Function creation helpers."""
from std.ffi import c_int
from std.memory.alloc import unsafe_alloc
from std.sys import size_of
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.types.to_sql import ToSQL, ToSqlOutput
from slight.types.value_ref import ValueRef
from slight.context import Context
from slight.util import CopyDestructible, MoveDestructible


@fieldwise_init
struct FunctionFlags(TrivialRegisterPassable, Writable):
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

    def __or__(self, other: Self) -> Self:
        """Combines two FunctionFlags using a bitwise OR operation.

        This allows multiple flags to be set at once when creating a SQL function.

        Args:
            other: The second FunctionFlags to combine with the first.

        Returns:
            A new FunctionFlags that is the result of combining the two flags with a bitwise OR operation.
        """
        return Self(self.value | other.value)


def _typed_destructor[T: CopyDestructible](pApp: Optional[MutExternalPointer[NoneType]]) abi("C"):
    """Destructor for user-defined function application data of type `T`.

    Used as the destructor callback when creating user-defined functions with
    application data. `ptr_copy` heap-copies a full `T` into the block that
    SQLite hands back here, so the pointee's destructor must run before the
    block is freed — otherwise any heap data owned by `T` (a `String`, `List`,
    `Dict`, ...) is leaked.

    This is parameterized on `T` so each instantiation knows the concrete type
    to destroy; a single untyped `void*` destructor cannot do this correctly.

    Parameters:
        T: The type of the application data the pointer refers to.

    Args:
        pApp: A mutable external pointer to the application data.
    """
    if pApp:
        var ptr = pApp.value().unsafe_bitcast[T]()
        ptr.unsafe_deinit_pointee()
        ptr.unsafe_free()


# For scalar functions, SQLite requires xFunc to be non-NULL and
# xStep/xFinal to be NULL. We call the raw C API directly to pass
# NULL for the unused callbacks.
comptime ScalarUDF[V: MoveDestructible] = def(mut ctx: Context) raises thin -> V
"""User provided scalar function callback.

Parameters:
    V: The return type of the scalar function, which must conform to `ToSQL`.
"""


def _call_scalar_callback[
    V: MoveDestructible, //, func: ScalarUDF[V]
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) abi("C"):
    """The xFunc callback for the scalar function.

    This is a wrapper around the user provided `func` that converts the raw C callback parameters
    into a `Context` object, calls the user's function, and then converts the result back to the appropriate SQLite type.
    This function matches the function signature expected by the C API.

    Parameters:
        V: The return type of the scalar function, which must conform to `ToSQL`.
        func: The user-provided function to be called for the scalar function.

    Args:
        ctx: The SQLite context for the function call.
        argc: The number of arguments passed to the function.
        argv: The arguments passed to the function.
    """
    comptime assert conforms_to(V, ToSQL), String(
        t"`func` must return a type that conforms to `ToSQL`. {reflect[V].name()} does not implement `ToSQL`."
    )

    # Convert raw C callback to our Context wrapper and call the user-provided function
    var context = Context(ctx, argc, argv)

    var fn_result: V
    try:
        fn_result = func(context)
    except e:
        # If the user's function raises an error, we need to convert it to a SQLite error result.
        context.result_error(t"Error in scalar function: {e}")
        return

    var result: ToSqlOutput[origin_of(fn_result)]
    try:
        result = fn_result.to_sql()
    except e:
        context.result_error(t"Error converting result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    context.set_result_output(result)


comptime AggregateInitUDF[A: MoveDestructible] = def(mut ctx: Context) raises thin -> A
"""User provided aggregate function initialization callback.

Parameters:
    A: The type of the aggregate context, which must be initialized by this function and updated by the step function.
"""
comptime AggregateStepUDF[A: MoveDestructible] = def(mut ctx: Context, mut acc: A) raises thin
"""User provided aggregate function step callback.

Parameters:
    A: The type of the aggregate context, which is initialized by the init function on the first call and updated by this function on each call.
"""
comptime AggregateFinalUDF[A: MoveDestructible, T: MoveDestructible] = def(mut ctx: Context, acc: A) raises thin -> T
"""User provided aggregate function final callback.

Parameters:
    A: The type of the aggregate context, which is updated by the step function and passed to this function.
    T: The return type of the final function, which must conform to `ToSQL`.
"""


comptime _AggregateSlot[A: MoveDestructible] = Optional[MutExternalPointer[A]]
"""What SQLite's aggregate context holds for an aggregate with accumulator `A`.

SQLite zero-fills the aggregate context on first use, which is the `None`
(null) state of this `Optional`, so "no accumulator yet" is distinguishable
from a real one. The accumulator itself lives on the Mojo heap: it is created
by `init_fn` on the first `xStep`, and destroyed in `xFinal`, which SQLite
calls exactly once per aggregate (including when the query fails or stops
early).

Parameters:
    A: The type of the aggregate accumulator.
"""


def _aggregate_slot[
    A: MoveDestructible
](mut context: Context, allocate: Bool) -> Optional[MutExternalPointer[_AggregateSlot[A]]]:
    """Returns this aggregate's slot in SQLite's aggregate context.

    Parameters:
        A: The type of the aggregate accumulator.

    Args:
        context: The SQLite context for the aggregate function.
        allocate: Whether to allocate the (zeroed) slot if it does not exist
            yet. Only `xStep` allocates; the other callbacks pass False, and
            get `None` if `xStep` never ran (for example over zero rows).

    Returns:
        A pointer to the slot, or `None` if it was not allocated (either
        because `allocate` is False, or because SQLite ran out of memory).
    """
    comptime assert (
        size_of[_AggregateSlot[A]]() == size_of[MutExternalPointer[A]]()
    ), "Optional[pointer] must be pointer-sized so a zero-filled aggregate context reads as None."
    return context.aggregate_context[_AggregateSlot[A]](size_of[_AggregateSlot[A]]() if allocate else 0)


def _call_step_callback[
    A: MoveDestructible,
    //,
    init_fn: AggregateInitUDF[A],
    step_fn: AggregateStepUDF[A],
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) abi("C"):
    """The xStep callback for the aggregate function.

    This is called once for each row in the group being aggregated. This is a wrapper
    around the user provided `init_fn` and `step_fn` that manages the aggregate context for the user.
    On the first row of each group, `init_fn` creates the accumulator.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is initialized by `init_fn` and updated by `step_fn`.
        init_fn: The user-provided function to initialize the aggregate context on the first call.
        step_fn: The user-provided function to update the aggregate context on each call.

    Args:
        ctx: The SQLite context for the aggregate function.
        argc: The number of arguments passed to the function.
        argv: The arguments passed to the function.
    """
    var context = Context(ctx, argc, argv)
    var slot = _aggregate_slot[A](context, allocate=True)
    if not slot:
        context.result_error_no_mem()
        return

    ref acc = slot.value()[]
    if not acc:
        var initial: A
        try:
            initial = init_fn(context)
        except e:
            # If the user's init function raises an error, we need to convert it to a SQLite error result.
            context.result_error(t"Error in aggregate init function: {e}")
            return
        var ptr = unsafe_alloc[A](count=1)
        ptr.unsafe_write(initial^)
        acc = ptr

    try:
        step_fn(context, acc.value()[])
    except e:
        context.result_error(t"Error in aggregate step function: {e}")
        return


def _call_final_callback[
    A: MoveDestructible,
    T: MoveDestructible,
    //,
    init_fn: AggregateInitUDF[A],
    final_fn: AggregateFinalUDF[A, T],
](ctx: MutExternalPointer[sqlite3_context]) abi("C"):
    """The xFinal callback for the aggregate function.

    This is called once at the end of the aggregation to compute the final result. This is a wrapper
    around the user provided `final_fn` that manages the aggregate context for the user and converts
    the result to the appropriate SQLite type. It also destroys the accumulator created by `xStep`.
    If `xStep` never ran (an aggregate over zero rows), `init_fn` provides the accumulator instead.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `final_fn`.
        T: The return type of the final function, which must conform to `ToSQL`.
        init_fn: The user-provided function to initialize the aggregate context, used when no rows were aggregated.
        final_fn: The user-provided function to compute the final result from the aggregate context.

    Args:
        ctx: The SQLite context for the aggregate function.
    """
    comptime assert conforms_to(T, ToSQL), String(
        t"`final_fn` must return a type that conforms to `ToSQL`. {reflect[T].name()} does not implement `ToSQL`."
    )
    var context = Context(ctx)
    var slot = _aggregate_slot[A](context, allocate=False)

    var acc: MutExternalPointer[A]
    if slot and slot.value()[]:
        acc = slot.value()[].value()
        # Clear the slot first so the accumulator can never be freed twice.
        slot.value()[] = None
    else:
        # `xStep` never ran (zero input rows), or its `init_fn` failed.
        var initial: A
        try:
            initial = init_fn(context)
        except e:
            context.result_error(t"Error in aggregate init function: {e}")
            return
        acc = unsafe_alloc[A](count=1)
        acc.unsafe_write(initial^)

    var finalize_result: T
    try:
        finalize_result = final_fn(context, acc[])
    except e:
        acc.unsafe_deinit_pointee()
        acc.unsafe_free()
        # If the user's final function raises an error, we need to convert it to a SQLite error result.
        context.result_error(t"Error in aggregate final function: {e}")
        return
    acc.unsafe_deinit_pointee()
    acc.unsafe_free()

    var result: ToSqlOutput[origin_of(finalize_result)]
    try:
        result = finalize_result.to_sql()
    except e:
        context.result_error(t"Error converting final result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    # ToSQL is implemented on most of the important stdlib types.
    context.set_result_output(result)


comptime WindowAggregateValueUDF[A: CopyDestructible, T: MoveDestructible] = def(acc: Optional[A]) raises thin -> T
"""User provided aggregate function initialization callback.

Parameters:
    A: The type of the aggregate context, which is updated by the xStep callback and passed to this function to compute the current value of the window function for window frames.
    T: The return type of the value function, which must conform to `ToSQL`.
"""
comptime WindowAggregateInverseUDF[A: CopyDestructible] = def(mut ctx: Context, mut acc: A) raises thin
"""User provided aggregate function initialization callback.

Parameters:
    A: The type of the aggregate context, which is updated by the xStep callback and passed to this function to compute the current value of the window function for window frames.
"""


def _call_value_callback[
    A: CopyDestructible, T: MoveDestructible, //, value_fn: WindowAggregateValueUDF[A, T]
](ctx: MutExternalPointer[sqlite3_context]) abi("C"):
    """The xValue callback for the window function.

    This is called to compute the current value of the window function without finalizing, for use in window frames.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `value_fn`.
        T: The return type of the value function, which must conform to `ToSQL`.
        value_fn: The user-provided function to compute the current value from the aggregate context for window functions.

    Args:
        ctx: The SQLite context for the window function.
    """
    comptime assert conforms_to(T, ToSQL), String(
        t"`value_fn` must return a type that conforms to `ToSQL`. {reflect[T].name()} does not implement `ToSQL`."
    )
    var context = Context(ctx)
    var slot = _aggregate_slot[A](context, allocate=False)
    var acc: Optional[A] = None
    if slot and slot.value()[]:
        acc = slot.value()[].value()[].copy()

    var value_result: T
    try:
        value_result = value_fn(acc^)
    except e:
        context.result_error(t"Error in window function value callback: {e}")
        return

    var result: ToSqlOutput[origin_of(value_result)]
    try:
        result = value_result.to_sql()
    except e:
        context.result_error(t"Error converting window function value result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    # ToSQL is implemented on most of the important stdlib types.
    context.set_result_output(result)


def _call_inverse_callback[
    A: CopyDestructible, //, inverse_fn: WindowAggregateInverseUDF[A]
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) abi("C"):
    """The `xInverse` callback for user defined window function.

    This is called when a row leaves the window frame, to update the aggregate context accordingly.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `inverse_fn`.
        inverse_fn: The user-provided function to update the aggregate context when a row leaves the window frame for window functions.

    Args:
        ctx: The SQLite context for the window function.
        argc: The number of arguments passed to the function.
        argv: The arguments passed to the function.
    """
    var context = Context(ctx, argc, argv)
    var slot = _aggregate_slot[A](context, allocate=False)
    if not slot or not slot.value()[]:
        # SQLite only calls xInverse for a row that xStep already added.
        context.result_error("Window function inverse called before any step")
        return

    try:
        inverse_fn(context, slot.value()[].value()[])
    except e:
        context.result_error(t"Error in window function inverse callback: {e}")
        return
