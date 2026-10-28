"""Informational Enums."""
from std.os import abort
from slight.c.types import ResultDestructorFn


__enum DataType(Equatable, ImplicitlyCopyable, Writable):
    """Fundamental Datatypes.

    Every value in SQLite has one of five fundamental datatypes:
    * 64-bit signed integer
    * 64-bit IEEE floating point number
    * string
    * BLOB
    * NULL

    These cases correspond to the `SQLITE_*` datatype codes; see `code()`.
    """

    case integer
    """`SQLITE_INTEGER`: 64-bit signed integer."""
    case float
    """`SQLITE_FLOAT`: 64-bit IEEE floating point number."""
    case text
    """`SQLITE_TEXT`: String."""
    case blob
    """`SQLITE_BLOB`: BLOB."""
    case null
    """`SQLITE_NULL`: NULL."""

    def __init__(out self, code: Int32):
        """Converts a raw `SQLITE_*` datatype code, as returned by `sqlite3_column_type` or `sqlite3_value_type`.

        Args:
            code: The raw datatype code.

        Notes:
            SQLite only ever returns the five codes above, so any other value aborts.
        """
        if code == 1:
            self = Self.integer
        elif code == 2:
            self = Self.float
        elif code == 3:
            self = Self.text
        elif code == 4:
            self = Self.blob
        elif code == 5:
            self = Self.null
        else:
            abort(t"[UNREACHABLE] invalid SQLite datatype code: {code}")

    def code(self) -> Int32:
        """Returns the raw `SQLITE_*` datatype code.

        Returns:
            The integer code SQLite uses for this datatype.
        """
        match self:
            case .integer:
                return 1
            case .float:
                return 2
            case .text:
                return 3
            case .blob:
                return 4
            case .null:
                return 5

    def __eq__(self, other: Self) -> Bool:
        """Checks if two datatypes are the same.

        Args:
            other: The datatype to compare against.

        Returns:
            True if both are the same datatype, False otherwise.
        """
        return self.code() == other.code()


__enum TextEncoding(ImplicitlyCopyable, Writable):
    """Text Encodings.

    These cases correspond to the integer codes SQLite uses for the text
    encodings it supports; see `code()`.
    """

    case utf8
    """`SQLITE_UTF8`: UTF-8 encoding."""

    def code(self) -> UInt8:
        """Returns the raw `SQLITE_*` encoding code.

        Returns:
            The integer code SQLite uses for this encoding.
        """
        match self:
            case .utf8:
                return 1


__enum DestructorHint(ImplicitlyCopyable, Writable):
    """If the destructor argument is `SQLITE_STATIC`, it means that the content pointer is constant
    and will never change. It does not need to be destroyed. The
    `SQLITE_TRANSIENT` value means that the content will likely change in
    the near future and that SQLite should make its own private copy of
    the content before returning.

    Pass `destructor()` as the destructor argument when calling `sqlite3_bind_text` or
    `sqlite3_result_blob`."""

    case static
    """`SQLITE_STATIC`: The content pointer is constant and will never change."""
    case transient
    """`SQLITE_TRANSIENT`: The content will likely change in the near future and SQLite should make its own private copy of the content before returning."""

    def destructor(self) -> ResultDestructorFn:
        """Returns the sentinel function pointer SQLite recognizes for this hint.

        SQLite defines `SQLITE_STATIC` and `SQLITE_TRANSIENT` as the integers 0 and -1
        cast to a destructor function pointer, so the integer is reinterpreted here.

        Returns:
            The destructor argument to pass to SQLite.
        """
        var sentinel: Int
        match self:
            case .static:
                sentinel = 0
            case .transient:
                sentinel = -1
        return Pointer(to=sentinel).unsafe_bitcast[ResultDestructorFn]()[]
