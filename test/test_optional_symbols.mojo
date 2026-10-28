"""Loading a libsqlite3 that lacks optional C API functions.

On macOS this loads the system `/usr/lib/libsqlite3.dylib`, which is built
without `sqlite3_load_extension` and `sqlite3_unlock_notify`. Before optional
symbols were resolved lazily, loading it aborted the whole process.

The library is chosen once per process, so this file sets `SQLITE_LIB_PATH`
in `main` before anything touches SQLite, and must stay a separate test file.
"""
from std import os
from std.ffi import CompilationTarget
from slight.api import sqlite_ffi
from slight.connection import Connection
from std.testing import TestSuite, assert_equal, assert_false, assert_raises, assert_true

comptime SYSTEM_SQLITE = "/usr/lib/libsqlite3.dylib"


def test_has_function() raises:
    assert_true(sqlite_ffi()[].has_function("sqlite3_step"))
    assert_false(sqlite_ffi()[].has_function("sqlite3_this_function_does_not_exist"))


def test_require_function_raises_for_missing() raises:
    sqlite_ffi()[].require_function("sqlite3_step")
    with assert_raises(contains="sqlite3_this_function_does_not_exist is not available"):
        sqlite_ffi()[].require_function("sqlite3_this_function_does_not_exist")


def test_library_without_optional_functions_is_usable() raises:
    comptime if not CompilationTarget.is_macos():
        return

    assert_false(sqlite_ffi()[].has_function("sqlite3_load_extension"))
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE t(x INTEGER); INSERT INTO t VALUES (1), (2);")
    assert_equal(db.one_column[Int64]("SELECT sum(x) FROM t"), 3)


def test_missing_function_raises_instead_of_aborting() raises:
    comptime if not CompilationTarget.is_macos():
        return

    var db = Connection.open_in_memory()
    with assert_raises(contains="sqlite3_enable_load_extension is not available"):
        var guard = db.enable_extension_loading()
        guard^.disable_extension_loading()
    with assert_raises(contains="sqlite3_load_extension is not available"):
        db.load_extension("does_not_matter")


def main() raises:
    comptime if CompilationTarget.is_macos():
        _ = os.setenv("SQLITE_LIB_PATH", SYSTEM_SQLITE)
    TestSuite.discover_tests[__functions_in_module()]().run()
