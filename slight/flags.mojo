from slight.c.raw_bindings import (
    SQLITE_OPEN_READONLY,
    SQLITE_OPEN_READWRITE,
    SQLITE_OPEN_CREATE,
    SQLITE_OPEN_DELETEONCLOSE,
    SQLITE_OPEN_EXCLUSIVE,
    SQLITE_OPEN_AUTOPROXY,
    SQLITE_OPEN_URI,
    SQLITE_OPEN_MEMORY,
    SQLITE_OPEN_MAIN_DB,
    SQLITE_OPEN_TEMP_DB,
    SQLITE_OPEN_TRANSIENT_DB,
    SQLITE_OPEN_MAIN_JOURNAL,
    SQLITE_OPEN_TEMP_JOURNAL,
    SQLITE_OPEN_SUBJOURNAL,
    SQLITE_OPEN_SUPER_JOURNAL,
    SQLITE_OPEN_NOMUTEX,
    SQLITE_OPEN_FULLMUTEX,
    SQLITE_OPEN_SHAREDCACHE,
    SQLITE_OPEN_PRIVATECACHE,
    SQLITE_OPEN_WAL,
    SQLITE_OPEN_NOFOLLOW,
    SQLITE_OPEN_EXRESCODE,
)


@fieldwise_init
struct PrepFlag(Copyable, Movable, ImplicitlyCopyable):
    """Flags for preparing a SQLite statement."""

    var value: UInt32
    """The integer value of the flags."""
    comptime PREPARE_PERSISTENT = Self(0x01)
    """A hint to the query planner that the prepared statement will be retained for a long time and probably reused many times."""
    comptime PREPARE_NO_VTAB = Self(0x04)
    """Causes the SQL compiler to return an error (error code SQLITE_ERROR) if the statement uses any virtual tables."""
    comptime PREPARE_DONT_LOG = Self(0x10)
    """Prevents SQL compiler errors from being sent to the error log."""

    fn __or__(self, other: Self) -> Self:
        return Self(self.value | other.value)


@fieldwise_init
struct OpenFlag(Copyable, Movable, ImplicitlyCopyable):
    """Flags for opening a SQLite database connection.
    
    Defaults to READ_WRITE | CREATE | URI.
    """

    var value: Int32
    """The integer value of the flags."""

    comptime READ_ONLY = Self(SQLITE_OPEN_READONLY)
     """Open the database in read-only mode. The database must already exist."""
    comptime CREATE = Self(SQLITE_OPEN_CREATE)
    """Create the database file if it does not already exist."""
    comptime READ_WRITE = Self(SQLITE_OPEN_READWRITE)
    """Open the database for reading and writing. The database must already exist."""
    comptime URI = Self(SQLITE_OPEN_URI)
    """The filename is interpreted as a URI. This allows additional query parameters to be appended to the filename."""
    comptime MEMORY = Self(SQLITE_OPEN_MEMORY)
    """Open an in-memory database. This is a private, temporary database that is not saved
    to disk and is automatically deleted when the connection is closed."""
    comptime DELETE_ON_CLOSE = Self(SQLITE_OPEN_DELETEONCLOSE)
    """The database is deleted when the connection is closed."""
    comptime EXCLUSIVE = Self(SQLITE_OPEN_EXCLUSIVE)
    """The database is opened in exclusive mode. This means that no other connections can be made
    to the database while this connection is open."""
    comptime AUTOPROXY = Self(SQLITE_OPEN_AUTOPROXY)
    """The database connection will automatically use a proxy if one is available."""
    comptime MAIN_DB = Self(SQLITE_OPEN_MAIN_DB)
    """The database is the main database. This is the default."""
    comptime TEMP_DB = Self(SQLITE_OPEN_TEMP_DB)
    """The database is a temporary database."""
    comptime TRANSIENT_DB = Self(SQLITE_OPEN_TRANSIENT_DB)
    """The database is a transient database."""
    comptime MAIN_JOURNAL = Self(SQLITE_OPEN_MAIN_JOURNAL)
    """The database is the main journal."""
    comptime TEMP_JOURNAL = Self(SQLITE_OPEN_TEMP_JOURNAL)
    """The database is a temporary journal."""
    comptime SUBJOURNAL = Self(SQLITE_OPEN_SUBJOURNAL)
    """The database is a sub-journal."""
    comptime SUPER_JOURNAL = Self(SQLITE_OPEN_SUPER_JOURNAL)
    """The database is a super-journal."""
    comptime NO_MUTEX = Self(SQLITE_OPEN_NOMUTEX)
    """The database connection will not use mutexes. This is unsafe and should only be used
    if the application ensures that no two threads will ever use the same database connection at the same
    time."""
    comptime FULL_MUTEX = Self(SQLITE_OPEN_FULLMUTEX)
    """The database connection will use full mutexes. This is the default."""
    comptime SHARED_CACHE = Self(SQLITE_OPEN_SHAREDCACHE)
    """The database connection will use a shared cache."""
    comptime PRIVATE_CACHE = Self(SQLITE_OPEN_PRIVATECACHE)
    """The database connection will use a private cache."""
    comptime WAL = Self(SQLITE_OPEN_WAL)
    """The database connection will use Write-Ahead Logging (WAL) mode."""
    comptime NO_FOLLOW = Self(SQLITE_OPEN_NOFOLLOW)
    """The database connection will not follow symbolic links when opening the database file."""
    comptime EXRESCODE = Self(SQLITE_OPEN_EXRESCODE)
    """The extended result codes will be enabled for this database connection."""

    # Default flags
    fn __init__(out self):
        self.value = Self.READ_WRITE.value |
            Self.CREATE.value |
            Self.URI.value

    fn __or__(self, other: Self) -> Self:
        return Self(self.value | other.value)
