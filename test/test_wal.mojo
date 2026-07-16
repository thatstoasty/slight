"""Tests for Connection.wal_checkpoint / Connection.wal_checkpoint_v2.

WAL mode requires a real file on disk (it does not apply to in-memory
databases), so these tests use a temporary directory.
"""

from std import tempfile
from std.pathlib import Path
from std.testing import assert_equal, assert_true, TestSuite

from slight import Connection, Int, Row
from slight.checkpoint import CheckpointMode


def test_wal_checkpoint_passive() raises:
    """A passive checkpoint should succeed after some writes in WAL mode."""
    with tempfile.TemporaryDirectory() as tmp:
        var path = Path(tmp) / "wal_passive.db"
        var db = Connection.open(path)
        db.execute_batch("PRAGMA journal_mode=WAL")
        db.execute_batch("CREATE TABLE t (value INTEGER)")
        for i in range(50):
            _ = db.execute("INSERT INTO t (value) VALUES (?1)", (i,))

        db.wal_checkpoint()

        def get_count(r: Row) raises -> Int:
            return r.get[Int](0)

        assert_equal(db.one_row[get_count]("SELECT COUNT(*) FROM t"), 50)


def test_wal_checkpoint_v2_returns_sane_frame_counts() raises:
    """`wal_checkpoint_v2()` should return non-negative frame counts."""
    with tempfile.TemporaryDirectory() as tmp:
        var path = Path(tmp) / "wal_v2.db"
        var db = Connection.open(path)
        db.execute_batch("PRAGMA journal_mode=WAL")
        db.execute_batch("CREATE TABLE t (value INTEGER)")
        for i in range(50):
            _ = db.execute("INSERT INTO t (value) VALUES (?1)", (i,))

        var log_frames, checkpointed_frames = db.wal_checkpoint_v2(CheckpointMode.FULL)

        assert_true(log_frames >= 0)
        assert_true(checkpointed_frames >= 0)
        assert_true(checkpointed_frames <= log_frames)


def test_wal_checkpoint_v2_truncate_mode() raises:
    """TRUNCATE mode checkpoints should also succeed without error."""
    with tempfile.TemporaryDirectory() as tmp:
        var path = Path(tmp) / "wal_truncate.db"
        var db = Connection.open(path)
        db.execute_batch("PRAGMA journal_mode=WAL")
        db.execute_batch("CREATE TABLE t (value INTEGER)")
        _ = db.execute("INSERT INTO t (value) VALUES (?1)", (1,))

        var log_frames, checkpointed_frames = db.wal_checkpoint_v2(CheckpointMode.TRUNCATE)
        assert_true(log_frames >= 0)
        assert_true(checkpointed_frames >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
