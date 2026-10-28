"""Run-Time Limits.

This module defines the `Limit` enum representing run-time limit categories
for SQLite database connections, for use with `Connection.limit()` and
`Connection.set_limit()`.

See the official documentation for more information:
- https://www.sqlite.org/c3ref/c_limit_attached.html
- https://www.sqlite.org/limits.html
"""


__enum Limit(ImplicitlyCopyable, Writable):
    """Run-time limit categories for `Connection.limit()` and
    `Connection.set_limit()`.

    Each case corresponds to a `SQLITE_LIMIT_*` constant from the SQLite C API; see `code()`.
    """

    case length
    """The maximum size of any string or BLOB or table row, in bytes."""

    case sql_length
    """The maximum length of an SQL statement, in bytes."""

    case column
    """The maximum number of columns in a table definition or in the result set
    of a SELECT or the maximum number of columns in an index or in an
    ORDER BY or GROUP BY clause."""

    case expr_depth
    """The maximum depth of the parse tree on any expression."""

    case compound_select
    """The maximum number of terms in a compound SELECT statement."""

    case vdbe_op
    """The maximum number of instructions in a virtual machine program used to
    implement an SQL statement."""

    case function_arg
    """The maximum number of arguments on a function."""

    case attached
    """The maximum number of attached databases."""

    case like_pattern_length
    """The maximum length of the pattern argument to the LIKE or GLOB
    operators."""

    case variable_number
    """The maximum index number of any parameter in an SQL statement."""

    case trigger_depth
    """The maximum depth of recursion for triggers."""

    case worker_threads
    """The maximum number of auxiliary worker threads that a single prepared
    statement may start."""

    def code(self) -> Int32:
        """Returns the raw `SQLITE_LIMIT_*` code.

        Returns:
            The integer code SQLite uses for this limit category.
        """
        match self:
            case .length:
                return 0
            case .sql_length:
                return 1
            case .column:
                return 2
            case .expr_depth:
                return 3
            case .compound_select:
                return 4
            case .vdbe_op:
                return 5
            case .function_arg:
                return 6
            case .attached:
                return 7
            case .like_pattern_length:
                return 8
            case .variable_number:
                return 9
            case .trigger_depth:
                return 10
            case .worker_threads:
                return 11

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        match self:
            case .length:
                writer.write("SQLITE_LIMIT_LENGTH")
            case .sql_length:
                writer.write("SQLITE_LIMIT_SQL_LENGTH")
            case .column:
                writer.write("SQLITE_LIMIT_COLUMN")
            case .expr_depth:
                writer.write("SQLITE_LIMIT_EXPR_DEPTH")
            case .compound_select:
                writer.write("SQLITE_LIMIT_COMPOUND_SELECT")
            case .vdbe_op:
                writer.write("SQLITE_LIMIT_VDBE_OP")
            case .function_arg:
                writer.write("SQLITE_LIMIT_FUNCTION_ARG")
            case .attached:
                writer.write("SQLITE_LIMIT_ATTACHED")
            case .like_pattern_length:
                writer.write("SQLITE_LIMIT_LIKE_PATTERN_LENGTH")
            case .variable_number:
                writer.write("SQLITE_LIMIT_VARIABLE_NUMBER")
            case .trigger_depth:
                writer.write("SQLITE_LIMIT_TRIGGER_DEPTH")
            case .worker_threads:
                writer.write("SQLITE_LIMIT_WORKER_THREADS")
