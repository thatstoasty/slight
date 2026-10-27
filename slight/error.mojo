"""Error handling."""
from slight.api import sqlite_ffi
from slight.c.types import MutExternalPointer, sqlite3_connection
from slight.result import SQLite3Result


def error_msg[
    conn_origin: ImmOrigin, //
](db: ImmPointer[sqlite3_connection, conn_origin], code: SQLite3Result) -> Optional[String]:
    """Checks for the error message set in sqlite3, or what the description of the provided code is.

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The SQLite error code.

    Returns:
        An optional string slice containing the error message, or None if not found.
    """
    if sqlite_ffi()[].errcode(db) != code:
        var ptr = sqlite_ffi()[].errstr(code.value)
        if not ptr:
            return None
        return String(unsafe_from_utf8_ptr=ptr.value())

    var ptr = sqlite_ffi()[].errmsg(db)
    if not ptr:
        return None
    return String(unsafe_from_utf8_ptr=ptr.value())


def raise_if_error[
    conn_origin: ImmOrigin, //
](db: ImmPointer[sqlite3_connection, conn_origin], code: SQLite3Result) raises:
    """Raises if the SQLite error code is not `SQLITE_OK`.

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The SQLite error code.

    Raises:
        Error: If the SQLite error code is not `SQLITE_OK`.
    """
    if SQLite3Result.OK == code:
        return

    raise Error(error_from_sqlite_code(_detailed_code(db, code), error_msg(db, code)))


def decode_error[
    conn_origin: ImmOrigin, //
](db: ImmPointer[sqlite3_connection, conn_origin], code: SQLite3Result) -> Error:
    """Returns an Error if the SQLite error code is not `SQLITE_OK`.

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The SQLite error code.

    Returns:
        Error: If the SQLite error code is not `SQLITE_OK`.
    """
    return Error(error_from_sqlite_code(_detailed_code(db, code), error_msg(db, code)))


def _detailed_code[
    conn_origin: ImmOrigin, //
](db: ImmPointer[sqlite3_connection, conn_origin], code: SQLite3Result) -> SQLite3Result:
    """Returns the extended result code for `code` when the connection recorded it.

    SQLite API calls return primary result codes, but the connection keeps the extended code of
    its most recent error (e.g. `SQLITE_CONSTRAINT_UNIQUE` rather than `SQLITE_CONSTRAINT`).

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The result code returned by the failed call.

    Returns:
        The extended code if it belongs to this error, otherwise `code` unchanged.
    """
    if sqlite_ffi()[].errcode(db) == code.value:
        return sqlite_ffi()[].extended_errcode(db)
    return code


def error_from_sqlite_code(code: SQLite3Result, msg: Optional[String]) -> String:
    """Constructs an error message from the SQLite error code and message.

    Args:
        code: The SQLite error code.
        msg: An optional string slice containing the error message.

    Returns:
        A string containing the formatted error message.
    """
    # The primary code comes first so messages still start with e.g. "sqlite3 Error (19"; the name
    # carries the extended code when there is one.
    if msg:
        return String(t"sqlite3 Error ({code.primary().value}, {code.name()}): {msg.value()}")
    return String(
        t"sqlite3 Error ({code.primary().value}, {code.name()}): Unknown error has occurred. The provided code was"
        t" invalid and could not get the error via sqlite3 handle."
    )
