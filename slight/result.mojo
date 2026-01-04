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


@register_passable("trivial")
struct SQLite3Result(Equatable, ImplicitlyCopyable, Intable, Writable, Stringable, Representable):
    var value: Int32
    comptime OK = Self(SQLITE_OK)
    comptime ERROR = Self(SQLITE_ERROR)
    comptime INTERNAL = Self(SQLITE_INTERNAL)
    comptime PERM = Self(SQLITE_PERM)
    comptime ABORT = Self(SQLITE_ABORT)
    comptime BUSY = Self(SQLITE_BUSY)
    comptime LOCKED = Self(SQLITE_LOCKED)
    comptime NO_MEM = Self(SQLITE_NOMEM)
    comptime READ_ONLY = Self(SQLITE_READONLY)
    comptime INTERRUPT = Self(SQLITE_INTERRUPT)
    comptime IO_ERROR = Self(SQLITE_IOERR)
    comptime CORRUPT = Self(SQLITE_CORRUPT)
    comptime NOT_FOUND = Self(SQLITE_NOTFOUND)
    comptime FULL = Self(SQLITE_FULL)
    comptime CANT_OPEN = Self(SQLITE_CANTOPEN)
    comptime PROTOCOL = Self(SQLITE_PROTOCOL)
    comptime EMPTY = Self(SQLITE_EMPTY)
    comptime SCHEMA = Self(SQLITE_SCHEMA)
    comptime TOO_BIG = Self(SQLITE_TOOBIG)
    comptime CONSTRAINT = Self(SQLITE_CONSTRAINT)
    comptime MISMATCH = Self(SQLITE_MISMATCH)
    comptime MISUSE = Self(SQLITE_MISUSE)
    comptime NOLFS = Self(SQLITE_NOLFS)
    comptime AUTH = Self(SQLITE_AUTH)
    comptime FORMAT = Self(SQLITE_FORMAT)
    comptime RANGE = Self(SQLITE_RANGE)
    comptime NOT_A_DB = Self(SQLITE_NOTADB)
    comptime NOTICE = Self(SQLITE_NOTICE)
    comptime WARNING = Self(SQLITE_WARNING)
    comptime ROW = Self(SQLITE_ROW)
    comptime DONE = Self(SQLITE_DONE)

    @implicit
    fn __init__(out self, value: Int32):
        self.value = value

    fn __int__(self) -> Int:
        return Int(self.value)

    fn __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    fn __eq__(self, other: Int32) -> Bool:
        return self.value == other
    
    fn __ne__(self, other: Int32) -> Bool:
        return self.value != other

    fn write_to[W: Writer](self, mut writer: W):
        writer.write(self.value)
    
    fn __repr__(self) -> String:
        return String("SQLite3Result(", self.value, ")")
    
    fn __str__(self) -> String:
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
