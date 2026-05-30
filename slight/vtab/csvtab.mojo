"""CSV Virtual Table for slight/SQLite.

Provides a read-only virtual table that exposes a CSV file as an SQL table.
Rows are streamed one at a time from the file rather than loaded into memory
up-front, matching the behaviour of ``rusqlite/src/vtab/csvtab.rs``.

Usage::

    CREATE VIRTUAL TABLE my_csv USING csv(
        filename='path/to/file.csv'        -- required: path to CSV file
        [, header=yes|no]                  -- default: no
        [, delimiter=C]                    -- default: ,
        [, quote=C]                        -- default: "  (use 0 to disable)
        [, columns=N]                      -- explicit column count
        [, schema=SQL]                     -- explicit CREATE TABLE SQL
    );
    SELECT * FROM my_csv;

Port of ``rusqlite/src/vtab/csvtab.rs``.
"""

from std.ffi import c_char, c_int
from slight.c.types import (
    ImmutExternalOrigin,
    MutExternalPointer,
    sqlite3_connection,
    sqlite3_index_info,
    sqlite3_value,
)
from slight.c.stdio import (
    SEEK_SET,
    SEEK_CUR,
    fopen,
    fclose,
    fseek,
    ftell,
    fread,
)
from slight.connection import Connection
from slight.context import Context
from slight.vtab.vtab import (
    VTabConnectFn,
    VTabBestIndexFn,
    VTabOpenFn,
    VTabFilterFn,
    VTabNextFn,
    VTabEofFn,
    VTabColumnFn,
    VTabRowidFn,
    VTabConnectResult,
    VTabConnection,
)

# Read buffer size for streaming (bytes per fread call).
comptime _READ_BUF_SIZE: Int = 4096


# ===----------------------------------------------------------------------=== #
# Virtual table / cursor state structs
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct CsvState(Movable):
    """State shared across all cursors for a given CSV virtual table instance.

    Unlike the previous in-memory design, ``CsvState`` no longer stores any
    row data.  Each cursor opens its own ``FILE *`` handle at ``xFilter``
    time and streams rows on demand.
    """

    var filename: String
    """Path to the CSV file."""

    var has_headers: Bool
    """Whether the first row of the CSV file is a header row."""

    var delimiter: UInt8
    """Field delimiter byte (default: ASCII 44 = ',')."""

    var quote: UInt8
    """Quote character byte (default: ASCII 34 = '"'); 0 = no quoting."""

    var n_cols: Int
    """Number of columns in the virtual table."""

    var data_start_offset: Int
    """Byte offset of the first data row (skips the header row when present).

    Equivalent to ``offset_first_row`` in the Rust implementation.
    Cursors seek to this position at the start of each scan so the header
    row is never re-exposed as a data row.
    """


@fieldwise_init
struct CsvCursor(Movable):
    """Streaming cursor state for a CSV virtual table scan.

    Each cursor holds an open ``FILE *`` handle (represented as ``Int``).
    Rows are parsed one at a time: only ``current_row`` is kept in memory.
    The file is closed when the cursor is destroyed (``__del__``).
    """

    var fp: Int
    """Open ``FILE *`` handle (0 = not open)."""

    var filename: String
    """Path of the CSV file — needed to re-open on each ``xFilter`` call."""

    var data_start_offset: Int
    """Byte offset at which data rows begin (header already skipped)."""

    var delimiter: UInt8
    """Field delimiter byte."""

    var quote: UInt8
    """Quote character byte (0 = no quoting)."""

    var current_row: List[String]
    """Fields of the row most recently read by ``xNext``."""

    var row_number: Int
    """1-based row counter used as the rowid."""

    var eof: Bool
    """True when the cursor has read past the last row."""

    def __init__(
        out self,
        filename: String,
        data_start_offset: Int,
        delimiter: UInt8,
        quote: UInt8,
    ):
        self.fp = 0
        self.filename = filename
        self.data_start_offset = data_start_offset
        self.delimiter = delimiter
        self.quote = quote
        self.current_row = List[String]()
        self.row_number = 0
        self.eof = True

    def __del__(deinit self):
        """Close the file handle when the cursor is destroyed."""
        if self.fp != 0:
            _ = fclose(self.fp)


# ===----------------------------------------------------------------------=== #
# CSV parsing helpers
# ===----------------------------------------------------------------------=== #


def _fgetc(fp: Int) -> Int:
    """Read one byte from an open file handle.

    Args:
        fp: Open file handle.

    Returns:
        The byte value (0-255), or -1 at end-of-file / on error.
    """
    var buf = List[UInt8](capacity=1)
    buf.append(UInt8(0))
    var n = fread(Int(buf.unsafe_ptr()), 1, 1, fp)
    if n == 0:
        return -1
    return Int(buf[0])


def _read_row_from_fp(
    fp: Int,
    delimiter: UInt8,
    quote: UInt8,
) -> Optional[List[String]]:
    """Read one CSV row from an open file handle.

    Handles CRLF and LF line endings. Quoted fields (enclosed by ``quote``)
    may span multiple lines. Doubled quote characters inside a quoted field
    are treated as an escaped single quote (RFC 4180).

    Args:
        fp: Open file handle positioned at the start of the next row.
        delimiter: Field separator byte (e.g. 44 for ``,``).
        quote: Quote character byte (e.g. 34 for ``"``); 0 disables quoting.

    Returns:
        The next row as a list of field strings, or ``None`` at end-of-file.
    """
    var row = List[String]()

    while True:  # one iteration per field
        var field_bytes = List[UInt8]()
        var next_action: Int = 0  # 0 = end_of_row, 1 = next_field

        var b = _fgetc(fp)

        if b == -1:
            # EOF — if no fields have been read yet this is a clean EOF.
            if len(row) == 0:
                return None
            # EOF at the start of an expected field (no trailing newline):
            # add an empty final field to match behaviour of _parse_csv.
            field_bytes.append(UInt8(0))
            row.append(
                String(
                    StringSlice(
                        unsafe_from_utf8_ptr=field_bytes.unsafe_ptr().bitcast[c_char]()
                    )
                )
            )
            break

        elif b == Int(UInt8(10)):  # LF — empty field, end of row
            next_action = 0

        elif b == Int(UInt8(13)):  # CR (possibly CRLF) — empty field, end of row
            var peek = _fgetc( fp)
            if peek != Int(UInt8(10)) and peek != -1:
                # Bare CR: put the peeked byte back.
                _ = fseek(fp, -1, SEEK_CUR)
            next_action = 0

        elif b == Int(delimiter):
            # Empty field followed immediately by a delimiter.
            next_action = 1

        elif quote != UInt8(0) and b == Int(quote):
            # Quoted field — read until the matching closing quote.
            var done = False
            while not done:
                var c = _fgetc(fp)
                if c == -1:
                    done = True  # Unclosed quote at EOF.
                    next_action = 0
                elif c == Int(quote):
                    # Doubled quote → literal quote character.
                    var next_c = _fgetc(fp)
                    if next_c == Int(quote):
                        field_bytes.append(quote)
                    else:
                        # Closing quote: next_c determines row/field boundary.
                        if next_c == -1:
                            next_action = 0
                        elif next_c == Int(delimiter):
                            next_action = 1
                        elif next_c == Int(UInt8(13)):
                            var lf = _fgetc(fp)
                            if lf != Int(UInt8(10)) and lf != -1:
                                _ = fseek(fp, -1, SEEK_CUR)
                            next_action = 0
                        elif next_c == Int(UInt8(10)):
                            next_action = 0
                        else:
                            # Malformed: content after closing quote; include.
                            field_bytes.append(UInt8(next_c))
                            next_action = 1
                        done = True
                else:
                    field_bytes.append(UInt8(c))

        else:
            # Unquoted field; ``b`` is the first byte of the field value.
            field_bytes.append(UInt8(b))
            var done = False
            while not done:
                var c = _fgetc(fp)
                if c == -1:
                    next_action = 0
                    done = True
                elif c == Int(delimiter):
                    next_action = 1
                    done = True
                elif c == Int(UInt8(13)):  # CR
                    var lf = _fgetc(fp)
                    if lf != Int(UInt8(10)) and lf != -1:
                        _ = fseek(fp, -1, SEEK_CUR)
                    next_action = 0
                    done = True
                elif c == Int(UInt8(10)):  # LF
                    next_action = 0
                    done = True
                else:
                    field_bytes.append(UInt8(c))

        # Build a String from the accumulated bytes and append to the row.
        field_bytes.append(UInt8(0))
        row.append(
            String(
                StringSlice(
                    unsafe_from_utf8_ptr=field_bytes.unsafe_ptr().bitcast[c_char]()
                )
            )
        )

        if next_action == 0:
            break

    if len(row) == 0:
        return None
    return row^


def _dequote(s: String) -> String:
    """Remove surrounding quote characters from a string.

    Handles ``"..."``, ``'...'``, `` `...` ``, and ``[...]`` delimiters.

    Args:
        s: The string to dequote.

    Returns:
        The inner content with surrounding delimiters removed, or ``s``
        unchanged if no recognised delimiters are present.
    """
    var n = s.byte_length()
    if n < 2:
        return s
    var bytes = s.as_bytes()
    var first = bytes[0]
    var last = bytes[n - 1]
    # ASCII: 34 = ", 39 = ', 96 = `, 91 = [, 93 = ]
    var is_match = False
    if first == UInt8(34) or first == UInt8(39) or first == UInt8(96):
        is_match = last == first
    elif first == UInt8(91) and last == UInt8(93):  # [ ... ]
        is_match = True
    if not is_match:
        return s
    # Build the inner string (bytes[1 .. n-2] inclusive).
    var inner = List[UInt8]()
    for i in range(1, n - 1):
        inner.append(bytes[i])
    inner.append(UInt8(0))
    # `String(StringSlice(unsafe_from_utf8_ptr=...))` may not include the null
    # terminator in all Mojo versions, causing `unsafe_ptr()` to fail for C
    # interop (e.g. fopen).  Appending via `+=` into a fresh empty `String`
    # forces a proper copy with null termination regardless of version.
    var result = String()
    result += String(
        StringSlice(
            unsafe_from_utf8_ptr=inner.unsafe_ptr().bitcast[c_char]()
        )
    )
    return result


def _parse_boolean(s: String) -> Optional[Bool]:
    """Parse a boolean keyword.

    Recognised **true** values (case-insensitive): ``yes``, ``on``, ``true``,
    ``1``.
    Recognised **false** values (case-insensitive): ``no``, ``off``,
    ``false``, ``0``.

    Args:
        s: The string to parse.

    Returns:
        ``True`` or ``False``, or ``None`` if the string is not recognised.
    """
    var lower = s.lower()
    if lower == "yes" or lower == "on" or lower == "true" or s == "1":
        return True
    elif lower == "no" or lower == "off" or lower == "false" or s == "0":
        return False
    return None


def _escape_double_quotes(s: String) -> String:
    """Escape double-quote characters in a string by doubling them.

    Used when embedding CSV column names inside a double-quoted SQL identifier.
    For example, ``my"col`` becomes ``my""col``.

    Args:
        s: The column name to escape.

    Returns:
        The escaped string.
    """
    if s.find('"') == -1:
        return s
    var result = String()
    var n = s.byte_length()
    var raw = s.unsafe_ptr().bitcast[UInt8]()
    for i in range(n):
        var b = raw[i]
        if b == UInt8(34):  # '"'
            result += "\"\""
        else:
            var tmp = List[UInt8]()
            tmp.append(b)
            tmp.append(UInt8(0))
            result += String(
                StringSlice(
                    unsafe_from_utf8_ptr=tmp.unsafe_ptr().bitcast[c_char]()
                )
            )
    return result


# ===----------------------------------------------------------------------=== #
# xConnect
# ===----------------------------------------------------------------------=== #


def csv_connect(
    db: VTabConnection,
    aux: MutExternalPointer[NoneType],
    module_name: String,
    database_name: String,
    table_name: String,
    argv: Span[String, ...],
) raises -> VTabConnectResult[CsvState]:
    """Parse module arguments, open the CSV file for schema detection, and
    build the virtual table state.

    The file is opened **once** at connect time only to determine column names
    and the byte offset of the first data row (``data_start_offset``). No row
    data is retained in ``CsvState``; rows are streamed on demand by each
    cursor at query time.

    Supported arguments (``argv[2+]``):

    - ``filename=PATH`` — path to the CSV file (required).
    - ``header=yes|no`` — first row is a header row (default: ``no``).
    - ``delimiter=C`` — single-character field delimiter (default: ``,``).
    - ``quote=C`` — single-character quote char (default: ``"``);
      use ``0`` to disable quoting.
    - ``columns=N`` — explicit column count (alternative to ``header``).
    - ``schema=SQL`` — explicit ``CREATE TABLE`` SQL (skips auto-generation).

    Args:
        db: The SQLite database connection (supplied by SQLite).
        aux: Auxiliary pointer from the module registration (unused).
        module_name: Name of the virtual table module (e.g. "csv").
        database_name: Name of the database (e.g. "main").
        table_name: Name of the virtual table being created.
        argv: User supplied args to the module.

    Returns:
        A ``VTabConnectResult[CsvState]`` with the schema SQL and vtab state.

    Raises:
        Error: If ``filename`` is missing, the file cannot be opened, a
               parameter value is invalid, or columns cannot be determined.
    """
    var filename = String()
    var has_headers = False
    var delimiter = UInt8(44)  # ','
    var quote = UInt8(34)  # '"'
    var n_col: Optional[Int] = None
    var schema: Optional[String] = None

    # Parse key=value arguments. argv[0] = module name, argv[1] = db name,
    # argv[2] = table name, argv[3+] = user-supplied arguments.
    for i in range(len(argv)):
        var raw_arg = argv[i]
        var eq_idx = raw_arg.find("=")
        if eq_idx < 0:
            raise Error(t"Illegal argument: '{raw_arg}'")
        var raw_bytes = raw_arg.as_bytes()
        var key_bytes = List[UInt8]()
        for bi in range(eq_idx):
            key_bytes.append(raw_bytes[bi])
        key_bytes.append(UInt8(0))
        var key = String(
            String(
                StringSlice(
                    unsafe_from_utf8_ptr=key_bytes.unsafe_ptr().bitcast[c_char]()
                )
            ).strip()
        )
        var val_bytes = List[UInt8]()
        for bi in range(eq_idx + 1, raw_arg.byte_length()):
            val_bytes.append(raw_bytes[bi])
        val_bytes.append(UInt8(0))
        var raw_val = String(
            StringSlice(
                unsafe_from_utf8_ptr=val_bytes.unsafe_ptr().bitcast[c_char]()
            )
        ).strip()
        var val = _dequote(String(raw_val))

        if key == "filename":
            filename = val
        elif key == "schema":
            schema = val
        elif key == "columns":
            try:
                var n = atol(val)
                if n <= 0:
                    raise Error("'columns' must be a positive integer, got: " + val)
                n_col = Int(n)
            except:
                raise Error("unrecognized argument to 'columns': " + val)
        elif key == "header":
            var b = _parse_boolean(val)
            if b:
                has_headers = b.value()
            else:
                raise Error("unrecognized argument to 'header': " + val)
        elif key == "delimiter":
            if val.byte_length() == 1:
                delimiter = val.as_bytes()[0]
            else:
                raise Error("unrecognized argument to 'delimiter': " + val)
        elif key == "quote":
            if val.byte_length() == 1:
                var q = val.as_bytes()[0]
                quote = UInt8(0) if q == UInt8(48) else q
            else:
                raise Error("unrecognized argument to 'quote': " + val)
        else:
            raise Error("unrecognized parameter '" + key + "'")

    if filename.byte_length() == 0:
        raise Error("no CSV file specified")

    # Open the CSV file to determine schema and data_start_offset.
    # Use as_c_string_slice().unsafe_ptr() — the same pattern as the rest of the
    # bindings — so fopen receives typed ImmutUnsafePointer[c_char] args.  This
    # prevents LLVM from dead-store-eliminating the string buffer contents in
    # AOT-compiled code (unlike passing the pointer cast to Int).
    var open_mode = String("r")
    var fp = fopen(
        filename.as_c_string_slice().unsafe_ptr(),
        open_mode.as_c_string_slice().unsafe_ptr(),
    )
    if fp == 0:
        raise Error("cannot open CSV file: " + filename)

    var col_names = List[String]()
    var data_start_offset: Int

    if has_headers:
        # Read the header row to derive column names.
        var header_row = _read_row_from_fp(fp, delimiter, quote)
        if not header_row:
            _ = fclose(fp)
            raise Error("CSV file is empty (no header row found): " + filename)
        var header = header_row.value().copy()
        for j in range(len(header)):
            col_names.append(_escape_double_quotes(header[j]))
        # Record the byte position immediately after the header row; each
        # cursor will seek here before streaming data rows.
        data_start_offset = ftell(fp)
        _ = fclose(fp)
    else:
        data_start_offset = 0
        if n_col:
            var nc = n_col.value()
            for j in range(nc):
                col_names.append("c" + String(j))
            _ = fclose(fp)
        elif not schema:
            # Infer column count from the first data row.
            var first_row = _read_row_from_fp(fp, delimiter, quote)
            _ = fclose(fp)
            if not first_row:
                raise Error(
                    "CSV file is empty (cannot determine column count): "
                    + filename
                )
            var nc = len(first_row.value())
            for j in range(nc):
                col_names.append("c" + String(j))
            # data_start_offset stays 0: the first row is data, not a header.
        else:
            _ = fclose(fp)

    # Build the CREATE TABLE schema if not provided explicitly.
    var schema_sql: String
    if schema:
        schema_sql = schema.value()
    else:
        if len(col_names) == 0:
            raise Error(
                "no columns specified and schema could not be determined"
            )
        var sql = String("CREATE TABLE x(")
        for j in range(len(col_names)):
            sql += "\""
            sql += col_names[j]
            sql += "\" TEXT"
            if j < len(col_names) - 1:
                sql += ", "
        sql += ");"
        schema_sql = sql^

    var vtab = CsvState(
        filename=filename^,
        has_headers=has_headers,
        delimiter=delimiter,
        quote=quote,
        n_cols=len(col_names),
        data_start_offset=data_start_offset,
    )

    return VTabConnectResult[CsvState](
        schema=schema_sql^,
        vtab=vtab^,
    )


# ===----------------------------------------------------------------------=== #
# xBestIndex
# ===----------------------------------------------------------------------=== #


def csv_best_index(
    vtab: MutExternalPointer[CsvState],
    index_info: MutExternalPointer[sqlite3_index_info],
) raises -> Bool:
    """Declare a full-table scan as the only supported query plan.

    Sets a large estimated cost so the query planner does not try to
    optimise scans using non-existent indexes.

    Args:
        vtab: Pointer to the virtual table state (not used).
        index_info: The SQLite index-information structure to fill in.

    Returns:
        ``False`` — output order does not match any index.
    """
    index_info[].estimatedCost = 1_000_000.0
    return False


# ===----------------------------------------------------------------------=== #
# xOpen
# ===----------------------------------------------------------------------=== #


def csv_open(vtab: MutExternalPointer[CsvState]) raises -> CsvCursor:
    """Create a new cursor from the vtab's connection metadata.

    The cursor does not open a file here; the file is opened lazily in
    ``csv_filter`` so that multiple ``SELECT`` statements on the same table
    each get a fresh file handle positioned at the first data row.

    Args:
        vtab: Pointer to the shared virtual table state.

    Returns:
        A new ``CsvCursor`` ready to be initialised by ``csv_filter``.
    """
    return CsvCursor(
        filename=vtab[].filename,
        data_start_offset=vtab[].data_start_offset,
        delimiter=vtab[].delimiter,
        quote=vtab[].quote,
    )


# ===----------------------------------------------------------------------=== #
# xFilter
# ===----------------------------------------------------------------------=== #


def _csv_advance(cursor: MutExternalPointer[CsvCursor]) raises:
    """Read the next row from the file into ``cursor[].current_row``.

    Sets ``cursor[].eof = True`` when there are no more rows.

    Args:
        cursor: Pointer to the cursor whose file handle to advance.
    """
    var maybe_row = _read_row_from_fp(
        cursor[].fp, cursor[].delimiter, cursor[].quote
    )
    if maybe_row:
        var row = maybe_row.value().copy()
        cursor[].current_row = row^
        cursor[].row_number += 1
        cursor[].eof = False
    else:
        cursor[].current_row = List[String]()
        cursor[].eof = True


def csv_filter(
    cursor: MutExternalPointer[CsvCursor],
    idx_num: c_int,
    idx_str: Optional[StringSlice[ImmutExternalOrigin]],
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    argc: c_int,
) raises:
    """Begin a full-table scan by opening the file and reading the first row.

    Closes any previously open file handle, re-opens the CSV file, seeks to
    ``data_start_offset`` (past the header row when present), and reads the
    first data row into ``cursor[].current_row``.

    Args:
        cursor: Pointer to the cursor state to reset.
        idx_num: Index number selected by ``xBestIndex`` (unused).
        idx_str: Index string selected by ``xBestIndex`` (unused).
        argv: Constraint values from the query planner (unused for full scan).
        argc: Number of constraint values (unused).
    """
    # Close any file handle from a previous scan.
    if cursor[].fp != 0:
        _ = fclose(cursor[].fp)
        cursor[].fp = 0

    # Open a fresh file handle.  See csv_connect for the as_c_string_slice()
    # pattern rationale.
    var xf_open_mode = String("r")
    var fp = fopen(
        cursor[].filename.as_c_string_slice().unsafe_ptr(),
        xf_open_mode.as_c_string_slice().unsafe_ptr(),
    )
    if fp == 0:
        raise Error("cannot open CSV file: " + cursor[].filename)
    cursor[].fp = fp

    # Seek past the header row (data_start_offset == 0 for headerless files).
    if cursor[].data_start_offset > 0:
        _ = fseek(fp, cursor[].data_start_offset, SEEK_SET)

    # Reset row counter and read the first data row.
    cursor[].row_number = 0
    cursor[].current_row = List[String]()
    cursor[].eof = False
    _csv_advance(cursor)


# ===----------------------------------------------------------------------=== #
# xNext
# ===----------------------------------------------------------------------=== #


def csv_next(cursor: MutExternalPointer[CsvCursor]) raises:
    """Advance the cursor to the next row by reading from the file.

    Sets ``eof = True`` when there are no more rows.

    Args:
        cursor: Pointer to the cursor state to advance.
    """
    _csv_advance(cursor)


# ===----------------------------------------------------------------------=== #
# xEof
# ===----------------------------------------------------------------------=== #


def csv_eof(cursor: MutExternalPointer[CsvCursor]) -> Bool:
    """Return ``True`` if the cursor has no more rows.

    Args:
        cursor: Pointer to the cursor state.

    Returns:
        ``True`` when the scan is complete.
    """
    return cursor[].eof


# ===----------------------------------------------------------------------=== #
# xColumn
# ===----------------------------------------------------------------------=== #


def csv_column(
    cursor: MutExternalPointer[CsvCursor],
    ctx: Context,
    col: c_int,
) raises:
    """Return the value of column ``col`` from the current row as TEXT.

    Returns SQL ``NULL`` if the column index is out of range or the cursor
    is at EOF.

    Args:
        cursor: Pointer to the cursor state.
        ctx: The SQLite function context used to set the return value.
        col: 0-based column index.
    """
    if cursor[].eof:
        ctx.result_null()
        return
    var col_idx = Int(col)
    if col_idx < 0 or col_idx >= len(cursor[].current_row):
        ctx.result_null()
        return
    ctx.result_text(cursor[].current_row[col_idx])


# ===----------------------------------------------------------------------=== #
# xRowid
# ===----------------------------------------------------------------------=== #


def csv_rowid(cursor: MutExternalPointer[CsvCursor]) raises -> Int64:
    """Return the current 1-based row number as the rowid.

    Args:
        cursor: Pointer to the cursor state.

    Returns:
        The 1-based index of the current row.
    """
    return Int64(cursor[].row_number)


# ===----------------------------------------------------------------------=== #
# Module registration
# ===----------------------------------------------------------------------=== #


def load_module(conn: Connection) raises:
    """Register the ``csv`` virtual table module with a database connection.

    After calling this function, the connection supports creating CSV virtual
    tables::

        CREATE VIRTUAL TABLE my_data USING csv(filename='data.csv', header=yes);
        SELECT * FROM my_data;

    Args:
        conn: The database connection to register the module with.

    Raises:
        Error: If the module could not be registered.
    """
    conn.create_module[
        CsvState,
        CsvCursor,
        csv_connect,
        csv_best_index,
        csv_open,
        csv_filter,
        csv_next,
        csv_eof,
        csv_column,
        csv_rowid,
    ]("csv")
