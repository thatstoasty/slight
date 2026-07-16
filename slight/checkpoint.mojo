"""Write-Ahead Log Checkpoint Modes.

This module defines the `CheckpointMode` struct representing the checkpoint
modes accepted by `sqlite3_wal_checkpoint_v2`, for use with
`Connection.wal_checkpoint_v2()`.

See the official documentation for more information:
- https://www.sqlite.org/c3ref/wal_checkpoint_v2.html
"""


@fieldwise_init
struct CheckpointMode(Equatable, TrivialRegisterPassable, Writable):
    """Checkpoint modes for `Connection.wal_checkpoint_v2()`.

    Each variant corresponds to a `SQLITE_CHECKPOINT_*` constant from the
    SQLite C API.
    """

    var value: Int32
    """The integer value of the checkpoint mode."""

    comptime PASSIVE = Self(0)
    """Checkpoint as many frames as possible without waiting for any database
    readers or writers to finish, then sync the database file if all frames
    in the log were checkpointed. This mode is the same as calling
    `sqlite3_wal_checkpoint()`."""

    comptime FULL = Self(1)
    """This mode blocks (calls the busy-handler callback) until there is no
    database writer and all readers are reading from the most recent database
    snapshot. It then checkpoints all frames in the log file and syncs the
    database file. This mode blocks new database writers while it is
    pending, but new database readers are allowed to continue unimpeded."""

    comptime RESTART = Self(2)
    """This mode works the same way as `FULL` with the addition that after
    checkpointing the log file it blocks (calls the busy-handler callback)
    until all readers are reading from the database file only. This ensures
    that the next writer will restart the log file from the beginning.
    This mode blocks new database writer attempts while it is pending, but
    does not impede readers."""

    comptime TRUNCATE = Self(3)
    """This mode works the same way as `RESTART` with the addition that the
    WAL file is truncated to zero bytes upon successful completion."""

    def __eq__(self, other: Self) -> Bool:
        """Check if two values are equal.

        Args:
            other: The other value to compare against.

        Returns:
            True if the values are equal, False otherwise.
        """
        return self.value == other.value

    def write_to(self, mut writer: Some[Writer]):
        """Write a human-readable representation.

        Args:
            writer: The writer to write to.
        """
        if self.value == Self.PASSIVE.value:
            writer.write("SQLITE_CHECKPOINT_PASSIVE")
        elif self.value == Self.FULL.value:
            writer.write("SQLITE_CHECKPOINT_FULL")
        elif self.value == Self.RESTART.value:
            writer.write("SQLITE_CHECKPOINT_RESTART")
        elif self.value == Self.TRUNCATE.value:
            writer.write("SQLITE_CHECKPOINT_TRUNCATE")
        else:
            writer.write(t"SQLITE_CHECKPOINT_UNKNOWN({self.value})")
