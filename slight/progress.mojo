"""Progress handler.

This module provides the Mojo-facing callback type and C-ABI trampoline
used to bridge a user-defined Mojo function to the SQLite
`sqlite3_progress_handler()` API.

The primary entry points are `Connection.register_progress_handler()` and
`Connection.clear_progress_handler()`.

See: https://www.sqlite.org/c3ref/progress_handler.html
"""

from std.ffi import c_int
from slight.c.types import MutExternalPointer


comptime ProgressHandlerFn = def() thin -> Bool
"""User-provided progress handler callback type for
`Connection.register_progress_handler()`.

Invoked approximately every N virtual-machine instructions during query
execution. Return `True` to INTERRUPT the running query (aborts it with
`SQLITE_INTERRUPT`), or `False` to allow it to keep running.
"""


comptime _NO_CALLBACK_SENTINEL = 1
"""Sentinel `ctx` address meaning "no callback registered" (see `clear_progress_handler`).

`MutExternalPointer` is non-nullable, so a true NULL address cannot be
constructed for the `pArg`-style `ctx` value.
"""


def _progress_handler_callback(ctx: MutExternalPointer[NoneType]) abi("C") -> c_int:
    """C-compatible callback for `sqlite3_progress_handler`.

    Reconstructs the user's `ProgressHandlerFn` from the `ctx` void pointer
    and invokes it. A non-zero return aborts the running query.

    Args:
        ctx: Void pointer whose address value IS the `ProgressHandlerFn` pointer.

    Returns:
        Non-zero to interrupt the running query, zero to continue.
    """
    var fn_as_int = Int(ctx)
    if fn_as_int == _NO_CALLBACK_SENTINEL:
        return c_int(0)
    var callback = Pointer(to=fn_as_int).unsafe_bitcast[ProgressHandlerFn]()[]
    if callback():
        return c_int(1)
    return c_int(0)
