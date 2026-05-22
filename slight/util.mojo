from slight.c.types import MutExternalPointer

comptime CopyDestructible = Movable & Copyable & ImplicitlyDestructible
comptime MoveDestructible = Movable & ImplicitlyDestructible
comptime ColumnType = ImplicitlyDestructible & Movable & Defaultable


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
