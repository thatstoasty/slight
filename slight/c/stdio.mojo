"""Thin wrappers around the C standard I/O functions needed for CSV streaming.

``FILE *`` handles are represented as ``Int`` (an opaque integer-sized value).
String path and mode arguments use ``ImmutUnsafePointer[c_char, origin]`` so
that LLVM sees typed pointer arguments to the external call — this prevents
dead-store elimination of the string buffers in AOT-compiled code.

The caller is responsible for:
- Keeping the path/mode strings alive across the ``fopen`` call.
- Checking that ``fopen`` returns a non-zero value before use.
- Calling ``fclose`` exactly once per successfully opened handle.
"""

from std.ffi import external_call, c_char, c_int

comptime CPointer[T: AnyType, origin: Origin] = Optional[UnsafePointer[T, origin]]
# SEEK_* constants (POSIX)
comptime SEEK_SET: c_int = c_int(0)
"""Seek from the beginning of the file."""
comptime SEEK_CUR: c_int = c_int(1)
"""Seek from the current file position."""
comptime SEEK_END: c_int = c_int(2)
"""Seek from the end of the file."""


def fopen[
    path_origin: ImmutOrigin,
    mode_origin: ImmutOrigin, //
](
    path: ImmutUnsafePointer[c_char, path_origin],
    mode: ImmutUnsafePointer[c_char, mode_origin],
) -> CPointer[NoneType, MutExternalOrigin]:
    """Open a file and return an opaque ``FILE *`` handle.

    Args:
        path: Immutable pointer to a null-terminated file path string.
        mode: Immutable pointer to a null-terminated mode string (e.g. ``"r"``).

    Returns:
        Opaque ``FILE *`` pointer on success, None on failure.
    """
    return external_call["fopen", CPointer[NoneType, MutExternalOrigin]](path, mode)


def fclose(fp: CPointer[NoneType, MutExternalOrigin]) -> c_int:
    """Close a ``FILE *`` handle.

    Args:
        fp: Handle previously returned by ``fopen``.

    Returns:
        0 on success, ``EOF`` on error.
    """
    return external_call["fclose", c_int](fp)


def fseek(fp: CPointer[NoneType, MutExternalOrigin], offset: Int, whence: c_int) -> c_int:
    """Reposition the file-position indicator.

    Args:
        fp: Open file handle.
        offset: Byte offset relative to ``whence``.
        whence: One of ``SEEK_SET``, ``SEEK_CUR``, or ``SEEK_END``.

    Returns:
        0 on success, non-zero on error.
    """
    return external_call["fseek", c_int](fp, offset, whence)


def ftell(fp: CPointer[NoneType, MutExternalOrigin]) -> Int:
    """Return the current file-position indicator.

    Args:
        fp: Open file handle.

    Returns:
        Current byte offset from the beginning of the file, or -1 on error.
    """
    return external_call["ftell", Int](fp)


def fread(buf: CPointer[NoneType, MutExternalOrigin], size: Int, count: Int, fp: CPointer[NoneType, MutExternalOrigin]) -> Int:
    """Read up to ``count`` elements of ``size`` bytes each from ``fp``.

    Args:
        buf: Opaque pointer to the destination buffer.
        size: Size of each element in bytes.
        count: Maximum number of elements to read.
        fp: Open file handle.

    Returns:
        Number of elements successfully read (may be less than ``count`` at EOF
        or on error).
    """
    return external_call["fread", Int](buf, size, count, fp)


def fgetc(fp: CPointer[NoneType, MutExternalOrigin]) -> Optional[Byte]:
    """Read one byte from an open file handle.

    Args:
        fp: Open file handle.

    Returns:
        The byte value (0-255), or -1 at end-of-file / on error.
    """
    var ret = external_call["fgetc", c_int](fp)
    if ret < c_int(0):
        return None
    return Byte(Int(ret))


def feof(fp: CPointer[NoneType, MutExternalOrigin]) -> c_int:
    """Test the end-of-file indicator.

    Args:
        fp: Open file handle.

    Returns:
        Non-zero if the end-of-file indicator is set, 0 otherwise.
    """
    return external_call["feof", c_int](fp)
