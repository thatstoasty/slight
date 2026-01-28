from testing import assert_equal, assert_true, assert_false, assert_not_equal, TestSuite, assert_raises

from slight.connection import Connection
from slight.statement import eq_ignore_ascii_case
from slight.row import Row
from slight import String, Int, Bool, SIMD, Dict, List
from slight.types.to_sql import ToSQL
from slight.types.from_sql import NoneType
from slight.bind import BindIndex, BindIndexError


fn test_bind_index_with_int() raises:
    """Test BindIndex with Int type for positional parameter indexing."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (id INTEGER, name TEXT)")

    var stmt = db.prepare("INSERT INTO test (id, name) VALUES (?1, ?2)")

    # Test that Int.bind_idx returns the correct index
    var index1: Int = 1
    var index2: Int = 2

    assert_equal(index1.bind_idx(stmt), UInt(1))
    assert_equal(index2.bind_idx(stmt), UInt(2))

    # Test with actual execution to verify it works end-to-end
    _ = stmt.execute(42, "test_value")

    fn get_id(r: Row) raises -> Int:
        return r.get[Int](0)

    var result = db.query_row[get_id]("SELECT id FROM test WHERE name = 'test_value'")
    assert_equal(result, 42)


fn test_bind_index_with_string() raises:
    """Test BindIndex with String type for named parameter indexing."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (id INTEGER, name TEXT)")

    var stmt = db.prepare("INSERT INTO test (id, name) VALUES (:id, :name)")

    # Test that String.bind_idx returns the correct index for valid parameter names
    var param_id = String(":id")
    var param_name = String(":name")

    var id_index = param_id.bind_idx(stmt)
    var name_index = param_name.bind_idx(stmt)

    # Indices should be valid (non-zero, 1-based)
    assert_true(id_index > 0)
    assert_true(name_index > 0)
    assert_not_equal(id_index, name_index)

    # Test with actual execution using named parameters
    _ = stmt.execute({":id": "123", ":name": "hello"})

    fn get_name(r: Row) raises -> String:
        return r.get[String](1)

    var result = db.query_row[get_name]("SELECT * FROM test WHERE id = 123")
    assert_equal(result, "hello")


fn test_bind_index_with_string_invalid_name() raises:
    """Test BindIndex with String type raises error for invalid parameter name."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (id INTEGER)")

    var stmt = db.prepare("INSERT INTO test (id) VALUES (:id)")

    var invalid_param = String(":nonexistent")

    with assert_raises(contains="invalid parameter name"):
        _ = invalid_param.bind_idx(stmt)


fn test_bind_index_with_string_slice() raises:
    """Test BindIndex with StringSlice type for named parameter indexing."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (value INTEGER, label TEXT)")

    var stmt = db.prepare("INSERT INTO test (value, label) VALUES (:value, :label)")

    # Test that StringSlice.bind_idx returns the correct index for valid parameter names
    var param_value = ":value"
    var param_label = ":label"

    var value_index = StringSlice(param_value).bind_idx(stmt)
    var label_index = StringSlice(param_label).bind_idx(stmt)

    # Indices should be valid (non-zero, 1-based)
    assert_true(value_index > 0)
    assert_true(label_index > 0)
    assert_not_equal(value_index, label_index)


fn test_bind_index_with_string_slice_invalid_name() raises:
    """Test BindIndex with StringSlice type raises error for invalid parameter name."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (id INTEGER)")

    var stmt = db.prepare("INSERT INTO test (id) VALUES (:id)")

    var invalid_param = ":missing"

    with assert_raises(contains="invalid parameter name"):
        _ = StringSlice(invalid_param).bind_idx(stmt)


fn test_bind_index_with_different_param_prefixes() raises:
    """Test BindIndex with different SQLite parameter prefixes (:, @, $)."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (a INTEGER, b INTEGER, c INTEGER)")

    # SQLite supports different parameter prefixes
    var stmt = db.prepare("INSERT INTO test (a, b, c) VALUES (:a, @b, $c)")

    var param_a = String(":a")
    var param_b = String("@b")
    var param_c = String("$c")

    var a_index = param_a.bind_idx(stmt)
    var b_index = param_b.bind_idx(stmt)
    var c_index = param_c.bind_idx(stmt)

    # All should have valid indices
    assert_true(a_index > 0)
    assert_true(b_index > 0)
    assert_true(c_index > 0)

    # All indices should be different
    assert_not_equal(a_index, b_index)
    assert_not_equal(b_index, c_index)
    assert_not_equal(a_index, c_index)


fn test_bind_index_int_zero_and_negative() raises:
    """Test BindIndex with Int for edge cases like zero and large values."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (id INTEGER)")

    var stmt = db.prepare("INSERT INTO test (id) VALUES (?1)")

    # Test zero index (SQLite uses 1-based indexing, 0 is typically invalid)
    var index_zero: Int = 0
    assert_equal(index_zero.bind_idx(stmt), UInt(0))

    # Test larger index
    var index_large: Int = 100
    assert_equal(index_large.bind_idx(stmt), UInt(100))


fn test_bind_index_string_vs_string_slice_consistency() raises:
    """Test that String and StringSlice return consistent indices for the same parameter."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (x INTEGER, y TEXT)")

    var stmt = db.prepare("SELECT * FROM test WHERE x = :x AND y = :y")

    var param_x_string = String(":x")
    var param_x_slice = ":x"

    var param_y_string = String(":y")
    var param_y_slice = ":y"

    # Both should return the same index for the same parameter name
    assert_equal(param_x_string.bind_idx(stmt), StringSlice(param_x_slice).bind_idx(stmt))
    assert_equal(param_y_string.bind_idx(stmt), StringSlice(param_y_slice).bind_idx(stmt))


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
    # var suite = TestSuite()
    # suite.test[test_insert_bytes]()
    # suite^.run()