"""Helper utilities."""
from std.pathlib import Path
from std.ffi import CStringSlice
from std.memory.alloc import unsafe_alloc
from slight.c.types import MutExternalPointer

comptime CopyDestructible = Copyable & Deinitable
comptime MoveDestructible = Movable & Deinitable


def as_byte[char: StringSpan]() -> Byte:
    """Convert a single-character StringSpan to a Byte.

    Parameters:
        char: A StringSpan that must contain exactly one character.

    Returns:
        The Byte representation of the single character.
    """
    comptime assert char.byte_length() == 1, "Expected a single-character StringSpan for Byte conversion"
    return char.as_bytes()[0]


def ptr_copy[T: CopyDestructible](data: T) -> MutExternalPointer[T]:
    """Creates a copy of the value as a mutable external pointer.

    This is used to create a copy of the application data to pass to SQLite when creating user-defined functions.
    This data can be freed on demand by the destructor callback, and we don't have to worry
    about Mojo's ASAP destruction.

    Returns:
        A mutable external pointer containing a copy of the value.
    """
    var ptr = unsafe_alloc[T](count=1)
    ptr.unsafe_write(data.copy())
    return ptr


def str_slice_to_path(s: CStringSlice[ImmUntrackedOrigin]) -> Optional[Path]:
    """Convert a String to a Path.

    Args:
        s: The String to convert.

    Returns:
        A Path representing the input String.
    """
    return Path(StringSpan(unsafe_from_utf8=s))


def str_slice_to_string(s: StringSpan[ImmUntrackedOrigin]) -> Optional[String]:
    """Convert a StringSpan to a String.

    Args:
        s: The String to convert.

    Returns:
        A newly allocated String copy of the StringSpan.
    """
    return String(s)
