from sys.ffi import _get_global

from slight.c.bindings import sqlite3


fn _init_global() -> OpaquePointer[MutExternalOrigin]:
    var ptr = alloc[sqlite3](1)
    ptr[] = sqlite3()
    return ptr.bitcast[NoneType]()


fn _destroy_global(lib: OpaquePointer[MutExternalOrigin]):
    var p = lib.bitcast[sqlite3]()
    p.free()


@always_inline
fn sqlite_ffi() -> UnsafePointer[sqlite3, MutExternalOrigin]:
    """Initializes or gets the global sqlite3 handle.

    DO NOT FREE THE POINTER MANUALLY. It will be freed automatically on program exit.

    Returns:
        A pointer to the global sqlite3 handle.
    """
    return _get_global["sqlite3", _init_global, _destroy_global]().bitcast[sqlite3]()
