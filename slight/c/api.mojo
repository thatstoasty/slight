from slight.c.bindings import sqlite3
from slight.c.types import MutExternalPointer
from std.ffi import _get_global


def _init_global() -> Optional[MutExternalPointer[NoneType]]:
    var ptr = alloc[sqlite3](1)
    ptr[] = sqlite3()
    return ptr.bitcast[NoneType]()


def _destroy_global(lib: Optional[MutExternalPointer[NoneType]]):
    if lib:
        var p = lib.value().bitcast[sqlite3]()
        p.free()


@always_inline
def sqlite_ffi() -> MutExternalPointer[sqlite3]:
    """Initializes or gets the global sqlite3 handle.

    DO NOT FREE THE POINTER MANUALLY. It will be freed automatically on program exit.

    Returns:
        A pointer to the global sqlite3 handle.
    """
    return _get_global["sqlite3", _init_global, _destroy_global]().value().bitcast[sqlite3]()
