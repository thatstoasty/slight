from slight.c.raw_bindings import (
    SQLITE_ABORT,
    SQLITE_AUTH,
    SQLITE_BUSY,
    SQLITE_CANTOPEN,
    SQLITE_CONSTRAINT,
    SQLITE_CORRUPT,
    SQLITE_DONE,
    SQLITE_EMPTY,
    SQLITE_ERROR,
    SQLITE_FORMAT,
    SQLITE_FULL,
    SQLITE_INTERNAL,
    SQLITE_INTERRUPT,
    SQLITE_IOERR,
    SQLITE_LOCKED,
    SQLITE_LOCKED_SHAREDCACHE,
    SQLITE_MISMATCH,
    SQLITE_MISUSE,
    SQLITE_NOLFS,
    SQLITE_NOMEM,
    SQLITE_NOTADB,
    SQLITE_NOTFOUND,
    SQLITE_NOTICE,
    SQLITE_OK,
    SQLITE_PERM,
    SQLITE_PROTOCOL,
    SQLITE_RANGE,
    SQLITE_READONLY,
    SQLITE_ROW,
    SQLITE_SCHEMA,
    SQLITE_TOOBIG,
    SQLITE_WARNING,
)


struct SQLite3Result(Equatable, ImplicitlyCopyable, Intable, TrivialRegisterPassable, Writable):
    """A wrapper around SQLite result codes that provides more descriptive error handling and utilities."""

    var value: Int32
    """The underlying SQLite result code value."""
    comptime OK = Self(SQLITE_OK)
    """A successful result."""
    comptime ERROR = Self(SQLITE_ERROR)
    """A generic error."""
    comptime INTERNAL = Self(SQLITE_INTERNAL)
    """Internal logic error in SQLite."""
    comptime PERM = Self(SQLITE_PERM)
    """Access permission denied."""
    comptime ABORT = Self(SQLITE_ABORT)
    """Callback routine requested an abort."""
    comptime BUSY = Self(SQLITE_BUSY)
    """The database file is locked."""
    comptime LOCKED = Self(SQLITE_LOCKED)
    """A table in the database is locked."""
    comptime NO_MEM = Self(SQLITE_NOMEM)
    """A malloc() failed."""
    comptime READ_ONLY = Self(SQLITE_READONLY)
    """Attempt to write a readonly database."""
    comptime INTERRUPT = Self(SQLITE_INTERRUPT)
    """Operation terminated by sqlite3_interrupt()."""
    comptime IO_ERROR = Self(SQLITE_IOERR)
    """Some kind of disk I/O error occurred."""
    comptime CORRUPT = Self(SQLITE_CORRUPT)
    """The database disk image is malformed."""
    comptime NOT_FOUND = Self(SQLITE_NOTFOUND)
    """Unknown opcode in sqlite3_file_control()."""
    comptime FULL = Self(SQLITE_FULL)
    """Insertion failed because database is full."""
    comptime CANT_OPEN = Self(SQLITE_CANTOPEN)
    """Unable to open the database file."""
    comptime PROTOCOL = Self(SQLITE_PROTOCOL)
    """Database lock protocol error."""
    comptime EMPTY = Self(SQLITE_EMPTY)
    """Database is empty."""
    comptime SCHEMA = Self(SQLITE_SCHEMA)
    """The database schema changed."""
    comptime TOO_BIG = Self(SQLITE_TOOBIG)
    """String or BLOB exceeds size limit."""
    comptime CONSTRAINT = Self(SQLITE_CONSTRAINT)
    """A constraint violation occurred."""
    comptime MISMATCH = Self(SQLITE_MISMATCH)
    """Data type mismatch."""
    comptime MISUSE = Self(SQLITE_MISUSE)
    """Library used incorrectly."""
    comptime NOLFS = Self(SQLITE_NOLFS)
    """Large file support is disabled."""
    comptime AUTH = Self(SQLITE_AUTH)
    """Authorization denied."""
    comptime FORMAT = Self(SQLITE_FORMAT)
    """Not used."""
    comptime RANGE = Self(SQLITE_RANGE)
    """2nd parameter to sqlite3_bind out of range."""
    comptime NOT_A_DB = Self(SQLITE_NOTADB)
    """File opened that is not a database file."""
    comptime NOTICE = Self(SQLITE_NOTICE)
    """Notifications from sqlite3_log()."""
    comptime WARNING = Self(SQLITE_WARNING)
    """The function sqlite3_step() has another row ready."""
    comptime ROW = Self(SQLITE_ROW)
    """The function sqlite3_step() has finished executing."""
    comptime DONE = Self(SQLITE_DONE)
    """A result code indicating that the function sqlite3_step() has finished executing."""
    comptime LOCKED_SHAREDCACHE = Self(SQLITE_LOCKED_SHAREDCACHE)
    """A table in the database is locked (shared cache)."""

    @implicit
    fn __init__(out self, value: Int32):
        """Initializes a SQLite3Result with the given result code value.

        Args:
            value: The SQLite result code value to wrap.
        """
        self.value = value

    fn __int__(self) -> Int:
        """Converts the SQLite3Result to its underlying integer value.

        Returns:
            The integer value of the SQLite result code.
        """
        return Int(self.value)

    fn __eq__(self, other: Self) -> Bool:
        """Checks if this SQLite3Result is equal to another SQLite3Result.

        Args:
            other: The other SQLite3Result to compare against.

        Returns:
            True if both SQLite3Result instances have the same result code value, False otherwise.
        """
        return self.value == other.value

    fn __eq__(self, other: Int32) -> Bool:
        """Checks if this SQLite3Result is equal to a raw integer result code.

        Args:
            other: The raw integer result code to compare against.

        Returns:
            True if the SQLite3Result's value is equal to the raw integer result code, False otherwise.
        """
        return self.value == other

    fn __ne__(self, other: Int32) -> Bool:
        """Checks if this SQLite3Result is not equal to a raw integer result code.

        Args:
            other: The raw integer result code to compare against.

        Returns:
            True if the SQLite3Result's value is not equal to the raw integer result code, False otherwise.
        """
        return self.value != other

    fn write_repr_to(self) -> String:
        """Returns a string representation of the SQLite3Result, including its integer value.

        Returns:
            A string representation of the SQLite3Result.
        """
        return t"SQLite3Result({self.value})"

    fn write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable string representation of the SQLite3Result, including a description of the result code.
        """
        if self.value == SQLITE_OK:
            writer.write(t"[SQLITE_OK ({self.value})] Successful result")
        elif self.value == SQLITE_ERROR:
            writer.write(t"[SQLITE_ERROR ({self.value})] Generic error")
        elif self.value == SQLITE_INTERNAL:
            writer.write(t"[SQLITE_INTERNAL ({self.value})] Internal logic error in SQLite")
        elif self.value == SQLITE_PERM:
            writer.write(t"[SQLITE_PERM ({self.value})] Access permission denied")
        elif self.value == SQLITE_ABORT:
            writer.write(t"[SQLITE_ABORT ({self.value})] Callback routine requested an abort")
        elif self.value == SQLITE_BUSY:
            writer.write(t"[SQLITE_BUSY ({self.value})] The database file is locked")
        elif self.value == SQLITE_LOCKED:
            writer.write(t"[SQLITE_LOCKED ({self.value})] A table in the database is locked")
        elif self.value == SQLITE_NOMEM:
            writer.write(t"[SQLITE_NOMEM ({self.value})] A malloc() failed")
        elif self.value == SQLITE_READONLY:
            writer.write(t"[SQLITE_READONLY ({self.value})] Attempt to write a readonly database")
        elif self.value == SQLITE_INTERRUPT:
            writer.write(t"[SQLITE_INTERRUPT ({self.value})] Operation terminated by sqlite3_interrupt()")
        elif self.value == SQLITE_IOERR:
            writer.write(t"[SQLITE_IOERR ({self.value})] Some kind of disk I/O error occurred")
        elif self.value == SQLITE_CORRUPT:
            writer.write(t"[SQLITE_CORRUPT ({self.value})] The database disk image is malformed")
        elif self.value == SQLITE_NOTFOUND:
            writer.write(t"[SQLITE_NOTFOUND ({self.value})] Unknown opcode in sqlite3_file_control()")
        elif self.value == SQLITE_FULL:
            writer.write(t"[SQLITE_FULL ({self.value})] Insertion failed because database is full")
        elif self.value == SQLITE_CANTOPEN:
            writer.write(t"[SQLITE_CANTOPEN ({self.value})] Unable to open the database file")
        elif self.value == SQLITE_PROTOCOL:
            writer.write(t"[SQLITE_PROTOCOL ({self.value})] Database lock protocol error")
        elif self.value == SQLITE_EMPTY:
            writer.write(t"[SQLITE_EMPTY ({self.value})] Internal use only")
        elif self.value == SQLITE_SCHEMA:
            writer.write(t"[SQLITE_SCHEMA ({self.value})] The database schema changed")
        elif self.value == SQLITE_TOOBIG:
            writer.write(t"[SQLITE_TOOBIG ({self.value})] String or BLOB exceeds size limit")
        elif self.value == SQLITE_CONSTRAINT:
            writer.write(t"[SQLITE_CONSTRAINT ({self.value})] Abort due to constraint violation")
        elif self.value == SQLITE_MISMATCH:
            writer.write(t"[SQLITE_MISMATCH ({self.value})] Data type mismatch")
        elif self.value == SQLITE_MISUSE:
            writer.write(t"[SQLITE_MISUSE ({self.value})] Library used incorrectly")
        elif self.value == SQLITE_NOLFS:
            writer.write(t"[SQLITE_NOLFS ({self.value})] Uses OS features not supported on host")
        elif self.value == SQLITE_AUTH:
            writer.write(t"[SQLITE_AUTH ({self.value})] Authorization denied")
        elif self.value == SQLITE_FORMAT:
            writer.write(t"[SQLITE_FORMAT ({self.value})] Not used")
        elif self.value == SQLITE_RANGE:
            writer.write(t"[SQLITE_RANGE ({self.value})] 2nd parameter to sqlite3_bind out of range")
        elif self.value == SQLITE_NOTFOUND:
            writer.write(t"[SQLITE_NOTADB ({self.value})] File opened that is not a database file")
        elif self.value == SQLITE_NOTICE:
            writer.write(t"[SQLITE_NOTICE ({self.value})] Notifications from sqlite3_log()")
        elif self.value == SQLITE_WARNING:
            writer.write(t"[SQLITE_WARNING ({self.value})] Warnings from sqlite3_log()")
        elif self.value == SQLITE_ROW:
            writer.write(t"[SQLITE_ROW ({self.value})] sqlite3_step() has another row ready")
        elif self.value == SQLITE_DONE:
            writer.write(t"[SQLITE_DONE ({self.value})] sqlite3_step() has finished executing")
        elif self.value == SQLITE_LOCKED_SHAREDCACHE:
            writer.write(t"[SQLITE_LOCKED_SHAREDCACHE ({self.value})] A table in the database is locked (shared cache)")
        else:
            writer.write(t"UNKNOWN SQLITE RESULT CODE: {self.value}")
