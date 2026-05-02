"""Tracing, profiling, and error logging.

This module provides trace event codes, statement status counters,
and a callback-based tracing API for monitoring SQL statement execution,
profiling performance, and logging errors.

The primary entry point is `Connection.trace()`, which registers a
callback for selected trace events. The deprecated `Connection.trace()`
and `Connection.profile()` are superseded by `trace`.

See:
- https://www.sqlite.org/c3ref/trace.html
- https://www.sqlite.org/c3ref/c_trace.html
- https://www.sqlite.org/c3ref/c_stmtstatus_counter.html
"""

from std.ffi import c_char, c_int
from slight.c.api import sqlite_ffi
from slight.c.raw_bindings import sqlite3_connection, sqlite3_stmt
from slight.c.types import MutExternalPointer


# ── Trace event codes (bitmask) ────────────────────────────────────────


@fieldwise_init
struct TraceEventCodes(
    ImplicitlyCopyable, Writable, TrivialRegisterPassable, Equatable,
):
    """Bitmask of trace event types for `Connection.trace()`.

    Multiple codes can be combined with `|` (bitwise OR).
    """

    var value: UInt32
    """The raw bitmask value."""

    comptime STMT = Self(0x01)
    """Fires when a prepared statement first begins running, and possibly at
    other times during execution (e.g. start of a trigger subprogram)."""

    comptime PROFILE = Self(0x02)
    """Fires when a statement finishes, providing elapsed wall-clock time."""

    comptime ROW = Self(0x04)
    """Fires whenever a prepared statement generates a single row of result."""

    comptime CLOSE = Self(0x08)
    """Fires when a database connection closes."""

    @staticmethod
    def all() -> Self:
        """Return a mask that enables all trace event types.

        Returns:
            A `TraceEventCodes` with STMT, PROFILE, ROW, and CLOSE enabled.
        """
        return Self(0x0F)

    @staticmethod
    def empty() -> Self:
        """Return an empty mask (no events enabled).

        Returns:
            A `TraceEventCodes` with no events enabled.
        """
        return Self(0)

    def __or__(self, other: Self) -> Self:
        """Combine two masks using bitwise OR.

        Args:
            other: The other mask to combine.

        Returns:
            A new mask with all events from both operands.
        """
        return Self(self.value | other.value)

    def __and__(self, other: Self) -> Self:
        """Intersect two masks using bitwise AND.

        Args:
            other: The other mask to intersect.

        Returns:
            A new mask with only events present in both operands.
        """
        return Self(self.value & other.value)

    def __contains__(self, code: Self) -> Bool:
        """Test whether `code` is fully contained in this mask.

        Args:
            code: The event code to test.

        Returns:
            True if every bit set in `code` is also set in `self`.
        """
        return (self.value & code.value) == code.value

    def __eq__(self, other: Self) -> Bool:
        """Test equality.

        Args:
            other: The other mask.

        Returns:
            True if both masks have the same value.
        """
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        var first = True
        if TraceEventCodes.STMT in self:
            writer.write("SQLITE_TRACE_STMT")
            first = False
        if TraceEventCodes.PROFILE in self:
            if not first:
                writer.write("|")
            writer.write("SQLITE_TRACE_PROFILE")
            first = False
        if TraceEventCodes.ROW in self:
            if not first:
                writer.write("|")
            writer.write("SQLITE_TRACE_ROW")
            first = False
        if TraceEventCodes.CLOSE in self:
            if not first:
                writer.write("|")
            writer.write("SQLITE_TRACE_CLOSE")
            first = False
        if first:
            writer.write("(none)")


# ── Statement status counters ──────────────────────────────────────────


@fieldwise_init
struct StatementStatus(
    ImplicitlyCopyable, Writable, TrivialRegisterPassable, Equatable
):
    """Status counters for prepared statements.

    Used with `TraceEvent.get_status()` and `Statement.get_status()`.
    """

    var value: Int32
    """The raw counter identifier."""

    comptime FULLSCAN_STEP = Self(1)
    """Number of full-scan steps taken by the virtual machine."""

    comptime SORT = Self(2)
    """Number of sort operations performed."""

    comptime AUTOINDEX = Self(3)
    """Number of automatic indexes created."""

    comptime VM_STEP = Self(4)
    """Number of virtual machine operations executed."""

    comptime REPREPARE = Self(5)
    """Number of times the prepared statement has been automatically
    re-prepared."""

    comptime RUN = Self(6)
    """Number of times the prepared statement has been run."""

    comptime FILTER_MISS = Self(7)
    """Number of Bloom filter misses."""

    comptime FILTER_HIT = Self(8)
    """Number of Bloom filter hits."""

    comptime MEMUSED = Self(99)
    """Approximate heap memory used by the prepared statement (bytes)."""

    def __eq__(self, other: Self) -> Bool:
        """Test equality.

        Args:
            other: The other status code.

        Returns:
            True if both have the same value.
        """
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        if self.value == Self.FULLSCAN_STEP.value:
            writer.write("SQLITE_STMTSTATUS_FULLSCAN_STEP")
        elif self.value == Self.SORT.value:
            writer.write("SQLITE_STMTSTATUS_SORT")
        elif self.value == Self.AUTOINDEX.value:
            writer.write("SQLITE_STMTSTATUS_AUTOINDEX")
        elif self.value == Self.VM_STEP.value:
            writer.write("SQLITE_STMTSTATUS_VM_STEP")
        elif self.value == Self.REPREPARE.value:
            writer.write("SQLITE_STMTSTATUS_REPREPARE")
        elif self.value == Self.RUN.value:
            writer.write("SQLITE_STMTSTATUS_RUN")
        elif self.value == Self.FILTER_MISS.value:
            writer.write("SQLITE_STMTSTATUS_FILTER_MISS")
        elif self.value == Self.FILTER_HIT.value:
            writer.write("SQLITE_STMTSTATUS_FILTER_HIT")
        elif self.value == Self.MEMUSED.value:
            writer.write("SQLITE_STMTSTATUS_MEMUSED")
        else:
            writer.write("SQLITE_STMTSTATUS_UNKNOWN(", self.value, ")")


# ── Trace event ────────────────────────────────────────────────────────


comptime TraceFn = def (TraceEvent) thin -> NoneType
"""User-provided trace callback type for `Connection.trace()`.

The callback receives a `TraceEvent` whose `event_code` indicates
which kind of event occurred. Use the accessor methods to extract
event-specific data.
"""


@fieldwise_init
struct TraceEvent:
    """A single trace event delivered to a `TraceFn` callback.

    The `event_code` field indicates which event fired. The `_p` and
    `_x` pointers carry event-specific data:

    | Event   | `_p`                   | `_x`                          |
    |---------|------------------------|-------------------------------|
    | STMT    | `sqlite3_stmt*`        | `const char*` (unexpanded SQL)|
    | PROFILE | `sqlite3_stmt*`        | `int64*` (elapsed ns)         |
    | ROW     | `sqlite3_stmt*`        | (unused)                      |
    | CLOSE   | `sqlite3*`             | (unused)                      |
    """

    var event_code: UInt32
    """The trace event type (one of TraceEventCodes values)."""
    var _p: MutExternalPointer[NoneType]
    """First opaque pointer from the C callback."""
    var _x: MutExternalPointer[NoneType]
    """Second opaque pointer from the C callback."""

    # ── Event-type predicates ──

    def is_stmt(self) -> Bool:
        """True when this is a STMT event.

        Returns:
            True if the event code is SQLITE_TRACE_STMT.
        """
        return self.event_code == TraceEventCodes.STMT.value

    def is_profile(self) -> Bool:
        """True when this is a PROFILE event.

        Returns:
            True if the event code is SQLITE_TRACE_PROFILE.
        """
        return self.event_code == TraceEventCodes.PROFILE.value

    def is_row(self) -> Bool:
        """True when this is a ROW event.

        Returns:
            True if the event code is SQLITE_TRACE_ROW.
        """
        return self.event_code == TraceEventCodes.ROW.value

    def is_close(self) -> Bool:
        """True when this is a CLOSE event.

        Returns:
            True if the event code is SQLITE_TRACE_CLOSE.
        """
        return self.event_code == TraceEventCodes.CLOSE.value

    # ── STMT / PROFILE / ROW accessors (statement-based events) ──

    def sql(self) -> String:
        """Return the unexpanded SQL text passed by the STMT event.

        Only valid for STMT events. For other events the result is undefined.

        Returns:
            The SQL text as a `String`.
        """
        var ptr = self._x.bitcast[c_char]().unsafe_mut_cast[False]()
        return String(
            StringSlice(unsafe_from_utf8_ptr=ptr)
        )

    def stmt_sql(self) -> String:
        """Return the SQL text from the statement handle.

        Valid for STMT, PROFILE, and ROW events.

        Returns:
            The statement's SQL text, or an empty string if unavailable.
        """
        var stmt = self._p.bitcast[sqlite3_stmt]()
        var sql_ptr = sqlite_ffi()[].sql(stmt)
        if not sql_ptr:
            return String("")
        return String(
            StringSlice(unsafe_from_utf8_ptr=sql_ptr)
        )

    def expanded_sql(self) -> Optional[String]:
        """Return expanded SQL (parameters substituted) from the statement.

        Valid for STMT, PROFILE, and ROW events.

        Returns:
            The expanded SQL as a `String`, or `None` on OOM or if unavailable.
        """
        var stmt = self._p.bitcast[sqlite3_stmt]()
        var s = sqlite_ffi()[].expanded_sql(stmt)
        if not s.ptr:
            return None
        return String(s.as_string_slice())

    def duration_ns(self) -> Int64:
        """Return elapsed wall-clock time in nanoseconds.

        Only valid for PROFILE events. For other events the result is
        undefined.

        Returns:
            Elapsed nanoseconds as `Int64`.
        """
        var ns_ptr = self._x.bitcast[Int64]()
        return ns_ptr[]

    def get_status(self, status: StatementStatus) -> Int32:
        """Read a statement status counter.

        Valid for STMT, PROFILE, and ROW events.

        Args:
            status: Which counter to read.

        Returns:
            The current value of the counter.
        """
        var stmt = self._p.bitcast[sqlite3_stmt]()
        return Int32(
            sqlite_ffi()[].stmt_status(stmt, c_int(status.value), c_int(0)).value
        )

    def is_autocommit(self) -> Bool:
        """Test whether the connection is in auto-commit mode.

        Only valid for CLOSE events.

        Returns:
            True if the connection is in auto-commit mode.
        """
        var db = self._p.bitcast[sqlite3_connection]()
        return sqlite_ffi()[].get_autocommit(db)

    def db_filename(self) -> Optional[String]:
        """Return the filename of the main database.

        Only valid for CLOSE events.

        Returns:
            The filename, or `None` if unavailable (e.g. in-memory).
        """
        var db = self._p.bitcast[sqlite3_connection]()
        var db_name = String("main")
        var ptr = sqlite_ffi()[].db_filename(db, db_name)
        if not ptr:
            return None
        var s = String(
            StringSlice(unsafe_from_utf8_ptr=ptr)
        )
        if s.byte_length() == 0:
            return None
        return s


# ── C-compatible trace callback ────────────────────────────────────────


def _trace_v2_callback(
    evt: UInt32,
    ctx: MutExternalPointer[NoneType],
    p: MutExternalPointer[NoneType],
    x: MutExternalPointer[NoneType],
) -> c_int:
    """C-compatible callback for `sqlite3_trace_v2`.

    Reconstructs the user's `TraceFn` from the `ctx` void pointer and
    invokes it with a `TraceEvent`.

    Args:
        evt: The trace event type bitmask.
        ctx: Void pointer whose address value IS the `TraceFn` pointer.
        p: First data pointer (meaning depends on event type).
        x: Second data pointer (meaning depends on event type).

    Returns:
        Always returns 0 (SQLITE_OK).
    """
    # Transmute: recover def pointer from the void pointer address value
    # (reverse of `f as *mut c_void` in Rust)
    var fn_as_int = Int(ctx)
    var callback = UnsafePointer(to=fn_as_int).bitcast[TraceFn]()[]
    callback(TraceEvent(evt, p, x))
    return c_int(0)


# ── Free function: log ─────────────────────────────────────────────────


def log(err_code: Int32, mut msg: String):
    """Write a message into the SQLite error log.

    The message is logged through the error logging callback established
    by `sqlite3_config(SQLITE_CONFIG_LOG, ...)`.

    Args:
        err_code: An SQLite error code to associate with the message.
        msg: The log message text.
    """
    sqlite_ffi()[].log(c_int(err_code), msg)
