"""Online Backup API.

This module defines the `Backup` struct, a handle for performing an online
backup of one database connection into another using SQLite's incremental
backup API.

See the official documentation for more information:
- https://www.sqlite.org/backup.html
- https://www.sqlite.org/c3ref/backup_finish.html
"""

from slight.c.types import MutExternalPointer, sqlite3_backup
from slight.connection import Connection
from slight.result import SQLite3Result


@explicit_destroy("You must call `.finish()` to finish the backup before the `Backup` is destroyed.")
struct Backup[dest_origin: MutOrigin, source_origin: MutOrigin](Deinitable where False, Movable):
    """A handle to an in-progress online backup operation, copying the
    contents of one database connection into another.

    Parameters:
        dest_origin: The mutable origin of the destination connection.
        source_origin: The mutable origin of the source connection.

    #### Note:

    The `Backup` owns the underlying `sqlite3_backup*` and finishes it
    automatically when it goes out of scope. Use `.finish()` to finish the
    backup explicitly and observe any error that occurs while doing so.

    #### Example:

    ```mojo
    from slight import Connection

    def perform_backup(mut source: Connection, mut dest: Connection) raises:
        var backup = source.backup(dest)
        try:
            while backup.step(5):
                pass
        finally:
            backup^.finish()
    ```
    """

    var dest: Pointer[Connection, Self.dest_origin]
    """A pointer to the destination connection."""
    var source: Pointer[Connection, Self.source_origin]
    """A pointer to the source connection."""
    var handle: MutExternalPointer[sqlite3_backup]
    """The underlying backup handle."""

    def __init__(
        out self,
        dest: Pointer[Connection, Self.dest_origin],
        source: Pointer[Connection, Self.source_origin],
        var dest_schema: String = "main",
        var source_schema: String = "main",
    ) raises:
        """Initializes a new backup operation.

        Args:
            dest: A pointer to the destination connection.
            source: A pointer to the source connection.
            dest_schema: Name of the destination database schema (e.g. "main").
            source_schema: Name of the source database schema (e.g. "main").

        Raises:
            Error: If the backup operation could not be initialized.
        """
        self.dest = dest
        self.source = source
        self.handle = source[].db.backup_init(dest[].db, dest_schema^, source_schema^)

    def step(mut self, n_pages: Int = -1) raises -> Bool:
        """Copies up to `n_pages` pages from the source database to the
        destination database.

        Args:
            n_pages: The number of pages to copy, or -1 to copy all remaining
                pages in a single call.

        Returns:
            True if more pages remain to be copied, False if the backup is
            complete.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        var rc = self.source[].db.backup_step(self.handle, n_pages)
        if rc == SQLite3Result.DONE:
            return False
        elif rc == SQLite3Result.OK:
            return True
        else:
            raise self.dest[].decode_error(rc)

    def remaining(self) -> Int:
        """Returns the number of pages still to be backed up.

        Returns:
            The number of pages remaining to be copied, as of the most
            recent call to `step()`.
        """
        return self.source[].db.backup_remaining(self.handle)

    def page_count(self) -> Int:
        """Returns the total number of pages in the source database.

        Returns:
            The total number of pages in the source database, as of the most
            recent call to `step()`.
        """
        return self.source[].db.backup_page_count(self.handle)

    def finish(deinit self) raises:
        """Finishes the backup operation and releases the backup handle.

        Raises:
            Error: If the underlying SQLite call fails.
        """
        var rc = self.source[].db.backup_finish(self.handle)
        self.dest[].raise_if_error(rc)
