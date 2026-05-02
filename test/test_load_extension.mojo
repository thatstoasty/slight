"""Tests for ExtensionLoadGuard lifecycle and extension loading behavior."""

from std.testing import assert_true, assert_raises, TestSuite

from slight import Connection
from slight.load_extension import ExtensionLoadGuard


def test_enable_extension_loading_returns_guard() raises:
    """Enabling extension loading should return an ExtensionLoadGuard."""
    var conn = Connection.open_in_memory()
    var guard = conn.enable_extension_loading()
    # Guard exists; disable to satisfy @explicit_destroy contract.
    guard^.disable_extension_loading()


def test_load_extension_fails_without_guard() raises:
    """Loading an extension without first enabling should raise an error."""
    var conn = Connection.open_in_memory()

    with assert_raises():
        conn.load_extension("nonexistent_ext")


def test_load_extension_with_invalid_path_raises() raises:
    """Loading an extension from a path that does not exist should raise."""
    var conn = Connection.open_in_memory()
    var guard = conn.enable_extension_loading()

    try:
        with assert_raises():
            conn.load_extension("/no/such/extension.dylib")
    finally:
        guard^.disable_extension_loading()


def test_load_extension_with_entry_point_raises_on_invalid() raises:
    """Loading a nonexistent extension with an explicit entry point should raise."""
    var conn = Connection.open_in_memory()
    var guard = conn.enable_extension_loading()

    try:
        with assert_raises():
            conn.load_extension("/no/such/extension.dylib", "sqlite3_ext_init")
    finally:
        guard^.disable_extension_loading()


def test_guard_round_trip_enable_disable_enable() raises:
    """Extension loading can be enabled, disabled, and re-enabled."""
    var conn = Connection.open_in_memory()

    # First cycle
    var guard1 = conn.enable_extension_loading()
    guard1^.disable_extension_loading()

    # Second cycle — should succeed if disable properly revoked access.
    var guard2 = conn.enable_extension_loading()
    guard2^.disable_extension_loading()


def test_multiple_connections_independent_guards() raises:
    """Guards on separate connections should be independent."""
    var conn1 = Connection.open_in_memory()
    var conn2 = Connection.open_in_memory()

    var guard1 = conn1.enable_extension_loading()
    var guard2: ExtensionLoadGuard[origin_of(conn2)]
    try:
        guard2 = conn2.enable_extension_loading()
    except:
        guard1^.disable_extension_loading()
        raise

    # Disabling on conn1 should not affect conn2.
    try:
        guard1^.disable_extension_loading()
    except:
        guard2^.disable_extension_loading()
        raise

    # conn2 extension loading should still be active — loading a bad path
    # raises a load error, not a "loading disabled" error.
    try:
        with assert_raises():
            conn2.load_extension("nonexistent_ext")
    finally:
        guard2^.disable_extension_loading()


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
