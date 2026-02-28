from slight.c.raw_bindings import (
    SQLITE_OK,
    SQLITE_ERROR,
    SQLITE_ROW,
    SQLITE_INTERNAL,
    SQLITE_PERM,
    SQLITE_ABORT,
    SQLITE_BUSY,
    SQLITE_LOCKED,
    SQLITE_NOMEM,
    SQLITE_READONLY,
    SQLITE_INTERRUPT,
    SQLITE_IOERR,
    SQLITE_CORRUPT,
    SQLITE_NOTFOUND,
    SQLITE_FULL,
    SQLITE_CANTOPEN,
    SQLITE_PROTOCOL,
    SQLITE_EMPTY,
    SQLITE_SCHEMA,
    SQLITE_TOOBIG,
    SQLITE_CONSTRAINT,
    SQLITE_MISMATCH,
    SQLITE_MISUSE,
    SQLITE_NOLFS,
    SQLITE_AUTH,
    SQLITE_FORMAT,
    SQLITE_RANGE,
    SQLITE_NOTADB,
    SQLITE_NOTICE,
    SQLITE_WARNING,
    SQLITE_DONE,
)


struct SQLite3Result(Equatable, ImplicitlyCopyable, Intable, Writable, Stringable, Representable, TrivialRegisterPassable):
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

    fn write_to(self, mut writer: Some[Writer]):
        """Writes the integer value of the SQLite3Result to the provided writer.

        Args:
            writer: A mutable reference to a Writer where the integer value will be written.
        """
        writer.write(self.value)
    
    fn __repr__(self) -> String:
        """Returns a string representation of the SQLite3Result, including its integer value.

        Returns:
            A string representation of the SQLite3Result.
        """
        return String("SQLite3Result(", self.value, ")")
    
    fn __str__(self) -> String:
        """Returns a human-readable string representation of the SQLite3Result, including a description of the result code.

        Returns:
            A human-readable string representation of the SQLite3Result.
        """
        if self.value == SQLITE_OK:
            return "[SQLITE_OK] Successful result"
        elif self.value == SQLITE_ERROR:
            return "[SQLITE_ERROR] Generic error"
        elif self.value == SQLITE_INTERNAL:
            return "[SQLITE_INTERNAL] Internal logic error in SQLite"
        elif self.value == SQLITE_PERM:
            return "[SQLITE_PERM] Access permission denied"
        elif self.value == SQLITE_ABORT:
            return "[SQLITE_ABORT] Callback routine requested an abort"
        elif self.value == SQLITE_BUSY:
            return "[SQLITE_BUSY] The database file is locked"
        elif self.value == SQLITE_LOCKED:
            return "[SQLITE_LOCKED] A table in the database is locked"
        elif self.value == SQLITE_NOMEM:
            return "[SQLITE_NOMEM] A malloc() failed"
        elif self.value == SQLITE_READONLY:
            return "[SQLITE_READONLY] Attempt to write a readonly database"
        elif self.value == SQLITE_INTERRUPT:
            return "[SQLITE_INTERRUPT] Operation terminated by sqlite3_interrupt()"
        elif self.value == SQLITE_IOERR:
            return "[SQLITE_IOERR] Some kind of disk I/O error occurred"
        elif self.value == SQLITE_CORRUPT:
            return "[SQLITE_CORRUPT] The database disk image is malformed"
        elif self.value == SQLITE_NOTFOUND:
            return "[SQLITE_NOTFOUND] Unknown opcode in sqlite3_file_control()"
        elif self.value == SQLITE_FULL:
            return "[SQLITE_FULL] Insertion failed because database is full"
        elif self.value == SQLITE_CANTOPEN:
            return "[SQLITE_CANTOPEN] Unable to open the database file"
        elif self.value == SQLITE_PROTOCOL:
            return "[SQLITE_PROTOCOL] Database lock protocol error"
        elif self.value == SQLITE_EMPTY:
            return "[SQLITE_EMPTY] Internal use only"
        elif self.value == SQLITE_SCHEMA:
            return "[SQLITE_SCHEMA] The database schema changed"
        elif self.value == SQLITE_TOOBIG:
            return "[SQLITE_TOOBIG] String or BLOB exceeds size limit"
        elif self.value == SQLITE_CONSTRAINT:
            return "[SQLITE_CONSTRAINT] Abort due to constraint violation"
        elif self.value == SQLITE_MISMATCH:
            return "[SQLITE_MISMATCH] Data type mismatch"
        elif self.value == SQLITE_MISUSE:
            return "[SQLITE_MISUSE] Library used incorrectly"
        elif self.value == SQLITE_NOLFS:
            return "[SQLITE_NOLFS] Uses OS features not supported on host"
        elif self.value == SQLITE_AUTH:
            return "[SQLITE_AUTH] Authorization denied"
        elif self.value == SQLITE_FORMAT:
            return "[SQLITE_FORMAT] Not used"
        elif self.value == SQLITE_RANGE:
            return "[SQLITE_RANGE] 2nd parameter to sqlite3_bind out of range"
        elif self.value == SQLITE_NOTFOUND:
            return "[SQLITE_NOTADB] File opened that is not a database file"
        elif self.value == SQLITE_NOTICE:
            return "[SQLITE_NOTICE] Notifications from sqlite3_log()"
        elif self.value == SQLITE_WARNING:
            return "[SQLITE_WARNING] Warnings from sqlite3_log()"
        elif self.value == SQLITE_ROW:
            return "[SQLITE_ROW] sqlite3_step() has another row ready"
        elif self.value == SQLITE_DONE:
            return "[SQLITE_DONE] sqlite3_step() has finished executing"
        else:
            return String("UNKNOWN SQLITE RESULT CODE: ", self.value)
