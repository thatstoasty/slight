"""CSV Virtual Table for slight/SQLite.

Provides a read-only virtual table that exposes a CSV file as an SQL table.

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
from std.pathlib import Path
from slight.c.types import (
    ImmutExternalOrigin,
    MutExternalPointer,
    sqlite3_connection,
    sqlite3_index_info,
    sqlite3_value,
)
from slight.connection import Connection
from slight.context import Context
from slight.vtab import (
    VTabConnectFn,
    VTabBestIndexFn,
    VTabOpenFn,
    VTabFilterFn,
    VTabNextFn,
    VTabEofFn,
    VTabColumnFn,
    VTabRowidFn,
    VTabConnectResult,
)


# ===----------------------------------------------------------------------=== #
# Virtual table / cursor state structs
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct CsvState(Movable):
    """State shared across all cursors for a given CSV virtual table instance."""

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

    var rows: List[List[String]]
    """All data rows parsed from the CSV file (header excluded when has_headers)."""


@fieldwise_init
struct CsvCursor(Movable):
    """Cursor state for iterating over CSV rows."""

    var rows: List[List[String]]
    """All data rows (shallow copy from the vtab at open time)."""

    var row_idx: Int
    """Current 0-based row index into rows."""

    var eof: Bool
    """True when the cursor has consumed all rows."""


# ===----------------------------------------------------------------------=== #
# CSV parsing helpers
# ===----------------------------------------------------------------------=== #


def _parse_csv(
    content: String,
    delimiter: UInt8,
    quote: UInt8,
) -> List[List[String]]:
    """Parse CSV content into a list of rows.

    Handles CRLF and LF line endings. Quoted fields (enclosed by ``quote``)
    may contain the delimiter or embedded newlines. Doubled quote characters
    inside a quoted field are treated as an escaped single quote.

    Args:
        content: Full CSV file content.
        delimiter: Field separator byte (e.g. 44 for ``,``).
        quote: Quote character byte (e.g. 34 for ``"``); 0 disables quoting.

    Returns:
        A list of rows; each row is a list of field strings.
    """
    var rows = List[List[String]]()
    var n = content.byte_length()
    if n == 0:
        return rows^
    var raw = content.unsafe_ptr().bitcast[UInt8]()
    var i = 0

    while i < n:
        var row = List[String]()

        # Parse fields for one row (ends at LF, CRLF, or EOF).
        while True:
            var field_bytes = List[UInt8]()

            # --- parse one field ---
            if i < n and quote != UInt8(0) and raw[i] == quote:
                # Quoted field: read until the closing quote.
                i += 1
                while i < n:
                    var b = raw[i]
                    if b == quote:
                        # Doubled quote inside field → literal quote char.
                        if i + 1 < n and raw[i + 1] == quote:
                            field_bytes.append(b)
                            i += 2
                        else:
                            i += 1
                            break  # end of quoted field
                    else:
                        field_bytes.append(b)
                        i += 1
            else:
                # Unquoted field: read until delimiter, CR, or LF.
                while i < n:
                    var b = raw[i]
                    if b == delimiter or b == UInt8(10) or b == UInt8(13):
                        break
                    field_bytes.append(b)
                    i += 1

            # Build a String from the accumulated bytes (null-terminate first).
            field_bytes.append(UInt8(0))
            row.append(
                String(
                    StringSlice(
                        unsafe_from_utf8_ptr=field_bytes.unsafe_ptr().bitcast[c_char]()
                    )
                )
            )

            # --- determine what follows the field ---
            if i >= n:
                break  # EOF: end of last row
            var sep = raw[i]
            if sep == delimiter:
                i += 1
                continue  # next field in the same row
            elif sep == UInt8(13):  # CR or CRLF
                i += 1
                if i < n and raw[i] == UInt8(10):
                    i += 1
                break
            elif sep == UInt8(10):  # LF
                i += 1
                break

        if len(row) > 0:
            rows.append(row^)

    return rows^


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
    return String(
        StringSlice(
            unsafe_from_utf8_ptr=inner.unsafe_ptr().bitcast[c_char]()
        )
    )


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
    db: MutExternalPointer[sqlite3_connection],
    argv: List[String],
) raises -> VTabConnectResult[CsvState]:
    """Parse module arguments, read the CSV file, and build the virtual table.

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
        argv: Module arguments; ``argv[0]`` = module name,
              ``argv[1]`` = database name, ``argv[2]`` = table name,
              ``argv[3+]`` = user-supplied args.

    Returns:
        A ``VTabConnectResult[CsvState]`` with the schema SQL and vtab state.

    Raises:
        Error: If ``filename`` is missing, the file cannot be read, a
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
    for i in range(3, len(argv)):
        var raw_arg = argv[i]
        # Split on first '=': collect chars before and after the '=' separator.
        var eq_idx = raw_arg.find("=")
        if eq_idx < 0:
            raise Error("illegal argument: '" + raw_arg + "'")
        # Build key bytes.
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
        # Build value bytes (everything after '=').
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
                # The character literal '0' (ASCII 48) means "disable quoting".
                quote = UInt8(0) if q == UInt8(48) else q
            else:
                raise Error("unrecognized argument to 'quote': " + val)
        else:
            raise Error("unrecognized parameter '" + key + "'")

    if filename.byte_length() == 0:
        raise Error("no CSV file specified")

    # Read and parse the CSV file.
    var content = Path(filename).read_text()
    var all_rows = _parse_csv(content, delimiter, quote)

    # Determine column names and the index of the first data row.
    var col_names = List[String]()
    var data_start = 0

    if has_headers:
        if len(all_rows) == 0:
            raise Error("CSV file is empty (no header row found): " + filename)
        var header = all_rows[0].copy()
        for j in range(len(header)):
            col_names.append(_escape_double_quotes(header[j]))
        data_start = 1
    elif n_col:
        var nc = n_col.value()
        for j in range(nc):
            col_names.append("c" + String(j))
    elif not schema:
        # No headers, no explicit columns, no explicit schema:
        # count columns from the first data row.
        if len(all_rows) == 0:
            raise Error(
                "CSV file is empty (cannot determine column count): " + filename
            )
        var nc = len(all_rows[0])
        for j in range(nc):
            col_names.append("c" + String(j))

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

    # Collect data rows (skip the header row when has_headers).
    var rows = List[List[String]]()
    for j in range(data_start, len(all_rows)):
        rows.append(all_rows[j].copy())

    var vtab = CsvState(
        filename=filename^,
        has_headers=has_headers,
        delimiter=delimiter,
        quote=quote,
        n_cols=len(col_names),
        rows=rows^,
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
    """Create a new cursor positioned before the first row.

    Copies the row data from the vtab at open time so the cursor is
    self-contained and does not need to hold a pointer back to the vtab.

    Args:
        vtab: Pointer to the shared virtual table state.

    Returns:
        A new ``CsvCursor`` ready to be initialised by ``csv_filter``.
    """
    return CsvCursor(rows=vtab[].rows.copy(), row_idx=0, eof=True)


# ===----------------------------------------------------------------------=== #
# xFilter
# ===----------------------------------------------------------------------=== #


def csv_filter(
    cursor: MutExternalPointer[CsvCursor],
    idx_num: c_int,
    idx_str: Optional[StringSlice[ImmutExternalOrigin]],
    argv: MutExternalPointer[MutExternalPointer[sqlite3_value]],
    argc: c_int,
) raises:
    """Begin a full-table scan by resetting the cursor to the first data row.

    Args:
        cursor: Pointer to the cursor state to reset.
        idx_num: Index number selected by ``xBestIndex`` (unused).
        idx_str: Index string selected by ``xBestIndex`` (unused).
        argv: Constraint values from the query planner (unused for full scan).
        argc: Number of constraint values (unused).
    """
    cursor[].row_idx = 0
    cursor[].eof = len(cursor[].rows) == 0


# ===----------------------------------------------------------------------=== #
# xNext
# ===----------------------------------------------------------------------=== #


def csv_next(cursor: MutExternalPointer[CsvCursor]) raises:
    """Advance the cursor to the next row.

    Sets ``eof = True`` when there are no more rows.

    Args:
        cursor: Pointer to the cursor state to advance.
    """
    cursor[].row_idx += 1
    cursor[].eof = cursor[].row_idx >= len(cursor[].rows)


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

    Returns SQL ``NULL`` if the column index is out of range.

    Args:
        cursor: Pointer to the cursor state.
        ctx: The SQLite function context used to set the return value.
        col: 0-based column index.
    """
    var row_idx = cursor[].row_idx
    if row_idx < 0 or row_idx >= len(cursor[].rows):
        ctx.result_null()
        return
    var col_idx = Int(col)
    if col_idx < 0 or col_idx >= len(cursor[].rows[row_idx]):
        ctx.result_null()
        return
    ctx.result_text(cursor[].rows[row_idx][col_idx])


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
    return Int64(cursor[].row_idx + 1)


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
