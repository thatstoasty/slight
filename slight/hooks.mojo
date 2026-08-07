"""Commit, rollback, and update hooks.

This module provides the Mojo-facing callback types and C-ABI trampolines
used to bridge user-defined Mojo functions to the SQLite
`sqlite3_commit_hook()`, `sqlite3_rollback_hook()`, and `sqlite3_update_hook()`
APIs.

The primary entry points are `Connection.register_commit_hook()`,
`Connection.register_rollback_hook()`, and `Connection.register_update_hook()`.

See:
- https://www.sqlite.org/c3ref/commit_hook.html
- https://www.sqlite.org/c3ref/update_hook.html
"""

from std.ffi import c_char, c_int, CStringSlice
from std.memory import MutPointer
from slight.c.types import (
    MutExternalPointer,
    CommitHookCallbackFn,
    RollbackHookCallbackFn,
    UpdateHookCallbackFn,
)


# ── Update operation codes ─────────────────────────────────────────────


@fieldwise_init
struct UpdateOperation(Equatable, TrivialRegisterPassable, Writable):
    """The kind of row-level change reported by an update hook callback.

    Corresponds to the `SQLITE_INSERT`, `SQLITE_UPDATE`, and `SQLITE_DELETE`
    action codes.
    """

    var value: Int32
    """Internal enum value."""

    comptime INSERT = Self(18)
    """`SQLITE_INSERT`: A new row was inserted."""
    comptime DELETE = Self(9)
    """`SQLITE_DELETE`: A row was deleted."""
    comptime UPDATE = Self(23)
    """`SQLITE_UPDATE`: A row was updated."""

    def __eq__(self, other: Self) -> Bool:
        """Test equality.

        Args:
            other: The other operation code.

        Returns:
            True if both have the same value.
        """
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        if self.value == Self.INSERT.value:
            writer.write("SQLITE_INSERT")
        elif self.value == Self.DELETE.value:
            writer.write("SQLITE_DELETE")
        elif self.value == Self.UPDATE.value:
            writer.write("SQLITE_UPDATE")
        else:
            writer.write("SQLITE_UNKNOWN(", self.value, ")")


# ── Callback types ──────────────────────────────────────────────────────


comptime CommitHookFn = def() thin -> Bool
"""User-provided commit hook callback type for `Connection.register_commit_hook()`.

Return `True` to veto the commit and convert it into a rollback, or `False`
to allow the commit to proceed.
"""

comptime RollbackHookFn = def() thin -> NoneType
"""User-provided rollback hook callback type for `Connection.register_rollback_hook()`.

Invoked whenever a transaction is rolled back.
"""

comptime UpdateHookFn = def(UpdateOperation, String, String, Int64) thin -> NoneType
"""User-provided update hook callback type for `Connection.register_update_hook()`.

Invoked whenever a row is inserted, updated, or deleted in a rowid table.
Receives the operation type, the database name, the table name, and the
rowid of the affected row.
"""


# ── C-compatible callbacks ──────────────────────────────────────────────


def _commit_hook_callback(ctx: MutExternalPointer[NoneType]) abi("C") -> c_int:
    """C-compatible callback for `sqlite3_commit_hook`.

    Reconstructs the user's `CommitHookFn` from the `ctx` void pointer and
    invokes it. A non-zero return converts the commit into a rollback.

    A cleared hook is unregistered with a NULL `xCallback`, so SQLite never
    invokes this trampoline once cleared; `ctx` is always a live callback.

    Args:
        ctx: Void pointer whose address value IS the `CommitHookFn` pointer.

    Returns:
        Non-zero to veto the commit (convert to rollback), zero to allow it.
    """
    var fn_as_int = Int(ctx)
    var callback = Pointer(to=fn_as_int).unsafe_bitcast[CommitHookFn]()[]
    if callback():
        return c_int(1)
    return c_int(0)


def _rollback_hook_callback(ctx: MutExternalPointer[NoneType]) abi("C"):
    """C-compatible callback for `sqlite3_rollback_hook`.

    Reconstructs the user's `RollbackHookFn` from the `ctx` void pointer and
    invokes it.

    A cleared hook is unregistered with a NULL `xCallback`, so SQLite never
    invokes this trampoline once cleared; `ctx` is always a live callback.

    Args:
        ctx: Void pointer whose address value IS the `RollbackHookFn` pointer.
    """
    var fn_as_int = Int(ctx)
    var callback = Pointer(to=fn_as_int).unsafe_bitcast[RollbackHookFn]()[]
    callback()


def _update_hook_callback(
    ctx: MutExternalPointer[NoneType],
    op: c_int,
    db_name: MutExternalPointer[c_char],
    table_name: MutExternalPointer[c_char],
    rowid: Int64,
):
    """C-compatible callback for `sqlite3_update_hook`.

    Reconstructs the user's `UpdateHookFn` from the `ctx` void pointer,
    decodes the database and table names, and invokes it.

    A cleared hook is unregistered with a NULL `xCallback`, so SQLite never
    invokes this trampoline once cleared; `ctx` is always a live callback.

    Args:
        ctx: Void pointer whose address value IS the `UpdateHookFn` pointer.
        op: The operation code (SQLITE_INSERT, SQLITE_UPDATE, SQLITE_DELETE).
        db_name: The database name (e.g. "main"), as a `const char*`.
        table_name: The name of the affected table, as a `const char*`.
        rowid: The rowid of the row affected by the change.
    """
    var fn_as_int = Int(ctx)
    var callback = Pointer(to=fn_as_int).unsafe_bitcast[UpdateHookFn]()[]
    var db_str = String(CStringSlice(unsafe_from_ptr=db_name.unsafe_mut_cast[False]().unsafe_bitcast[Int8]()))
    var table_str = String(CStringSlice(unsafe_from_ptr=table_name.unsafe_mut_cast[False]().unsafe_bitcast[Int8]()))
    callback(
        UpdateOperation(Int32(op)),
        db_str,
        table_str,
        rowid,
    )


# ── Stable trampoline pointers ───────────────────────────────────────────
#
# `Pointer(to=some_def_value)` materializes a fresh temporary on each
# use rather than pointing at stable static storage, which is unsafe here
# since SQLite retains `xCallback` past the registering call's return. We
# instead dereference the trampoline once to get its (stable) code address,
# then rebuild an `Pointer` from that raw address on every call.


def _commit_hook_trampoline_ptr() -> MutExternalPointer[CommitHookCallbackFn]:
    """Build a stable pointer to `_commit_hook_callback`.

    Returns:
        A pointer suitable for passing as `xCallback` to `sqlite3_commit_hook`.
    """
    var fn_val: CommitHookCallbackFn = _commit_hook_callback
    var addr = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
    return MutExternalPointer[CommitHookCallbackFn](unsafe_from_address=addr)


def _rollback_hook_trampoline_ptr() -> MutExternalPointer[RollbackHookCallbackFn]:
    """Build a stable pointer to `_rollback_hook_callback`.

    Returns:
        A pointer suitable for passing as `xCallback` to `sqlite3_rollback_hook`.
    """
    var fn_val: RollbackHookCallbackFn = _rollback_hook_callback
    var addr = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
    return MutExternalPointer[RollbackHookCallbackFn](unsafe_from_address=addr)


def _update_hook_trampoline_ptr() -> MutExternalPointer[UpdateHookCallbackFn]:
    """Build a stable pointer to `_update_hook_callback`.

    Returns:
        A pointer suitable for passing as `xCallback` to `sqlite3_update_hook`.
    """
    var fn_val: UpdateHookCallbackFn = _update_hook_callback
    var addr = Pointer(to=fn_val).unsafe_bitcast[Int]()[]
    return MutExternalPointer[UpdateHookCallbackFn](unsafe_from_address=addr)
