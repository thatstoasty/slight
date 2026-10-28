"""Write-Ahead Log Checkpoint Modes.

This module defines the `CheckpointMode` enum representing the checkpoint
modes accepted by `sqlite3_wal_checkpoint_v2`, for use with
`Connection.wal_checkpoint_v2()`.

See the official documentation for more information:
- https://www.sqlite.org/c3ref/wal_checkpoint_v2.html
"""


__enum CheckpointMode(Equatable, ImplicitlyCopyable, Writable):
    """Checkpoint modes for `Connection.wal_checkpoint_v2()`.

    Each case corresponds to a `SQLITE_CHECKPOINT_*` constant from the
    SQLite C API; see `code()`.
    """

    case passive
    """Checkpoint as many frames as possible without waiting for any database
    readers or writers to finish, then sync the database file if all frames
    in the log were checkpointed. This mode is the same as calling
    `sqlite3_wal_checkpoint()`."""

    case full
    """This mode blocks (calls the busy-handler callback) until there is no
    database writer and all readers are reading from the most recent database
    snapshot. It then checkpoints all frames in the log file and syncs the
    database file. This mode blocks new database writers while it is
    pending, but new database readers are allowed to continue unimpeded."""

    case restart
    """This mode works the same way as `full` with the addition that after
    checkpointing the log file it blocks (calls the busy-handler callback)
    until all readers are reading from the database file only. This ensures
    that the next writer will restart the log file from the beginning.
    This mode blocks new database writer attempts while it is pending, but
    does not impede readers."""

    case truncate
    """This mode works the same way as `restart` with the addition that the
    WAL file is truncated to zero bytes upon successful completion."""

    def code(self) -> Int32:
        """Returns the raw `SQLITE_CHECKPOINT_*` code.

        Returns:
            The integer code SQLite uses for this checkpoint mode.
        """
        match self:
            case .passive:
                return 0
            case .full:
                return 1
            case .restart:
                return 2
            case .truncate:
                return 3

    def __eq__(self, other: Self) -> Bool:
        """Checks if two checkpoint modes are the same.

        Args:
            other: The checkpoint mode to compare against.

        Returns:
            True if both are the same mode, False otherwise.
        """
        return self.code() == other.code()

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        match self:
            case .passive:
                writer.write("SQLITE_CHECKPOINT_PASSIVE")
            case .full:
                writer.write("SQLITE_CHECKPOINT_FULL")
            case .restart:
                writer.write("SQLITE_CHECKPOINT_RESTART")
            case .truncate:
                writer.write("SQLITE_CHECKPOINT_TRUNCATE")
