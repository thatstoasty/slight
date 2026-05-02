"""Run-Time Limits.

This module defines the `Limit` struct representing run-time limit categories
for SQLite database connections, for use with `Connection.limit()` and
`Connection.set_limit()`.

See the official documentation for more information:
- https://www.sqlite.org/c3ref/c_limit_attached.html
- https://www.sqlite.org/limits.html
"""

from std.ffi import c_int


@fieldwise_init
struct Limit(Copyable, ImplicitlyCopyable, Movable, Writable, TrivialRegisterPassable):
    """Run-time limit categories for `Connection.limit()` and
    `Connection.set_limit()`.

    Each variant corresponds to a `SQLITE_LIMIT_*` constant from the SQLite C API.
    """

    var value: Int32
    """The integer value of the limit category."""

    comptime LENGTH = Self(0)
    """The maximum size of any string or BLOB or table row, in bytes."""

    comptime SQL_LENGTH = Self(1)
    """The maximum length of an SQL statement, in bytes."""

    comptime COLUMN = Self(2)
    """The maximum number of columns in a table definition or in the result set
    of a SELECT or the maximum number of columns in an index or in an
    ORDER BY or GROUP BY clause."""

    comptime EXPR_DEPTH = Self(3)
    """The maximum depth of the parse tree on any expression."""

    comptime COMPOUND_SELECT = Self(4)
    """The maximum number of terms in a compound SELECT statement."""

    comptime VDBE_OP = Self(5)
    """The maximum number of instructions in a virtual machine program used to
    implement an SQL statement."""

    comptime FUNCTION_ARG = Self(6)
    """The maximum number of arguments on a function."""

    comptime ATTACHED = Self(7)
    """The maximum number of attached databases."""

    comptime LIKE_PATTERN_LENGTH = Self(8)
    """The maximum length of the pattern argument to the LIKE or GLOB
    operators."""

    comptime VARIABLE_NUMBER = Self(9)
    """The maximum index number of any parameter in an SQL statement."""

    comptime TRIGGER_DEPTH = Self(10)
    """The maximum depth of recursion for triggers."""

    comptime WORKER_THREADS = Self(11)
    """The maximum number of auxiliary worker threads that a single prepared
    statement may start."""

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        if self.value == Self.LENGTH.value:
            writer.write("SQLITE_LIMIT_LENGTH")
        elif self.value == Self.SQL_LENGTH.value:
            writer.write("SQLITE_LIMIT_SQL_LENGTH")
        elif self.value == Self.COLUMN.value:
            writer.write("SQLITE_LIMIT_COLUMN")
        elif self.value == Self.EXPR_DEPTH.value:
            writer.write("SQLITE_LIMIT_EXPR_DEPTH")
        elif self.value == Self.COMPOUND_SELECT.value:
            writer.write("SQLITE_LIMIT_COMPOUND_SELECT")
        elif self.value == Self.VDBE_OP.value:
            writer.write("SQLITE_LIMIT_VDBE_OP")
        elif self.value == Self.FUNCTION_ARG.value:
            writer.write("SQLITE_LIMIT_FUNCTION_ARG")
        elif self.value == Self.ATTACHED.value:
            writer.write("SQLITE_LIMIT_ATTACHED")
        elif self.value == Self.LIKE_PATTERN_LENGTH.value:
            writer.write("SQLITE_LIMIT_LIKE_PATTERN_LENGTH")
        elif self.value == Self.VARIABLE_NUMBER.value:
            writer.write("SQLITE_LIMIT_VARIABLE_NUMBER")
        elif self.value == Self.TRIGGER_DEPTH.value:
            writer.write("SQLITE_LIMIT_TRIGGER_DEPTH")
        elif self.value == Self.WORKER_THREADS.value:
            writer.write("SQLITE_LIMIT_WORKER_THREADS")
        else:
            writer.write(t"SQLITE_LIMIT_UNKNOWN({self.value})")
