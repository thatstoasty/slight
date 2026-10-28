"""SQLite Result wrapper."""
from slight.c.types import (
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


struct SQLite3Result(Equatable, Intable, TrivialRegisterPassable, Writable):
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

    # Extended result codes. SQLite API calls return primary codes, but `Connection.extended_error_code()`
    # reports the extended code of the connection's most recent error. Generated from sqlite3.h.
    comptime ERROR_MISSING_COLLSEQ = Self(257)
    """`SQLITE_ERROR_MISSING_COLLSEQ` (257)."""
    comptime ERROR_RETRY = Self(513)
    """`SQLITE_ERROR_RETRY` (513)."""
    comptime ERROR_SNAPSHOT = Self(769)
    """`SQLITE_ERROR_SNAPSHOT` (769)."""
    comptime ERROR_RESERVESIZE = Self(1025)
    """`SQLITE_ERROR_RESERVESIZE` (1025)."""
    comptime ERROR_KEY = Self(1281)
    """`SQLITE_ERROR_KEY` (1281)."""
    comptime ERROR_UNABLE = Self(1537)
    """`SQLITE_ERROR_UNABLE` (1537)."""
    comptime IOERR_READ = Self(266)
    """`SQLITE_IOERR_READ` (266)."""
    comptime IOERR_SHORT_READ = Self(522)
    """`SQLITE_IOERR_SHORT_READ` (522)."""
    comptime IOERR_WRITE = Self(778)
    """`SQLITE_IOERR_WRITE` (778)."""
    comptime IOERR_FSYNC = Self(1034)
    """`SQLITE_IOERR_FSYNC` (1034)."""
    comptime IOERR_DIR_FSYNC = Self(1290)
    """`SQLITE_IOERR_DIR_FSYNC` (1290)."""
    comptime IOERR_TRUNCATE = Self(1546)
    """`SQLITE_IOERR_TRUNCATE` (1546)."""
    comptime IOERR_FSTAT = Self(1802)
    """`SQLITE_IOERR_FSTAT` (1802)."""
    comptime IOERR_UNLOCK = Self(2058)
    """`SQLITE_IOERR_UNLOCK` (2058)."""
    comptime IOERR_RDLOCK = Self(2314)
    """`SQLITE_IOERR_RDLOCK` (2314)."""
    comptime IOERR_DELETE = Self(2570)
    """`SQLITE_IOERR_DELETE` (2570)."""
    comptime IOERR_BLOCKED = Self(2826)
    """`SQLITE_IOERR_BLOCKED` (2826)."""
    comptime IOERR_NOMEM = Self(3082)
    """`SQLITE_IOERR_NOMEM` (3082)."""
    comptime IOERR_ACCESS = Self(3338)
    """`SQLITE_IOERR_ACCESS` (3338)."""
    comptime IOERR_CHECKRESERVEDLOCK = Self(3594)
    """`SQLITE_IOERR_CHECKRESERVEDLOCK` (3594)."""
    comptime IOERR_LOCK = Self(3850)
    """`SQLITE_IOERR_LOCK` (3850)."""
    comptime IOERR_CLOSE = Self(4106)
    """`SQLITE_IOERR_CLOSE` (4106)."""
    comptime IOERR_DIR_CLOSE = Self(4362)
    """`SQLITE_IOERR_DIR_CLOSE` (4362)."""
    comptime IOERR_SHMOPEN = Self(4618)
    """`SQLITE_IOERR_SHMOPEN` (4618)."""
    comptime IOERR_SHMSIZE = Self(4874)
    """`SQLITE_IOERR_SHMSIZE` (4874)."""
    comptime IOERR_SHMLOCK = Self(5130)
    """`SQLITE_IOERR_SHMLOCK` (5130)."""
    comptime IOERR_SHMMAP = Self(5386)
    """`SQLITE_IOERR_SHMMAP` (5386)."""
    comptime IOERR_SEEK = Self(5642)
    """`SQLITE_IOERR_SEEK` (5642)."""
    comptime IOERR_DELETE_NOENT = Self(5898)
    """`SQLITE_IOERR_DELETE_NOENT` (5898)."""
    comptime IOERR_MMAP = Self(6154)
    """`SQLITE_IOERR_MMAP` (6154)."""
    comptime IOERR_GETTEMPPATH = Self(6410)
    """`SQLITE_IOERR_GETTEMPPATH` (6410)."""
    comptime IOERR_CONVPATH = Self(6666)
    """`SQLITE_IOERR_CONVPATH` (6666)."""
    comptime IOERR_VNODE = Self(6922)
    """`SQLITE_IOERR_VNODE` (6922)."""
    comptime IOERR_AUTH = Self(7178)
    """`SQLITE_IOERR_AUTH` (7178)."""
    comptime IOERR_BEGIN_ATOMIC = Self(7434)
    """`SQLITE_IOERR_BEGIN_ATOMIC` (7434)."""
    comptime IOERR_COMMIT_ATOMIC = Self(7690)
    """`SQLITE_IOERR_COMMIT_ATOMIC` (7690)."""
    comptime IOERR_ROLLBACK_ATOMIC = Self(7946)
    """`SQLITE_IOERR_ROLLBACK_ATOMIC` (7946)."""
    comptime IOERR_DATA = Self(8202)
    """`SQLITE_IOERR_DATA` (8202)."""
    comptime IOERR_CORRUPTFS = Self(8458)
    """`SQLITE_IOERR_CORRUPTFS` (8458)."""
    comptime IOERR_IN_PAGE = Self(8714)
    """`SQLITE_IOERR_IN_PAGE` (8714)."""
    comptime IOERR_BADKEY = Self(8970)
    """`SQLITE_IOERR_BADKEY` (8970)."""
    comptime IOERR_CODEC = Self(9226)
    """`SQLITE_IOERR_CODEC` (9226)."""
    comptime LOCKED_VTAB = Self(518)
    """`SQLITE_LOCKED_VTAB` (518)."""
    comptime BUSY_RECOVERY = Self(261)
    """`SQLITE_BUSY_RECOVERY` (261)."""
    comptime BUSY_SNAPSHOT = Self(517)
    """`SQLITE_BUSY_SNAPSHOT` (517)."""
    comptime BUSY_TIMEOUT = Self(773)
    """`SQLITE_BUSY_TIMEOUT` (773)."""
    comptime CANTOPEN_NOTEMPDIR = Self(270)
    """`SQLITE_CANTOPEN_NOTEMPDIR` (270)."""
    comptime CANTOPEN_ISDIR = Self(526)
    """`SQLITE_CANTOPEN_ISDIR` (526)."""
    comptime CANTOPEN_FULLPATH = Self(782)
    """`SQLITE_CANTOPEN_FULLPATH` (782)."""
    comptime CANTOPEN_CONVPATH = Self(1038)
    """`SQLITE_CANTOPEN_CONVPATH` (1038)."""
    comptime CANTOPEN_DIRTYWAL = Self(1294)
    """`SQLITE_CANTOPEN_DIRTYWAL` (1294)."""
    comptime CANTOPEN_SYMLINK = Self(1550)
    """`SQLITE_CANTOPEN_SYMLINK` (1550)."""
    comptime CORRUPT_VTAB = Self(267)
    """`SQLITE_CORRUPT_VTAB` (267)."""
    comptime CORRUPT_SEQUENCE = Self(523)
    """`SQLITE_CORRUPT_SEQUENCE` (523)."""
    comptime CORRUPT_INDEX = Self(779)
    """`SQLITE_CORRUPT_INDEX` (779)."""
    comptime READONLY_RECOVERY = Self(264)
    """`SQLITE_READONLY_RECOVERY` (264)."""
    comptime READONLY_CANTLOCK = Self(520)
    """`SQLITE_READONLY_CANTLOCK` (520)."""
    comptime READONLY_ROLLBACK = Self(776)
    """`SQLITE_READONLY_ROLLBACK` (776)."""
    comptime READONLY_DBMOVED = Self(1032)
    """`SQLITE_READONLY_DBMOVED` (1032)."""
    comptime READONLY_CANTINIT = Self(1288)
    """`SQLITE_READONLY_CANTINIT` (1288)."""
    comptime READONLY_DIRECTORY = Self(1544)
    """`SQLITE_READONLY_DIRECTORY` (1544)."""
    comptime ABORT_ROLLBACK = Self(516)
    """`SQLITE_ABORT_ROLLBACK` (516)."""
    comptime CONSTRAINT_CHECK = Self(275)
    """`SQLITE_CONSTRAINT_CHECK` (275)."""
    comptime CONSTRAINT_COMMITHOOK = Self(531)
    """`SQLITE_CONSTRAINT_COMMITHOOK` (531)."""
    comptime CONSTRAINT_FOREIGNKEY = Self(787)
    """`SQLITE_CONSTRAINT_FOREIGNKEY` (787)."""
    comptime CONSTRAINT_FUNCTION = Self(1043)
    """`SQLITE_CONSTRAINT_FUNCTION` (1043)."""
    comptime CONSTRAINT_NOTNULL = Self(1299)
    """`SQLITE_CONSTRAINT_NOTNULL` (1299)."""
    comptime CONSTRAINT_PRIMARYKEY = Self(1555)
    """`SQLITE_CONSTRAINT_PRIMARYKEY` (1555)."""
    comptime CONSTRAINT_TRIGGER = Self(1811)
    """`SQLITE_CONSTRAINT_TRIGGER` (1811)."""
    comptime CONSTRAINT_UNIQUE = Self(2067)
    """`SQLITE_CONSTRAINT_UNIQUE` (2067)."""
    comptime CONSTRAINT_VTAB = Self(2323)
    """`SQLITE_CONSTRAINT_VTAB` (2323)."""
    comptime CONSTRAINT_ROWID = Self(2579)
    """`SQLITE_CONSTRAINT_ROWID` (2579)."""
    comptime CONSTRAINT_PINNED = Self(2835)
    """`SQLITE_CONSTRAINT_PINNED` (2835)."""
    comptime CONSTRAINT_DATATYPE = Self(3091)
    """`SQLITE_CONSTRAINT_DATATYPE` (3091)."""
    comptime NOTICE_RECOVER_WAL = Self(283)
    """`SQLITE_NOTICE_RECOVER_WAL` (283)."""
    comptime NOTICE_RECOVER_ROLLBACK = Self(539)
    """`SQLITE_NOTICE_RECOVER_ROLLBACK` (539)."""
    comptime NOTICE_RBU = Self(795)
    """`SQLITE_NOTICE_RBU` (795)."""
    comptime WARNING_AUTOINDEX = Self(284)
    """`SQLITE_WARNING_AUTOINDEX` (284)."""
    comptime AUTH_USER = Self(279)
    """`SQLITE_AUTH_USER` (279)."""
    comptime OK_LOAD_PERMANENTLY = Self(256)
    """`SQLITE_OK_LOAD_PERMANENTLY` (256)."""
    comptime OK_SYMLINK = Self(512)
    """`SQLITE_OK_SYMLINK` (512)."""

    @implicit
    def __init__(out self, value: Int32):
        """Initializes a SQLite3Result with the given result code value.

        Args:
            value: The SQLite result code value to wrap.
        """
        self.value = value

    def __int__(self) -> Int:
        """Converts the SQLite3Result to its underlying integer value.

        Returns:
            The integer value of the SQLite result code.
        """
        return Int(self.value)

    def __eq__(self, other: Int32) -> Bool:
        """Checks if this SQLite3Result is equal to a raw integer result code.

        Args:
            other: The raw integer result code to compare against.

        Returns:
            True if the SQLite3Result's value is equal to the raw integer result code, False otherwise.
        """
        return self.value == other

    def __ne__(self, other: Int32) -> Bool:
        """Checks if this SQLite3Result is not equal to a raw integer result code.

        Args:
            other: The raw integer result code to compare against.

        Returns:
            True if the SQLite3Result's value is not equal to the raw integer result code, False otherwise.
        """
        return self.value != other

    def name(self) -> StaticString:
        """Returns the SQLite name of this result code, e.g. `SQLITE_CONSTRAINT_UNIQUE`.

        Covers every primary and extended result code in `sqlite3.h`.

        Returns:
            The code's name, or `SQLITE_UNKNOWN` for a value SQLite does not define.
        """
        if self.value == 0:
            return "SQLITE_OK"
        elif self.value == 1:
            return "SQLITE_ERROR"
        elif self.value == 2:
            return "SQLITE_INTERNAL"
        elif self.value == 3:
            return "SQLITE_PERM"
        elif self.value == 4:
            return "SQLITE_ABORT"
        elif self.value == 5:
            return "SQLITE_BUSY"
        elif self.value == 6:
            return "SQLITE_LOCKED"
        elif self.value == 7:
            return "SQLITE_NOMEM"
        elif self.value == 8:
            return "SQLITE_READONLY"
        elif self.value == 9:
            return "SQLITE_INTERRUPT"
        elif self.value == 10:
            return "SQLITE_IOERR"
        elif self.value == 11:
            return "SQLITE_CORRUPT"
        elif self.value == 12:
            return "SQLITE_NOTFOUND"
        elif self.value == 13:
            return "SQLITE_FULL"
        elif self.value == 14:
            return "SQLITE_CANTOPEN"
        elif self.value == 15:
            return "SQLITE_PROTOCOL"
        elif self.value == 16:
            return "SQLITE_EMPTY"
        elif self.value == 17:
            return "SQLITE_SCHEMA"
        elif self.value == 18:
            return "SQLITE_TOOBIG"
        elif self.value == 19:
            return "SQLITE_CONSTRAINT"
        elif self.value == 20:
            return "SQLITE_MISMATCH"
        elif self.value == 21:
            return "SQLITE_MISUSE"
        elif self.value == 22:
            return "SQLITE_NOLFS"
        elif self.value == 23:
            return "SQLITE_AUTH"
        elif self.value == 24:
            return "SQLITE_FORMAT"
        elif self.value == 25:
            return "SQLITE_RANGE"
        elif self.value == 26:
            return "SQLITE_NOTADB"
        elif self.value == 27:
            return "SQLITE_NOTICE"
        elif self.value == 28:
            return "SQLITE_WARNING"
        elif self.value == 100:
            return "SQLITE_ROW"
        elif self.value == 101:
            return "SQLITE_DONE"
        elif self.value == 257:
            return "SQLITE_ERROR_MISSING_COLLSEQ"
        elif self.value == 513:
            return "SQLITE_ERROR_RETRY"
        elif self.value == 769:
            return "SQLITE_ERROR_SNAPSHOT"
        elif self.value == 1025:
            return "SQLITE_ERROR_RESERVESIZE"
        elif self.value == 1281:
            return "SQLITE_ERROR_KEY"
        elif self.value == 1537:
            return "SQLITE_ERROR_UNABLE"
        elif self.value == 266:
            return "SQLITE_IOERR_READ"
        elif self.value == 522:
            return "SQLITE_IOERR_SHORT_READ"
        elif self.value == 778:
            return "SQLITE_IOERR_WRITE"
        elif self.value == 1034:
            return "SQLITE_IOERR_FSYNC"
        elif self.value == 1290:
            return "SQLITE_IOERR_DIR_FSYNC"
        elif self.value == 1546:
            return "SQLITE_IOERR_TRUNCATE"
        elif self.value == 1802:
            return "SQLITE_IOERR_FSTAT"
        elif self.value == 2058:
            return "SQLITE_IOERR_UNLOCK"
        elif self.value == 2314:
            return "SQLITE_IOERR_RDLOCK"
        elif self.value == 2570:
            return "SQLITE_IOERR_DELETE"
        elif self.value == 2826:
            return "SQLITE_IOERR_BLOCKED"
        elif self.value == 3082:
            return "SQLITE_IOERR_NOMEM"
        elif self.value == 3338:
            return "SQLITE_IOERR_ACCESS"
        elif self.value == 3594:
            return "SQLITE_IOERR_CHECKRESERVEDLOCK"
        elif self.value == 3850:
            return "SQLITE_IOERR_LOCK"
        elif self.value == 4106:
            return "SQLITE_IOERR_CLOSE"
        elif self.value == 4362:
            return "SQLITE_IOERR_DIR_CLOSE"
        elif self.value == 4618:
            return "SQLITE_IOERR_SHMOPEN"
        elif self.value == 4874:
            return "SQLITE_IOERR_SHMSIZE"
        elif self.value == 5130:
            return "SQLITE_IOERR_SHMLOCK"
        elif self.value == 5386:
            return "SQLITE_IOERR_SHMMAP"
        elif self.value == 5642:
            return "SQLITE_IOERR_SEEK"
        elif self.value == 5898:
            return "SQLITE_IOERR_DELETE_NOENT"
        elif self.value == 6154:
            return "SQLITE_IOERR_MMAP"
        elif self.value == 6410:
            return "SQLITE_IOERR_GETTEMPPATH"
        elif self.value == 6666:
            return "SQLITE_IOERR_CONVPATH"
        elif self.value == 6922:
            return "SQLITE_IOERR_VNODE"
        elif self.value == 7178:
            return "SQLITE_IOERR_AUTH"
        elif self.value == 7434:
            return "SQLITE_IOERR_BEGIN_ATOMIC"
        elif self.value == 7690:
            return "SQLITE_IOERR_COMMIT_ATOMIC"
        elif self.value == 7946:
            return "SQLITE_IOERR_ROLLBACK_ATOMIC"
        elif self.value == 8202:
            return "SQLITE_IOERR_DATA"
        elif self.value == 8458:
            return "SQLITE_IOERR_CORRUPTFS"
        elif self.value == 8714:
            return "SQLITE_IOERR_IN_PAGE"
        elif self.value == 8970:
            return "SQLITE_IOERR_BADKEY"
        elif self.value == 9226:
            return "SQLITE_IOERR_CODEC"
        elif self.value == 262:
            return "SQLITE_LOCKED_SHAREDCACHE"
        elif self.value == 518:
            return "SQLITE_LOCKED_VTAB"
        elif self.value == 261:
            return "SQLITE_BUSY_RECOVERY"
        elif self.value == 517:
            return "SQLITE_BUSY_SNAPSHOT"
        elif self.value == 773:
            return "SQLITE_BUSY_TIMEOUT"
        elif self.value == 270:
            return "SQLITE_CANTOPEN_NOTEMPDIR"
        elif self.value == 526:
            return "SQLITE_CANTOPEN_ISDIR"
        elif self.value == 782:
            return "SQLITE_CANTOPEN_FULLPATH"
        elif self.value == 1038:
            return "SQLITE_CANTOPEN_CONVPATH"
        elif self.value == 1294:
            return "SQLITE_CANTOPEN_DIRTYWAL"
        elif self.value == 1550:
            return "SQLITE_CANTOPEN_SYMLINK"
        elif self.value == 267:
            return "SQLITE_CORRUPT_VTAB"
        elif self.value == 523:
            return "SQLITE_CORRUPT_SEQUENCE"
        elif self.value == 779:
            return "SQLITE_CORRUPT_INDEX"
        elif self.value == 264:
            return "SQLITE_READONLY_RECOVERY"
        elif self.value == 520:
            return "SQLITE_READONLY_CANTLOCK"
        elif self.value == 776:
            return "SQLITE_READONLY_ROLLBACK"
        elif self.value == 1032:
            return "SQLITE_READONLY_DBMOVED"
        elif self.value == 1288:
            return "SQLITE_READONLY_CANTINIT"
        elif self.value == 1544:
            return "SQLITE_READONLY_DIRECTORY"
        elif self.value == 516:
            return "SQLITE_ABORT_ROLLBACK"
        elif self.value == 275:
            return "SQLITE_CONSTRAINT_CHECK"
        elif self.value == 531:
            return "SQLITE_CONSTRAINT_COMMITHOOK"
        elif self.value == 787:
            return "SQLITE_CONSTRAINT_FOREIGNKEY"
        elif self.value == 1043:
            return "SQLITE_CONSTRAINT_FUNCTION"
        elif self.value == 1299:
            return "SQLITE_CONSTRAINT_NOTNULL"
        elif self.value == 1555:
            return "SQLITE_CONSTRAINT_PRIMARYKEY"
        elif self.value == 1811:
            return "SQLITE_CONSTRAINT_TRIGGER"
        elif self.value == 2067:
            return "SQLITE_CONSTRAINT_UNIQUE"
        elif self.value == 2323:
            return "SQLITE_CONSTRAINT_VTAB"
        elif self.value == 2579:
            return "SQLITE_CONSTRAINT_ROWID"
        elif self.value == 2835:
            return "SQLITE_CONSTRAINT_PINNED"
        elif self.value == 3091:
            return "SQLITE_CONSTRAINT_DATATYPE"
        elif self.value == 283:
            return "SQLITE_NOTICE_RECOVER_WAL"
        elif self.value == 539:
            return "SQLITE_NOTICE_RECOVER_ROLLBACK"
        elif self.value == 795:
            return "SQLITE_NOTICE_RBU"
        elif self.value == 284:
            return "SQLITE_WARNING_AUTOINDEX"
        elif self.value == 279:
            return "SQLITE_AUTH_USER"
        elif self.value == 256:
            return "SQLITE_OK_LOAD_PERMANENTLY"
        elif self.value == 512:
            return "SQLITE_OK_SYMLINK"
        return "SQLITE_UNKNOWN"

    def primary(self) -> Self:
        """Returns the primary result code, i.e. the low 8 bits of an extended result code.

        For example, `SQLITE_CONSTRAINT_UNIQUE` (2067) has the primary code `SQLITE_CONSTRAINT` (19).

        Returns:
            The primary result code.
        """
        return Self(self.value & 0xFF)

    def write_repr_to(self) -> String:
        """Returns a string representation of the SQLite3Result, including its integer value.

        Returns:
            A string representation of the SQLite3Result.
        """
        return String(t"SQLite3Result({self.value})")

    def write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable string representation of the SQLite3Result, including a description of the result code.

        Args:
            writer: The writer to write to.
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
        elif self.value == SQLITE_NOTADB:
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
