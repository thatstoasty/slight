"""[Unlock Notification](http://sqlite.org/unlock_notify.html)

This module provides the unlock-notify mechanism for SQLite shared-cache mode.
When a connection receives `SQLITE_LOCKED` due to shared-cache contention,
`wait_for_unlock_notify` can be used to block until the lock holder commits
or rolls back, then retry the operation.

Note: Mojo does not currently have Mutex/Condvar, so this implementation uses
a simple spin-wait with `sleep` instead of condition-variable signaling.
"""

from std.ffi import c_int
from std.utils.lock import SpinWaiter

from slight.c.api import sqlite_ffi
from slight.c.raw_bindings import (
    SQLITE_LOCKED,
    SQLITE_LOCKED_SHAREDCACHE,
    SQLITE_OK,
    sqlite3_connection,
)
from slight.c.types import MutExternalPointer, MutOpaquePointer
from slight.result import SQLite3Result


fn _unlock_notify_cb(
    ap_arg: MutUnsafePointer[MutExternalPointer[NoneType], MutExternalOrigin],
    n_arg: c_int,
) -> NoneType:
    """C-compatible unlock-notify callback.

    Called by SQLite when the blocking connection's transaction is finished.
    Iterates over each notification argument and sets its fired flag to True.

    Args:
        ap_arg: Array of opaque pointers, each pointing to a Bool flag.
        n_arg: Number of entries in the array.
    """
    for i in range(Int(n_arg)):
        var flag_ptr = ap_arg[i].bitcast[Bool]()
        flag_ptr[] = True
    return None


fn is_locked(
    db: MutExternalPointer[sqlite3_connection], rc: SQLite3Result
) -> Bool:
    """Check whether a result code indicates shared-cache lock contention.

    Args:
        db: The database connection handle.
        rc: The result code returned by a recent SQLite API call.

    Returns:
        True if the error is SQLITE_LOCKED due to shared-cache contention.
    """
    if rc == SQLITE_LOCKED_SHAREDCACHE:
        return True
    return (
        rc.value & 0xFF == SQLITE_LOCKED
        and sqlite_ffi()[].extended_errcode(db) == SQLite3Result.LOCKED_SHAREDCACHE
    )


fn wait_for_unlock_notify(
    db: MutExternalPointer[sqlite3_connection],
) -> SQLite3Result:
    """Block until an unlock-notify callback fires, then return SQLITE_OK.

    This function registers for an unlock-notify callback via
    `sqlite3_unlock_notify()`, then spins (with short sleeps) until the
    callback sets the fired flag to True.

    If `sqlite3_unlock_notify()` returns an error (e.g. SQLITE_LOCKED
    indicating potential deadlock), that error code is returned immediately
    and the caller should roll back the current transaction.

    Args:
        db: The blocked database connection handle.

    Returns:
        SQLITE_OK after the notification fires, or an error code if
        registering the notification fails.
    """
    var fired = False
    var notify_arg = UnsafePointer(to=fired).bitcast[NoneType]()

    var rc = sqlite_ffi()[].unlock_notify(
        db,
        _unlock_notify_cb,
        notify_arg,
    )
    debug_assert(
        rc == SQLITE_LOCKED
        or rc == SQLITE_LOCKED_SHAREDCACHE
        or rc == SQLITE_OK,
        "unexpected result from sqlite3_unlock_notify",
    )
    if rc == SQLite3Result.OK:
        var waiter = SpinWaiter()
        while not fired:
            waiter.wait()

    return rc
