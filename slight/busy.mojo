"""Busy handler (when the database is locked).

This module provides the busy handler callback type and the C-compatible
callback wrapper used to bridge user-defined Mojo functions to the SQLite
`sqlite3_busy_handler()` API.
"""

from slight.c.types import MutExternalPointer, BusyHandlerFn
from std.ffi import c_int


fn _busy_handler_callback(
    p_arg: MutExternalPointer[NoneType], count: c_int
) -> c_int:
    """C-compatible busy handler callback that delegates to a Mojo function.

    This function is passed as the callback to `sqlite3_busy_handler()`.
    It reconstructs the user's `BusyHandlerFn` from the `p_arg` void pointer
    and invokes it with the retry count.

    Args:
        p_arg: Opaque pointer holding the user's `BusyHandlerFn`.
        count: Number of times the busy handler has been invoked for this event.

    Returns:
        Non-zero to retry, zero to return SQLITE_BUSY.
    """
    var fn_ptr = p_arg.bitcast[BusyHandlerFn]()
    var handler = fn_ptr[]
    return c_int(handler(Int32(count)))
