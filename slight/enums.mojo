from slight.c.types import ResultDestructorFn

@fieldwise_init
struct DataType(Equatable, Movable, TrivialRegisterPassable):
    """Fundamental Datatypes.

    Every value in SQLite has one of five fundamental datatypes:
    * 64-bit signed integer
    * 64-bit IEEE floating point number
    * string
    * BLOB
    * NULL

    These constants are codes for each of those types.
    """

    var value: Int32
    """Internal enum value."""
    comptime INTEGER = Self(1)
    """`SQLITE_INTEGER`: 64-bit signed integer."""
    comptime FLOAT = Self(2)
    """`SQLITE_FLOAT`: 64-bit IEEE floating point number."""
    comptime TEXT = Self(3)
    """`SQLITE_TEXT`: String."""
    comptime BLOB = Self(4)
    """`SQLITE_BLOB`: BLOB."""
    comptime NULL = Self(5)
    """`SQLITE_NULL`: NULL."""

    def __eq__(self, other: Self) -> Bool:
        """Checks if this value is equal to `other`.

        Args:
            other: The other `DataType` to compare against.

        Returns:
            True if both `DataType` instances have the same value, False otherwise.
        """
        return self.value == other.value

    def __eq__(self, other: Int32) -> Bool:
        """Checks if this value is equal to a raw integer value.

        Args:
            other: The raw integer value to compare against.

        Returns:
            True if the `DataType`'s value is equal to the raw integer value, False otherwise.
        """
        return self.value == other


@fieldwise_init
struct TextEncoding(Movable, TrivialRegisterPassable):
    """Text Encodings.

    These constant define integer codes that represent the various
    text encodings supported by SQLite.
    """

    var value: UInt8
    """Internal enum value."""
    comptime UTF8 = Self(1)
    """`SQLITE_UTF8`: UTF-8 encoding."""

@fieldwise_init
struct DestructorHint(Movable, TrivialRegisterPassable):
    """If the destructor argument is `SQLITE_STATIC`, it means that the content pointer is constant
    and will never change. It does not need to be destroyed. The
    `SQLITE_TRANSIENT` value means that the content will likely change in
    the near future and that SQLite should make its own private copy of
    the content before returning.

    To use these as destructors for libsqlite3, first create a pointer to the value.
    Then bitcast it to `ResultDestructorFn`. Then when calling `sqlite3_bind_text` or
    `sqlite3_result_blob`, pass the dereferenced pointer as the destructor argument."""

    var value: Int
    """Internal enum value."""
    comptime STATIC = Self(0)
    """`SQLITE_STATIC`: The content pointer is constant and will never change."""
    comptime TRANSIENT = Self(-1)
    """`SQLITE_TRANSIENT`: The content will likely change in the near future and SQLite should make its own private copy of the content before returning."""

    # Why do I have to do this cursed conversion?
    @staticmethod
    def static_destructor() -> ResultDestructorFn:
        """Returns a function pointer representing the `SQLITE_STATIC` destructor.

        Returns:
            A function pointer representing the `SQLITE_STATIC` destructor.
        """
        return UnsafePointer(to=Self.STATIC.value).bitcast[ResultDestructorFn]()[]

    @staticmethod
    def transient_destructor() -> ResultDestructorFn:
        """Returns a function pointer representing the `SQLITE_TRANSIENT` destructor.

        Returns:
            A function pointer representing the `SQLITE_TRANSIENT` destructor.
        """
        return UnsafePointer(to=Self.TRANSIENT.value).bitcast[ResultDestructorFn]()[]
