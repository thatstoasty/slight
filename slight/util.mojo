fn as_byte[char: StringSlice]() -> Byte:
    """Convert a single-character StringSlice to a Byte.

    Parameters:
        char: A StringSlice that must contain exactly one character.

    Returns:
        The Byte representation of the single character.
    """
    comptime assert len(char) == 1, "Expected a single-character StringSlice for Byte conversion"
    return char.as_bytes()[0]
