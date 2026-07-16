"""Custom collating sequences.

This module provides the Mojo-facing callback type and C-ABI trampoline
used to bridge a user-defined Mojo comparison function to the SQLite
`sqlite3_create_collation_v2()` API.

The primary entry points are `Connection.create_collation()` and
`Connection.remove_collation()`.

See: https://www.sqlite.org/c3ref/create_collation.html
"""

from std.ffi import c_int
from slight.c.types import MutExternalPointer, ImmutExternalPointer


comptime CollationCompareFn = def(Span[Byte, ImmutUntrackedOrigin], Span[Byte, ImmutUntrackedOrigin]) thin -> Int
"""User-provided collation comparator type for `Connection.create_collation()`.

Given the raw bytes of two values being compared, returns an ordering
integer analogous to C's `strcmp`: negative if `left < right`, zero if
`left == right`, positive if `left > right`.
"""


def _collation_compare_callback(
    ctx: MutExternalPointer[NoneType],
    n_left: Int32,
    left: ImmutExternalPointer[NoneType],
    n_right: Int32,
    right: ImmutExternalPointer[NoneType],
) abi("C") -> c_int:
    """C-compatible callback for `sqlite3_create_collation_v2`.

    Reconstructs the user's `CollationCompareFn` from the `ctx` void pointer,
    builds byte spans over the two operands, and invokes it.

    Args:
        ctx: Void pointer whose address value IS the `CollationCompareFn` pointer.
        n_left: Length in bytes of the left operand.
        left: Pointer to the left operand's bytes.
        n_right: Length in bytes of the right operand.
        right: Pointer to the right operand's bytes.

    Returns:
        Negative if left < right, zero if equal, positive if left > right.
    """
    var fn_as_int = Int(ctx)
    var callback = UnsafePointer(to=fn_as_int).bitcast[CollationCompareFn]()[]
    var left_span = Span[Byte, ImmutUntrackedOrigin](ptr=left.bitcast[Byte](), length=Int(n_left))
    var right_span = Span[Byte, ImmutUntrackedOrigin](ptr=right.bitcast[Byte](), length=Int(n_right))
    return c_int(callback(left_span, right_span))


def _no_op_collation_destructor(pArg: Optional[MutExternalPointer[NoneType]]) abi("C"):
    """No-op destructor for `sqlite3_create_collation_v2`.

    Used when no heap-allocated user data was passed via `pArg` (the
    comparator function pointer is transmuted into the context value
    directly, so there is nothing to free).

    Args:
        pArg: The user data pointer (unused).
    """
    pass
