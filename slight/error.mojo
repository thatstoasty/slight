from slight.api import sqlite_ffi
from slight.inner_connection import InnerConnection
from slight.result import SQLite3Result


def error_msg(db: InnerConnection, code: SQLite3Result) -> Optional[String]:
    """Checks for the error message set in sqlite3, or what the description of the provided code is.

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The SQLite error code.

    Returns:
        An optional string slice containing the error message, or None if not found.
    """
    if sqlite_ffi()[].errcode(db.db) != code:
        var ptr = sqlite_ffi()[].errstr(code.value)
        if not ptr:
            return None
        return String(unsafe_from_utf8_ptr=ptr.value())

    var ptr = sqlite_ffi()[].errmsg(db.db)
    if not ptr:
        return None
    return String(unsafe_from_utf8_ptr=ptr.value())


def raise_if_error(db: InnerConnection, code: SQLite3Result) raises:
    """Raises if the SQLite error code is not `SQLITE_OK`.

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The SQLite error code.

    Raises:
        Error: If the SQLite error code is not `SQLITE_OK`.
    """
    if SQLite3Result.OK == code:
        return

    raise Error(error_from_sqlite_code(code, error_msg(db, code)))


def decode_error(db: InnerConnection, code: SQLite3Result) -> Error:
    """Returns an Error if the SQLite error code is not `SQLITE_OK`.

    Args:
        db: The raw sqlite3 database connection pointer.
        code: The SQLite error code.

    Returns:
        Error: If the SQLite error code is not `SQLITE_OK`.
    """
    return Error(error_from_sqlite_code(code, error_msg(db, code)))


def error_from_sqlite_code(code: SQLite3Result, msg: Optional[String]) -> String:
    """Constructs an error message from the SQLite error code and message.

    Args:
        code: The SQLite error code.
        msg: An optional string slice containing the error message.

    Returns:
        A string containing the formatted error message.
    """
    if msg:
        return String(t"sqlite3 Error ({code.value}): {msg.value()}")
    return String(t"sqlite3 Error ({code.value}): Unknown error has occurred. The provided code was invalid and could not get the error via sqlite3 handle.")
