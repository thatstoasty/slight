"""SQLite FFI Binding."""
from std.ffi import _get_global
from std.memory.alloc import unsafe_alloc
from std.memory import unsafe_destroy_n
from slight.c.types import MutExternalPointer
from slight.bindings import sqlite3


def _init_global() -> Optional[MutExternalPointer[NoneType]]:
    var ptr = unsafe_alloc[sqlite3](1)
    ptr.unsafe_write(sqlite3())
    return ptr.unsafe_bitcast[NoneType]()


def _destroy_global(lib: Optional[MutExternalPointer[NoneType]]):
    if lib:
        var p = lib.value().unsafe_bitcast[sqlite3]()
        p.unsafe_deinit_pointee()
        p.unsafe_free()


@always_inline
def sqlite_ffi() -> MutExternalPointer[sqlite3]:
    """Initializes or gets the global sqlite3 handle.

    DO NOT FREE THE POINTER MANUALLY. It will be freed automatically on program exit.

    Returns:
        A pointer to the global sqlite3 handle.
    """
    return _get_global["sqlite3", _init_global, _destroy_global]().value().unsafe_bitcast[sqlite3]()
