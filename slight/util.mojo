from std.pathlib import Path
from slight.c.types import MutExternalPointer

comptime CopyDestructible = Copyable & ImplicitlyDestructible
comptime MoveDestructible = Movable & ImplicitlyDestructible
comptime ColumnType = MoveDestructible & Defaultable


def as_byte[char: StringSlice]() -> Byte:
    """Convert a single-character StringSlice to a Byte.

    Parameters:
        char: A StringSlice that must contain exactly one character.

    Returns:
        The Byte representation of the single character.
    """
    comptime assert char.byte_length() == 1, "Expected a single-character StringSlice for Byte conversion"
    return char.as_bytes()[0]


def ptr_copy[T: CopyDestructible](data: T) -> MutExternalPointer[T]:
    """Creates a copy of the value as a mutable external pointer.

    This is used to create a copy of the application data to pass to SQLite when creating user-defined functions.
    This data can be freed on demand by the destructor callback, and we don't have to worry
    about Mojo's ASAP destruction.

    Returns:
        A mutable external pointer containing a copy of the value.
    """
    var ptr = alloc[T](count=1)
    ptr[0] = data.copy()
    return ptr


def str_slice_to_path(s: StringSlice[ImmutExternalOrigin]) -> Optional[Path]:
    """Convert a String to a Path.

    Args:
        s: The String to convert.

    Returns:
        A Path representing the input String.
    """
    return Path(s)


def str_slice_to_string(s: StringSlice[ImmutExternalOrigin]) -> Optional[String]:
    """Convert a StringSlice to a String.

    Args:
        s: The String to convert.

    Returns:
        A newly allocated String copy of the StringSlice.
    """
    return String(s)
