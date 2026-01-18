from testing import assert_equal, assert_true, assert_false, assert_not_equal, TestSuite, assert_raises

from slight.connection import Connection
from slight import Row, String, Int
from slight.types.to_sql import Int
from slight.pragma import Sql, is_identifier

comptime dummy: Int = 0
"""For some reason, using the extended type explicitly makes the extensions start working after it in the
file."""
comptime dummy_str: String = ""


fn test_pragma_query_value() raises:
    """Test querying a single value from a pragma."""
    var db = Connection.open_in_memory()
    
    fn get_int(r: Row) raises -> Int:
        return r.get[Int](0)
    
    var user_version = db.pragma_query_value[get_int]("user_version")
    assert_equal(user_version, 0)


# fn test_pragma_query_no_schema() raises:
#     """Test querying pragma without schema name."""
#     var db = Connection.open_in_memory()
#     var user_version: Int = -1
    
#     @parameter
#     fn set_version(r: Row) raises:
#         user_version = r.get[Int](0)
    
#     db.pragma_query[callback=set_version]("user_version")
#     assert_equal(user_version, 0)


# fn test_pragma_query_with_schema() raises:
#     """Test querying pragma with schema name."""
#     var db = Connection.open_in_memory()
#     var user_version: Int = -1
    
#     @parameter
#     fn set_version(r: Row) raises:
#         user_version = r.get[Int](0)
    
#     db.pragma_query[callback=set_version]("main", "user_version")
#     assert_equal(user_version, 0)


# fn test_pragma() raises:
#     """Test pragma with argument (table_info)."""
#     var db = Connection.open_in_memory()
#     var columns = List[String]()
    
#     @parameter
#     fn collect_column(r: Row) raises:
#         var column = r.get[String](1)
#         columns.append(column)
    
#     db.pragma[callback=collect_column]("table_info", "sqlite_master")
#     assert_equal(len(columns), 5)


fn test_pragma_func() raises:
    """Test using PRAGMA function syntax."""
    var db = Connection.open_in_memory()
    var table_info = db.prepare("SELECT * FROM pragma_table_info(?1)")
    var columns = List[String]()
    
    var rows = table_info.query(["sqlite_master"])
    for row in rows:
        var column = row.get[String](1)
        columns.append(column)
    
    assert_equal(len(columns), 5)


fn test_pragma_update() raises:
    """Test updating a pragma value."""
    var db = Connection.open_in_memory()
    db.pragma_update("user_version", 1)
    
    # Verify the update worked
    fn get_int(r: Row) raises -> Int:
        return r.get[Int](0)
    
    var user_version = db.pragma_query_value[get_int]("user_version")
    assert_equal(user_version, 1)


fn test_pragma_update_and_check() raises:
    """Test updating a pragma and checking the returned value."""
    var db = Connection.open_in_memory()
    
    fn get_string(r: Row) raises -> String:
        return r.get[String](0)
    
    var journal_mode = db.pragma_update_and_check[get_string](
        "journal_mode", "OFF"
    )
    # Result may be "off" or "memory" depending on SQLite version and build
    assert_true(
        journal_mode == "off" or journal_mode == "memory",
        "Unexpected journal mode: " + journal_mode
    )
    
    # Second call to ensure consistency
    var mode2 = db.pragma_update_and_check[get_string](
        "journal_mode", "OFF"
    )
    assert_true(
        mode2 == "off" or mode2 == "memory",
        "Unexpected journal mode: " + mode2
    )


fn test_is_identifier() raises:
    """Test identifier validation."""
    assert_true(is_identifier("full"))
    assert_true(is_identifier("r2d2"))
    assert_false(is_identifier("sp ce"))
    assert_false(is_identifier("semi;colon"))
    assert_false(is_identifier(""))


fn test_double_quote() raises:
    """Test double quote escaping in schema names."""
    var sql = Sql()
    sql.push_schema("schema\";--")
    var result = String(sql)
    assert_equal(result, "\"schema\"\";--\"")


fn test_wrap_and_escape() raises:
    """Test string literal escaping."""
    var sql = Sql()
    sql.push_string_literal("value'; --")
    var result = String(sql)
    assert_equal(result, "'value''; --'")


fn test_locking_mode() raises:
    """Test setting locking mode pragma."""
    var db = Connection.open_in_memory()
    # TODO: Pragma returns a result set sometimes which causes execute_batch to throw
    db.pragma_update("locking_mode", "exclusive")
    
    # Verify it was set
    fn get_string(r: Row) raises -> String:
        return r.get[String](0)
    
    var mode = db.pragma_query_value[get_string]("locking_mode")
    assert_equal(mode, "exclusive")


fn test_sql_builder_keyword() raises:
    """Test SQL builder keyword validation."""
    var sql = Sql()
    
    # Valid keyword should work
    sql.push_keyword("PRAGMA")
    assert_equal(String(sql), "PRAGMA")
    
    # Invalid keyword should raise
    var sql2 = Sql()
    with assert_raises(contains="Invalid keyword"):
        sql2.push_keyword("INVALID KEYWORD")
    
    # Empty keyword should raise
    var sql3 = Sql()
    with assert_raises(contains="Invalid keyword"):
        sql3.push_keyword("")


fn test_sql_builder_pragma() raises:
    """Test building PRAGMA statements."""
    var sql = Sql()
    sql.push_pragma("user_version")
    assert_equal(String(sql), "PRAGMA user_version")
    
    # With schema name
    var sql2 = Sql()
    sql2.push_pragma("user_version", "main")
    assert_equal(String(sql2), "PRAGMA main.user_version")


fn test_sql_builder_value() raises:
    """Test pushing different value types."""
    var sql = Sql()
    sql.push_int(42)
    assert_equal(String(sql), "42")
    
    var sql2 = Sql()
    sql2.push_real(3.14)
    var result = String(sql2)
    assert_true(result.startswith("3.14"))
    
    var sql3 = Sql()
    sql3.push_string_literal("hello")
    assert_equal(String(sql3), "'hello'")


fn test_sql_builder_complete_statement() raises:
    """Test building a complete PRAGMA statement with value."""
    var sql = Sql()
    sql.push_pragma("user_version")
    sql.push_equal_sign()
    sql.push_int(5)
    assert_equal(String(sql), "PRAGMA user_version=5")


fn test_identifier_edge_cases() raises:
    """Test edge cases for identifier validation."""
    # Valid identifiers
    assert_true(is_identifier("_underscore"))
    assert_true(is_identifier("UPPERCASE"))
    assert_true(is_identifier("lowercase"))
    assert_true(is_identifier("Mixed_Case123"))
    
    # Invalid identifiers
    assert_false(is_identifier("123start"))  # Can't start with digit
    assert_false(is_identifier("has space"))
    assert_false(is_identifier("has-dash"))
    assert_false(is_identifier("has.dot"))


# fn test_pragma_with_int_value() raises:
#     """Test pragma with integer parameter."""
#     var db = Connection.open_in_memory()
#     var columns = List[String]()
    
#     fn collect_column(r: Row) raises:
#         var column = r.get[String](1)
#         columns.append(column)
    
#     # Create a test table first
#     db.execute_batch("CREATE TABLE test (id INTEGER, name TEXT)")
    
#     # Query table info using pragma with string parameter
#     db.pragma[collect_column](None, "table_info", "test")
#     assert_equal(len(columns), 2)


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
