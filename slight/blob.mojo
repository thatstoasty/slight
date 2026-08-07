"""Incremental BLOB I/O.

This module defines the `Blob` struct, a handle for reading and writing a
BLOB value in a database row incrementally, without loading the entire value
into memory.

See the official documentation for more information:
- https://www.sqlite.org/c3ref/blob_open.html
"""

from std.sys import stderr
from slight.c.types import MutExternalPointer, sqlite3_blob
from slight.connection import Connection


@explicit_destroy("You must call `.close()` to close the BLOB before the `Blob` is destroyed.")
struct Blob[conn_origin: MutOrigin, read_only: Bool = False](Movable, Sized, Deinitable where False):
    """A handle for incremental BLOB I/O, allowing a BLOB value to be read
    or written in chunks without loading the entire value into memory.

    Parameters:
        conn_origin: The mutable origin of the connection that opened this BLOB.
        read_only: If True, opens the BLOB for reading only. If False, opens the BLOB for reading and writing.

    #### Note:

    The `Blob` owns the underlying `sqlite3_blob*` and closes it
    automatically when it goes out of scope. Use `.close()` to close the
    BLOB explicitly and observe any error that occurs while doing so.

    #### Example:

    ```mojo
    from slight import Connection

    def read_blob(mut conn: Connection) raises:
        var blob = conn.blob_open("images", "data", row_id=1)
        var buf = List[Byte](length=len(blob), fill=0)
        try:
            blob.read(buf)
        finally:
            blob^.close()
    ```
    """

    var conn: Pointer[Connection, Self.conn_origin]
    """A pointer to the connection that opened this BLOB."""
    var handle: MutExternalPointer[sqlite3_blob]
    """The underlying BLOB handle."""

    def __init__(
        out self,
        conn: Pointer[Connection, Self.conn_origin],
        var table: String,
        var column: String,
        row_id: Int64,
        *,
        var schema: String = "main",
    ) raises:
        """Opens a BLOB for incremental I/O.

        Args:
            conn: A pointer to the connection to open the BLOB on.
            table: Name of the table containing the BLOB.
            column: Name of the column containing the BLOB.
            row_id: Row ID of the row containing the BLOB.
            schema: Name of the database schema containing the table
                (e.g. "main").

        Raises:
            Error: If the BLOB could not be opened.
        """
        self.conn = conn
        self.handle = conn[].db.blob_open(
            table^, column^, row_id, read_only=Self.read_only, schema=schema^
        )

    def __len__(self) -> Int:
        """Returns the size of the BLOB in bytes.

        Returns:
            The size of the BLOB in bytes.
        """
        return self.conn[].db.blob_bytes(self.handle)

    def read(self, mut buffer: List[Byte], offset: Int = 0) raises:
        """Reads data from the BLOB incrementally into `buffer`.

        The number of bytes read is determined by `len(buffer)`.

        Args:
            buffer: The buffer to read data into.
            offset: The offset within the BLOB to start reading from.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn[].db.blob_read(self.handle, buffer, offset)

    def read(self, n: Int, offset: Int = 0) raises -> List[Byte]:
        """Reads `n` bytes of data from the BLOB, starting at `offset`.

        Args:
            n: The number of bytes to read.
            offset: The offset within the BLOB to start reading from.

        Returns:
            The bytes read from the BLOB.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        var buffer = List[Byte](length=n, fill=0)
        self.read(buffer, offset)
        return buffer^

    # Self doesn't need to be Mut since it carries a mutable pointer.
    # But we're altering the blob, so self being borrow immutably is wrong.
    def write(mut self, data: Span[Byte, ...], offset: Int = 0) raises where
        not Self.read_only:
        """Writes data into the BLOB incrementally.

        The BLOB must have been opened with `read_only=False`.

        Args:
            data: The bytes to write into the BLOB.
            offset: The offset within the BLOB to start writing at.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn[].db.blob_write(self.handle, data, offset)

    def reopen(self, row_id: Int64) raises:
        """Moves this BLOB handle to point to a different row of the same
        database table.

        This is faster than closing and reopening the BLOB handle. The new
        row must contain a BLOB or TEXT value in the same column.

        Args:
            row_id: The row ID of the new row.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        self.conn[].db.blob_reopen(self.handle, row_id)

    def close(deinit self) raises:
        """Closes the BLOB handle, committing any changes made via `write()`.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        var rc = self.conn[].db.blob_close(self.handle)
        self.conn[].raise_if_error(rc)
