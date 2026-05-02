from std.ffi import c_int
from std.sys import size_of
from slight.c.types import MutExternalPointer, sqlite3_context, sqlite3_value
from slight.types.value_ref import ValueRef
from slight.context import Context
from slight.util import CopyDestructible, MoveDestructible


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

    def __or__(self, other: Self) -> Self:
        """Combines two FunctionFlags using a bitwise OR operation.

        This allows multiple flags to be set at once when creating a SQL function.

        Args:
            other: The second FunctionFlags to combine with the first.

        Returns:
            A new FunctionFlags that is the result of combining the two flags with a bitwise OR operation.
        """
        return Self(self.value | other.value)


def _default_destructor(pApp: MutExternalPointer[NoneType]):
    """Default destructor for user-defined function application data.

    This function is used as the destructor callback when creating user-defined functions
    with application data. It checks if the provided pointer is valid and frees it if so.

    Args:
        pApp: A mutable external pointer to the application data.
    """
    if pApp:
        pApp.free()


# For scalar functions, SQLite requires xFunc to be non-NULL and
# xStep/xFinal to be NULL. We call the raw C API directly to pass
# NULL for the unused callbacks.
comptime ScalarUDF[V: MoveDestructible] = def(Context) raises thin -> V
"""User provided scalar function callback.

Parameters:
    V: The return type of the scalar function, which must conform to `ToSQL`.
"""

def _call_scalar_callback[
    V: MoveDestructible, //,
    func: ScalarUDF[V]
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) -> NoneType:
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
    # Convert raw C callback to our Context wrapper and call the user-provided function
    var context = Context(ctx, argc, argv)
    
    var fn_result: V
    try:
        fn_result = func(context)
    except e:
        # If the user's function raises an error, we need to convert it to a SQLite error result.
        context.result_error(t"Error in scalar function: {e}")
        return
    
    var result: ValueRef[origin_of(fn_result)]
    try:
        result = trait_downcast[ToSQL](fn_result).to_sql()
    except e:
        context.result_error(t"Error converting result to SQL: {e}")
        return
    
    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    context.set_result(result)
    return

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

def _call_step_callback[
    A: MoveDestructible,
    //,
    init_fn: AggregateInitUDF[A],
    step_fn: AggregateStepUDF[A],
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) -> NoneType:
    """The xStep callback for the aggregate function.

    This is called once for each row in the group being aggregated. This is a wrapper
    around the user provided `init_fn` and `step_fn` that manages the aggregate context for the user.
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
    var agg_context = context.aggregate_context[A](size_of[A]())
    # TODO: Throw sqlite3_result_error_nomem if we fail to allocate memory for the aggregate context.
    if not agg_context:
        var agg_context_ptr = alloc[A](count=1)
        try:
            agg_context_ptr[0] = init_fn(context)
        except e:
            # If the user's init function raises an error, we need to convert it to a SQLite error result.
            context.result_error(t"Error in aggregate init function: {e}")
            return
        agg_context = Optional[UnsafePointer[A, MutExternalOrigin]](agg_context_ptr)

    try:
        step_fn(context, agg_context.value()[])
    except e:
        context.result_error(t"Error in aggregate step function: {e}")
        return
    return


def _call_final_callback[
    A: MoveDestructible,
    T: MoveDestructible,
    //,
    final_fn: AggregateFinalUDF[A, T],
](ctx: MutExternalPointer[sqlite3_context]) -> NoneType:
    """The xFinal callback for the aggregate function.

    This is called once at the end of the aggregation to compute the final result. This is a wrapper
    around the user provided `final_fn` that manages the aggregate context for the user and converts
    the result to the appropriate SQLite type.
    This function matches the function signature expected by the C API.

    Parameters:
        A: The type of the aggregate context, which is updated by the xStep callback and passed to `final_fn`.
        T: The return type of the final function, which must conform to `ToSQL`.
        final_fn: The user-provided function to compute the final result from the aggregate context.

    Args:
        ctx: The SQLite context for the aggregate function.
    """
    var context = Context(ctx)
    var agg_context = context.aggregate_context[A](0)
    if not agg_context:
        context.result_error_no_mem()
        return

    var finalize_result: T
    try:
        finalize_result = final_fn(context, agg_context.value()[])
    except e:
        # If the user's final function raises an error, we need to convert it to a SQLite error result.
        context.result_error(t"Error in aggregate final function: {e}")
        return

    var result: ValueRef[origin_of(finalize_result)]
    try:
        result = trait_downcast[ToSQL](finalize_result).to_sql()
    except e:
        context.result_error(t"Error converting final result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    # ToSQL is implemented on most of the important stdlib types.
    context.set_result(result)
    return


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
    A: CopyDestructible,
    T: MoveDestructible,
    //,
    value_fn: WindowAggregateValueUDF[A, T]
](ctx: MutExternalPointer[sqlite3_context]) -> NoneType:
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
    var context = Context(ctx)
    # Set n_bytes to 0 so no unneccessary allocations occur
    var agg_context = context.aggregate_context[A](0)
    if not agg_context:
        context.result_error_no_mem()
        return

    var value_result: T
    try:
        value_result = value_fn(agg_context.value()[].copy())
    except e:
        context.result_error(t"Error in window function value callback: {e}")
        return

    var result: ValueRef[origin_of(value_result)]
    try:
        result = trait_downcast[ToSQL](value_result).to_sql()
    except e:
        context.result_error(t"Error converting window function value result to SQL: {e}")
        return

    # Convert the result of the user's `func` to the appropriate SQLite type and set it on the context.
    # ToSQL is implemented on most of the important stdlib types.
    context.set_result(result)
    return

def _call_inverse_callback[
    A: CopyDestructible, //, inverse_fn: WindowAggregateInverseUDF[A]
](
    ctx: MutExternalPointer[sqlite3_context],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) -> NoneType:
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
    var agg_context = context.aggregate_context[A](0)
    if not agg_context:
        context.result_error_no_mem()
        return

    try:
        inverse_fn(context, agg_context.value()[])
    except e:
        context.result_error(t"Error in window function inverse callback: {e}")
        return
    return
