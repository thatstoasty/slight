from std.ffi import c_char, c_int
from std.sys import size_of
from slight.api import sqlite_ffi
from slight.c.types import (
    ImmutExternalPointer,
    MutExternalPointer,
    SQLITE_ERROR,
    SQLITE_OK,
    SQLITE_READONLY,
    VtabBeginCallbackFn,
    VtabBestIndexCallbackFn,
    VtabCloseCallbackFn,
    VtabColumnCallbackFn,
    VtabCommitCallbackFn,
    VtabConnectCallbackFn,
    VtabCreateCallbackFn,
    VtabDestroyCallbackFn,
    VtabDisconnectCallbackFn,
    VtabEofCallbackFn,
    VtabFilterCallbackFn,
    VtabFindFunctionCallbackFn,
    VtabIntegrityCallbackFn,
    VtabNextCallbackFn,
    VtabOpenCallbackFn,
    VtabReleaseCallbackFn,
    VtabRenameCallbackFn,
    VtabRollbackCallbackFn,
    VtabRollbackToCallbackFn,
    VtabRowidCallbackFn,
    VtabSavepointCallbackFn,
    VtabShadowNameCallbackFn,
    VtabSyncCallbackFn,
    VtabUpdateCallbackFn,
    sqlite3_connection,
    sqlite3_context,
    sqlite3_index_info,
    sqlite3_module,
    sqlite3_value,
    sqlite3_vtab,
    sqlite3_vtab_cursor,
    _sqlite3_index_info_sqlite3_index_constraint,
    _sqlite3_index_info_sqlite3_index_constraint_usage,
)
from slight.context import Context
from slight.result import SQLite3Result
from slight.util import MoveDestructible

# ===----------------------------------------------------------------------=== #
# VTabBox / VTabCursorBox — C-compatible wrappers for user vtab/cursor data
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct VTabBox[T: MoveDestructible](Movable):
    """Extends sqlite3_vtab with user-provided virtual table state.

    The `_base` field MUST be the first field so that a `*sqlite3_vtab` can be
    safely bitcast to a `*VTabBox[T]` and vice versa (C layout guarantee).

    Parameters:
        T: The user-provided virtual table state type.
    """

    var _base: sqlite3_vtab
    """The C-compatible sqlite3_vtab base (must remain at offset 0)."""
    var data: Self.T
    """User-provided virtual table state."""


@fieldwise_init
struct VTabCursorBox[C: MoveDestructible](Movable):
    """Extends sqlite3_vtab_cursor with user-provided cursor state.

    The `_base` field MUST be the first field so that a `*sqlite3_vtab_cursor`
    can be safely bitcast to a `*VTabCursorBox[C]` and vice versa.

    Parameters:
        C: The user-provided cursor state type.
    """

    var _base: sqlite3_vtab_cursor
    """The C-compatible sqlite3_vtab_cursor base (must remain at offset 0)."""
    var data: Self.C
    """User-provided cursor state."""


# ===----------------------------------------------------------------------=== #
# User callback type aliases
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct VTabConnectResult[T: MoveDestructible](Movable):
    """Return value of a VTabConnectFn callback.

    Parameters:
        T: The user-provided virtual table state type.
    """

    var schema: String
    """A `CREATE TABLE` SQL string declaring the virtual table schema."""
    var vtab: Self.T
    """The initial virtual table state."""

    def take_schema(deinit self, out schema: String):
        """Consume this result, returning the schema and dropping vtab.

        This is an escape hatch: call only when vtab is already moved out.
        """
        schema = self.schema^

    def take_vtab(deinit self, mut schema: String, out vtab: Self.T):
        """Consume this result, extracting both the schema and vtab state.

        Moves schema into the provided variable and returns vtab via `out`.

        Args:
            schema: Receives the `CREATE TABLE` schema string.
        """
        schema = self.schema^
        vtab = self.vtab^


comptime VTabConnectFn[T: MoveDestructible] = def(
    MutExternalPointer[sqlite3_connection],
    List[String],
) raises thin -> VTabConnectResult[T]
"""User-provided xCreate / xConnect callback.

Called when a virtual table is created or an existing one is reconnected to.
Must return a `VTabConnectResult[T]` containing:
- A `CREATE TABLE` SQL string declaring the virtual table schema.
- The initial virtual table state of type `T`.

Parameters:
    T: The user-provided virtual table state type.
"""

comptime VTabBestIndexFn[T: MoveDestructible] = def(
    MutExternalPointer[T],
    MutExternalPointer[sqlite3_index_info],
) raises thin -> Bool
"""User-provided xBestIndex callback.

Called to determine the best index to use for a given query. The function
should inspect and fill in fields of the `sqlite3_index_info` struct, then
return `True` if the query order is already satisfied by the index.

Parameters:
    T: The user-provided virtual table state type.
"""

comptime VTabOpenFn[T: MoveDestructible, C: MoveDestructible] = def(
    MutExternalPointer[T],
) raises thin -> C
"""User-provided xOpen callback.

Called to create a new cursor for iterating over the virtual table. Returns
the initial cursor state of type `C`.

Parameters:
    T: The user-provided virtual table state type.
    C: The user-provided cursor state type.
"""

comptime VTabFilterFn[C: MoveDestructible] = def(
    MutExternalPointer[C],
    c_int,
    Optional[StringSlice[ImmutExternalOrigin]],
    MutExternalPointer[MutExternalPointer[sqlite3_value]],
    c_int,
) raises thin
"""User-provided xFilter callback.

Called to begin a search of the virtual table. Arguments:
- Pointer to cursor state.
- `idxNum`: integer selected by xBestIndex.
- `idxStr`: optional string selected by xBestIndex.
- `argv`: array of constraint values.
- `argc`: number of constraint values.

Parameters:
    C: The user-provided cursor state type.
"""

comptime VTabNextFn[C: MoveDestructible] = def(MutExternalPointer[C]) raises thin
"""User-provided xNext callback.

Advances the cursor to the next row.

Parameters:
    C: The user-provided cursor state type.
"""

comptime VTabEofFn[C: MoveDestructible] = def(MutExternalPointer[C]) thin -> Bool
"""User-provided xEof callback.

Returns `True` when the cursor has no more rows to return.

Parameters:
    C: The user-provided cursor state type.
"""

comptime VTabColumnFn[C: MoveDestructible] = def(
    MutExternalPointer[C], Context, c_int,
) raises thin
"""User-provided xColumn callback.

Called to retrieve the value of the column at index `iCol` from the current
cursor row. Use the `Context` to set the result value.

Parameters:
    C: The user-provided cursor state type.
"""

comptime VTabRowidFn[C: MoveDestructible] = def(MutExternalPointer[C]) raises thin -> Int64
"""User-provided xRowid callback.

Returns the rowid of the current cursor row.

Parameters:
    C: The user-provided cursor state type.
"""


# ===----------------------------------------------------------------------=== #
# Stub callbacks for optional sqlite3_module fields (read-only vtab)
# ===----------------------------------------------------------------------=== #


def _vtab_stub_update(
    pVTab: MutExternalPointer[sqlite3_vtab],
    nArg: c_int,
    apArg: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    pRowid: MutExternalPointer[Int64],
) abi("C") -> c_int:
    """Stub xUpdate that rejects all mutations (read-only virtual table)."""
    return SQLITE_READONLY


def _vtab_stub_begin(pVTab: MutExternalPointer[sqlite3_vtab]) abi("C") -> c_int:
    """Stub xBegin — transactions not supported."""
    return SQLITE_OK


def _vtab_stub_sync(pVTab: MutExternalPointer[sqlite3_vtab]) abi("C") -> c_int:
    """Stub xSync — transactions not supported."""
    return SQLITE_OK


def _vtab_stub_commit(pVTab: MutExternalPointer[sqlite3_vtab]) abi("C") -> c_int:
    """Stub xCommit — transactions not supported."""
    return SQLITE_OK


def _vtab_stub_rollback(pVTab: MutExternalPointer[sqlite3_vtab]) abi("C") -> c_int:
    """Stub xRollback — transactions not supported."""
    return SQLITE_OK


def _vtab_stub_find_function(
    pVtab: MutExternalPointer[sqlite3_vtab],
    nArg: c_int,
    zName: ImmutExternalPointer[c_char],
    pxFunc: def(MutExternalPointer[sqlite3_context], c_int, MutExternalPointer[MutExternalPointer[sqlite3_value]]) abi("C") thin -> MutExternalPointer[MutExternalPointer[NoneType]],
    ppArg: MutExternalPointer[MutExternalPointer[NoneType]],
) abi("C") -> c_int:
    """Stub xFindFunction — no overloaded SQL functions."""
    return c_int(0)


def _vtab_stub_rename(
    pVtab: MutExternalPointer[sqlite3_vtab],
    zNew: MutExternalPointer[c_char],
) abi("C") -> c_int:
    """Stub xRename — renaming not supported (read-only)."""
    return SQLITE_READONLY


def _vtab_stub_savepoint(
    pVTab: MutExternalPointer[sqlite3_vtab], iSavepoint: c_int,
) abi("C") -> c_int:
    """Stub xSavepoint — savepoints not supported."""
    return SQLITE_OK


def _vtab_stub_release(
    pVTab: MutExternalPointer[sqlite3_vtab], iSavepoint: c_int,
) abi("C") -> c_int:
    """Stub xRelease — savepoints not supported."""
    return SQLITE_OK


def _vtab_stub_rollback_to(
    pVTab: MutExternalPointer[sqlite3_vtab], iSavepoint: c_int,
) abi("C") -> c_int:
    """Stub xRollbackTo — savepoints not supported."""
    return SQLITE_OK


def _vtab_stub_shadow_name(zName: ImmutExternalPointer[c_char]) abi("C") -> c_int:
    """Stub xShadowName — no shadow tables."""
    return c_int(0)


def _vtab_stub_integrity(
    pVTab: MutExternalPointer[sqlite3_vtab],
    zSchema: MutExternalPointer[MutExternalPointer[c_char]],
    pzErr: MutExternalPointer[MutExternalPointer[c_char]],
) abi("C") -> c_int:
    """Stub xIntegrity — no integrity check implemented."""
    return SQLITE_OK


# ===----------------------------------------------------------------------=== #
# C-compatible callback wrappers (parameterized over user callback types)
# ===----------------------------------------------------------------------=== #


def _vtab_xConnect[
    T: MoveDestructible,
    connect_fn: VTabConnectFn[T],
](
    db: MutExternalPointer[sqlite3_connection],
    pAux: MutExternalPointer[NoneType],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[c_char]],
    ppVTab: MutExternalPointer[MutExternalPointer[sqlite3_vtab]],
    pzErr: MutExternalPointer[MutExternalPointer[c_char]],
) abi("C") -> c_int:
    """xCreate / xConnect trampoline.

    Parses SQLite-supplied module arguments, calls the user `connect_fn`,
    declares the virtual table schema, and allocates a `VTabBox[T]` for
    the vtab lifetime.

    Parameters:
        T: The user-provided virtual table state type.
        connect_fn: The user-provided xCreate / xConnect implementation.
    """
    # Build a List[String] from the argv array supplied by SQLite.
    var args = List[String]()
    for i in range(Int(argc)):
        var ptr = argv[i]
        args.append(String(StringSlice(unsafe_from_utf8_ptr=ptr)))

    try:
        var result = connect_fn(db, args^)
        var schema: String = ""
        var vtab_data = result^.take_vtab(schema)

        # Register the schema with SQLite — must happen inside xCreate/xConnect.
        var rc = sqlite_ffi()[].declare_vtab(db, schema)
        if rc != SQLITE_OK:
            return c_int(Int(rc))

        # Allocate VTabBox[T] on the heap.
        var vtab_base = sqlite3_vtab(
            pModule=None, nRef=c_int(0), zErrMsg=None
        )
        var box_ptr = alloc[VTabBox[T]](count=1)
        box_ptr.init_pointee_move(VTabBox[T](_base=vtab_base^, data=vtab_data^))

        # Write the vtab pointer back to SQLite.
        ppVTab[] = box_ptr.bitcast[sqlite3_vtab]().unsafe_origin_cast[MutExternalOrigin]()
        return SQLITE_OK
    except e:
        print("vtab xConnect error:", e)
        return SQLITE_ERROR


def _vtab_xBestIndex[
    T: MoveDestructible, //,
    best_index_fn: VTabBestIndexFn[T],
](
    pVTab: MutExternalPointer[sqlite3_vtab],
    pIdxInfo: MutExternalPointer[sqlite3_index_info],
) abi("C") -> c_int:
    """xBestIndex trampoline.

    Casts the sqlite3_vtab pointer to the full VTabBox[T], then calls the
    user-provided xBestIndex implementation.

    Parameters:
        T: The user-provided virtual table state type.
        best_index_fn: The user-provided xBestIndex implementation.
    """
    var box_ptr = pVTab.bitcast[VTabBox[T]]()
    try:
        var data_ptr = UnsafePointer(to=box_ptr[].data).unsafe_origin_cast[MutExternalOrigin]()
        _ = best_index_fn(data_ptr, pIdxInfo)
        return SQLITE_OK
    except:
        return SQLITE_ERROR


def _vtab_xDisconnect[T: MoveDestructible](
    pVTab: MutExternalPointer[sqlite3_vtab],
) abi("C") -> c_int:
    """xDisconnect / xDestroy trampoline.

    Moves the user data out of the VTabBox[T], drops it (triggering the
    destructor), then frees the heap allocation.

    Parameters:
        T: The user-provided virtual table state type.
    """
    var box_ptr = pVTab.bitcast[VTabBox[T]]()
    # Destroy the user data in-place so its destructor runs (frees inner heap
    # allocations) before we free the raw VTabBox memory.
    UnsafePointer(to=box_ptr[].data).destroy_pointee()
    box_ptr.free()
    return SQLITE_OK


def _vtab_xOpen[
    T: MoveDestructible,
    C: MoveDestructible, //,
    open_fn: VTabOpenFn[T, C],
](
    pVTab: MutExternalPointer[sqlite3_vtab],
    ppCursor: MutExternalPointer[MutExternalPointer[sqlite3_vtab_cursor]],
) abi("C") -> c_int:
    """xOpen trampoline.

    Calls the user-provided xOpen implementation and allocates a VTabCursorBox[C]
    for the cursor lifetime.

    Parameters:
        T: The user-provided virtual table state type.
        C: The user-provided cursor state type.
        open_fn: The user-provided xOpen implementation.
    """
    var box_ptr = pVTab.bitcast[VTabBox[T]]()
    try:
        var cursor_data = open_fn(UnsafePointer(to=box_ptr[].data).unsafe_origin_cast[MutExternalOrigin]())

        # Allocate VTabCursorBox[C] on the heap.
        var cursor_base = sqlite3_vtab_cursor(pVtab=None)
        var cursor_box_ptr = alloc[VTabCursorBox[C]](count=1)
        cursor_box_ptr.init_pointee_move(
            VTabCursorBox[C](_base=cursor_base^, data=cursor_data^)
        )

        # Write the cursor pointer back to SQLite.
        ppCursor[] = cursor_box_ptr.bitcast[sqlite3_vtab_cursor]().unsafe_origin_cast[
            MutExternalOrigin
        ]()
        return SQLITE_OK
    except:
        return SQLITE_ERROR


def _vtab_xClose[C: MoveDestructible](
    pCursor: MutExternalPointer[sqlite3_vtab_cursor],
) abi("C") -> c_int:
    """xClose trampoline.

    Moves the cursor state out of VTabCursorBox[C] (triggering its destructor)
    then frees the heap allocation.

    Parameters:
        C: The user-provided cursor state type.
    """
    var cursor_box_ptr = pCursor.bitcast[VTabCursorBox[C]]()
    # Destroy the cursor data in-place so its destructor runs before freeing memory.
    UnsafePointer(to=cursor_box_ptr[].data).destroy_pointee()
    cursor_box_ptr.free()
    return SQLITE_OK


def _vtab_xFilter[
    C: MoveDestructible, //,
    filter_fn: VTabFilterFn[C],
](
    pCursor: MutExternalPointer[sqlite3_vtab_cursor],
    idxNum: c_int,
    idxStr: Optional[ImmutExternalPointer[c_char]],
    argc: c_int,
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
) abi("C") -> c_int:
    """xFilter trampoline.

    Converts the raw C parameters into Mojo-friendly types and calls the
    user-provided xFilter implementation.

    Parameters:
        C: The user-provided cursor state type.
        filter_fn: The user-provided xFilter implementation.
    """
    var cursor_box_ptr = pCursor.bitcast[VTabCursorBox[C]]()

    # Convert nullable idxStr C pointer to Optional[StringSlice].
    var idx_str: Optional[StringSlice[ImmutExternalOrigin]] = None
    if idxStr:
        idx_str = StringSlice[ImmutExternalOrigin](
            unsafe_from_utf8_ptr=idxStr.value()
        )

    try:
        filter_fn(
            UnsafePointer(to=cursor_box_ptr[].data).unsafe_origin_cast[MutExternalOrigin](),
            idxNum,
            idx_str,
            argv,
            argc,
        )
        return SQLITE_OK
    except:
        return SQLITE_ERROR


def _vtab_xNext[
    C: MoveDestructible, //,
    next_fn: VTabNextFn[C],
](
    pCursor: MutExternalPointer[sqlite3_vtab_cursor],
) abi("C") -> c_int:
    """xNext trampoline.

    Parameters:
        C: The user-provided cursor state type.
        next_fn: The user-provided xNext implementation.
    """
    var cursor_box_ptr = pCursor.bitcast[VTabCursorBox[C]]()
    try:
        next_fn(UnsafePointer(to=cursor_box_ptr[].data).unsafe_origin_cast[MutExternalOrigin]())
        return SQLITE_OK
    except:
        return SQLITE_ERROR


def _vtab_xEof[
    C: MoveDestructible, //,
    eof_fn: VTabEofFn[C],
](
    pCursor: MutExternalPointer[sqlite3_vtab_cursor],
) abi("C") -> c_int:
    """xEof trampoline.

    Returns 1 if the cursor is past the last row, 0 otherwise.

    Parameters:
        C: The user-provided cursor state type.
        eof_fn: The user-provided xEof implementation.
    """
    var cursor_box_ptr = pCursor.bitcast[VTabCursorBox[C]]()
    return c_int(1) if eof_fn(UnsafePointer(to=cursor_box_ptr[].data).unsafe_origin_cast[MutExternalOrigin]()) else c_int(0)


def _vtab_xColumn[
    C: MoveDestructible, //,
    column_fn: VTabColumnFn[C],
](
    pCursor: MutExternalPointer[sqlite3_vtab_cursor],
    pCtx: MutExternalPointer[sqlite3_context],
    iCol: c_int,
) abi("C") -> c_int:
    """xColumn trampoline.

    Parameters:
        C: The user-provided cursor state type.
        column_fn: The user-provided xColumn implementation.
    """
    var cursor_box_ptr = pCursor.bitcast[VTabCursorBox[C]]()
    var context = Context(pCtx)
    try:
        column_fn(UnsafePointer(to=cursor_box_ptr[].data).unsafe_origin_cast[MutExternalOrigin](), context, iCol)
        return SQLITE_OK
    except:
        return SQLITE_ERROR


def _vtab_xRowid[
    C: MoveDestructible, //,
    rowid_fn: VTabRowidFn[C],
](
    pCursor: MutExternalPointer[sqlite3_vtab_cursor],
    pRowid: MutExternalPointer[Int64],
) abi("C") -> c_int:
    """xRowid trampoline.

    Parameters:
        C: The user-provided cursor state type.
        rowid_fn: The user-provided xRowid implementation.
    """
    var cursor_box_ptr = pCursor.bitcast[VTabCursorBox[C]]()
    try:
        pRowid[] = rowid_fn(UnsafePointer(to=cursor_box_ptr[].data).unsafe_origin_cast[MutExternalOrigin]())
        return SQLITE_OK
    except:
        return SQLITE_ERROR


# ===----------------------------------------------------------------------=== #
# Module factory functions
# ===----------------------------------------------------------------------=== #


def make_read_only_module[
    T: MoveDestructible,
    C: MoveDestructible, //,
    connect_fn: VTabConnectFn[T],
    best_index_fn: VTabBestIndexFn[T],
    open_fn: VTabOpenFn[T, C],
    filter_fn: VTabFilterFn[C],
    next_fn: VTabNextFn[C],
    eof_fn: VTabEofFn[C],
    column_fn: VTabColumnFn[C],
    rowid_fn: VTabRowidFn[C],
]() -> MutExternalPointer[sqlite3_module]:
    """Allocate and return a heap-allocated `sqlite3_module` for a read-only virtual table.

    The same callback is used for both xCreate and xConnect, making this an
    eponymous-style module that can be used with `CREATE VIRTUAL TABLE` and as
    a table-valued function.

    The returned pointer must be passed to `Connection.create_module()`, which
    also registers it as `pClientData` so SQLite automatically frees it via the
    default destructor when the module is unregistered.

    Parameters:
        T: The user-provided virtual table state type.
        C: The user-provided cursor state type.
        connect_fn: Called for both xCreate and xConnect.
        best_index_fn: Called for xBestIndex.
        open_fn: Called for xOpen to create a cursor.
        filter_fn: Called for xFilter to begin a scan.
        next_fn: Called for xNext to advance the cursor.
        eof_fn: Called for xEof to check end-of-rows.
        column_fn: Called for xColumn to retrieve a column value.
        rowid_fn: Called for xRowid to retrieve the current rowid.

    Returns:
        A heap-allocated `MutExternalPointer[sqlite3_module]`.
    """
    var module_ptr = alloc[sqlite3_module](count=1)
    module_ptr[0] = sqlite3_module(
        iVersion=c_int(3),
        xCreate=_vtab_xConnect[T, connect_fn],
        xConnect=_vtab_xConnect[T, connect_fn],
        xBestIndex=_vtab_xBestIndex[best_index_fn],
        xDisconnect=_vtab_xDisconnect[T],
        xDestroy=_vtab_xDisconnect[T],
        xOpen=_vtab_xOpen[open_fn],
        xClose=_vtab_xClose[C],
        xFilter=_vtab_xFilter[filter_fn],
        xNext=_vtab_xNext[next_fn],
        xEof=_vtab_xEof[eof_fn],
        xColumn=_vtab_xColumn[column_fn],
        xRowid=_vtab_xRowid[rowid_fn],
        xUpdate=_vtab_stub_update,
        xBegin=_vtab_stub_begin,
        xSync=_vtab_stub_sync,
        xCommit=_vtab_stub_commit,
        xRollback=_vtab_stub_rollback,
        xFindFunction=_vtab_stub_find_function,
        xRename=_vtab_stub_rename,
        xSavepoint=_vtab_stub_savepoint,
        xRelease=_vtab_stub_release,
        xRollbackTo=_vtab_stub_rollback_to,
        xShadowName=_vtab_stub_shadow_name,
        xIntegrity=_vtab_stub_integrity,
    )
    return module_ptr
