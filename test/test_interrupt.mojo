"""Tests for Connection.interrupt / Connection.is_interrupted."""

from std.testing import assert_false, TestSuite

from slight import Connection


def test_is_interrupted_initially_false() raises:
    """A fresh connection should not have a pending interrupt."""
    var db = Connection.open_in_memory()
    assert_false(db.is_interrupted())


def test_interrupt_is_callable() raises:
    """Calling interrupt() should not raise, even with no query running."""
    var db = Connection.open_in_memory()
    db.interrupt()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
