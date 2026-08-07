"""Authorizer callback.

This module provides the Mojo-facing callback type, action/result enums,
and C-ABI trampoline used to bridge a user-defined Mojo function to the
SQLite `sqlite3_set_authorizer()` API.

The primary entry points are `Connection.register_authorizer()` and
`Connection.clear_authorizer()`.

See:
- https://www.sqlite.org/c3ref/set_authorizer.html
- https://www.sqlite.org/c3ref/c_alter_table.html
"""

from std.ffi import c_char, c_int, CStringSlice
from slight.c.types import MutExternalPointer, ImmExternalPointer, ImmExternalStringSlice


# ── Authorizer action codes ─────────────────────────────────────────────


@fieldwise_init
struct AuthAction(Equatable, TrivialRegisterPassable, Writable):
    """Action codes passed to the authorizer callback, describing the kind
    of access being checked during statement preparation.

    Only a common subset of the SQLite action codes is provided here; see
    https://www.sqlite.org/c3ref/c_alter_table.html for the complete list.
    Unrecognized codes can still be matched by comparing `.value` directly.
    """

    var value: Int32
    """Internal enum value."""

    comptime CREATE_TABLE = Self(2)
    """`SQLITE_CREATE_TABLE`: A table is being created."""
    comptime DELETE = Self(9)
    """`SQLITE_DELETE`: A `DELETE` statement is being prepared."""
    comptime DROP_TABLE = Self(11)
    """`SQLITE_DROP_TABLE`: A table is being dropped."""
    comptime INSERT = Self(18)
    """`SQLITE_INSERT`: An `INSERT` statement is being prepared."""
    comptime PRAGMA = Self(19)
    """`SQLITE_PRAGMA`: A `PRAGMA` statement is being prepared."""
    comptime READ = Self(20)
    """`SQLITE_READ`: A column is being read."""
    comptime SELECT = Self(21)
    """`SQLITE_SELECT`: A `SELECT` statement is being prepared."""
    comptime TRANSACTION = Self(22)
    """`SQLITE_TRANSACTION`: A transaction operation is being prepared."""
    comptime UPDATE = Self(23)
    """`SQLITE_UPDATE`: An `UPDATE` statement is being prepared."""
    comptime ATTACH = Self(24)
    """`SQLITE_ATTACH`: A database is being attached."""
    comptime DETACH = Self(25)
    """`SQLITE_DETACH`: A database is being detached."""
    comptime FUNCTION = Self(31)
    """`SQLITE_FUNCTION`: A function is being invoked."""

    def __eq__(self, other: Self) -> Bool:
        """Test equality.

        Args:
            other: The other action code.

        Returns:
            True if both have the same value.
        """
        return self.value == other.value


# ── Authorizer result codes ─────────────────────────────────────────────


@fieldwise_init
struct AuthResult(Equatable, TrivialRegisterPassable, Writable):
    """Result codes returned by an authorizer callback."""

    var value: Int32
    """Internal enum value."""

    comptime OK = Self(0)
    """`SQLITE_OK`: Allow the action."""
    comptime DENY = Self(1)
    """`SQLITE_DENY`: Abort the SQL statement with an error."""
    comptime IGNORE = Self(2)
    """`SQLITE_IGNORE`: Disallow the specific action but allow the SQL
    statement to continue (e.g. treat a denied column read as NULL)."""

    def __eq__(self, other: Self) -> Bool:
        """Test equality.

        Args:
            other: The other result code.

        Returns:
            True if both have the same value.
        """
        return self.value == other.value


# ── Callback type ────────────────────────────────────────────────────────


comptime AuthorizerFn = def(
    AuthAction,
    Optional[ImmExternalStringSlice],
    Optional[ImmExternalStringSlice],
    Optional[ImmExternalStringSlice],
    Optional[ImmExternalStringSlice]
) thin -> AuthResult
"""User-provided authorizer callback type for `Connection.register_authorizer()`.

Invoked during statement preparation for each action that requires
authorization. Receives the action code and up to two subject arguments,
the database name, and (for triggers/views) the name of the trigger or
view responsible for the access — any of which may be `None` depending on
the action. Returns an `AuthResult` deciding whether to allow, deny, or
ignore the action.
"""


# ── C-compatible callback ────────────────────────────────────────────────


def _optional_c_string_slice(ptr: Optional[ImmExternalPointer[c_char]]) -> Optional[ImmExternalStringSlice]:
    """Decode a possibly-NULL `const char*` into an `Optional[StringSpan]`.

    Args:
        ptr: The pointer to decode.

    Returns:
        `None` if `ptr` is NULL, otherwise the decoded `StringSpan`.
    """
    if not ptr:
        return None
    return StringSpan(unsafe_from_utf8=CStringSlice(unsafe_from_ptr=ptr.value()))


def _authorizer_callback(
    ctx: MutExternalPointer[NoneType],
    action: c_int,
    arg1: Optional[ImmExternalPointer[c_char]],
    arg2: Optional[ImmExternalPointer[c_char]],
    db_name: Optional[ImmExternalPointer[c_char]],
    trigger_or_view: Optional[ImmExternalPointer[c_char]],
) abi("C") -> c_int:
    """C-compatible callback for `sqlite3_set_authorizer`.

    Reconstructs the user's `AuthorizerFn` from the `ctx` void pointer,
    decodes the (possibly-NULL) string arguments, and invokes it.

    Args:
        ctx: Void pointer whose address value IS the `AuthorizerFn` pointer.
        action: The action code being authorized.
        arg1: First subject argument (meaning depends on `action`), or NULL.
        arg2: Second subject argument (meaning depends on `action`), or NULL.
        db_name: Name of the database being accessed, or NULL.
        trigger_or_view: Name of the trigger or view responsible for the
            access, or NULL if the access is a direct result of top-level SQL.

    Returns:
        One of `AuthResult.OK`, `AuthResult.DENY`, or `AuthResult.IGNORE`.
    """
    # `clear_authorizer` fully unregisters via `sqlite3_set_authorizer(db, NULL,
    # NULL)`, so SQLite never invokes this trampoline once cleared; `ctx` is
    # always a live callback.
    var fn_as_int = Int(ctx)
    var callback = Pointer(to=fn_as_int).unsafe_bitcast[AuthorizerFn]()[]
    var result = callback(
        AuthAction(Int32(action)),
        _optional_c_string_slice(arg1),
        _optional_c_string_slice(arg2),
        _optional_c_string_slice(db_name),
        _optional_c_string_slice(trigger_or_view),
    )
    return c_int(result.value)
