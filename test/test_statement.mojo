from testing import assert_equal, assert_true, assert_false, assert_not_equal, TestSuite, assert_raises

from slight.connection import Connection
from slight.statement import eq_ignore_ascii_case
from slight.row import Row
from slight import String, Int, Bool, SIMD, Dict, List
from slight.types.to_sql import ToSQL
from slight.types.from_sql import NoneType

comptime dummy_int: Int = 0
comptime dummy_str: String = ""
comptime dummy_bool: Bool = False
comptime dummy_simd: Int32 = 0


fn test_execute_named() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER)")

    # TODO: Because the tuple literal syntax is not supported anymore ATM, use the initializer format.
    assert_equal(
        db.execute("INSERT INTO foo(x) VALUES (:x)", {":x": 1}),
        1
    )
    assert_equal(
        db.execute("INSERT INTO foo(x) VALUES (:x)", {":x": 2}),
        1
    )
    assert_equal(
        db.execute("INSERT INTO foo(x) VALUES (:x)", {":x": 3}),
        1
    )

    fn get_int32(r: Row) raises -> Int32:
        return Int32(r.get[Int](0))

    assert_equal(
        db.query_row[get_int32](
            "SELECT SUM(x) FROM foo WHERE x > :x",
            {":x": 0},
        ),
        6
    )
    assert_equal(
        db.query_row[get_int32](
            "SELECT SUM(x) FROM foo WHERE x > :x",
            {":x": 1},
        ),
        5
    )


# BROKEN
fn test_stmt_execute_named() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, flag INTEGER)")

    var stmt = db.prepare("INSERT INTO test (name) VALUES (:name)")
    _ = stmt.execute({":name": "one"})
    _ = stmt.execute({":name": "one"})

    fn get_count(r: Row) raises -> Int:
        return r.get[Int](0)

    var stmt2 = db.prepare("SELECT COUNT(*) FROM test WHERE name = :name")
    assert_equal(
        stmt2.query_row[transform=get_count]({":name": "one"}),
        2
    )


fn test_query_named() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""CREATE TABLE test (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, flag INTEGER);
    INSERT INTO test(id, name) VALUES (1, "one");""")

    var stmt = db.prepare("SELECT id FROM test where name = :name")
    # var rows = stmt.query([(":name", "one")])
    var rows = stmt.query({":name": "one"})
    for row in rows:
        assert_equal(row.get[Int](0), 1)


fn test_query_params() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""CREATE TABLE test (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, flag INTEGER);
    INSERT INTO test(id, name) VALUES (1, "one");""")

    var stmt = db.prepare("SELECT id FROM test where name = ?1")
    var rows = stmt.query(["one"])
    for row in rows:
        assert_equal(row.get[Int](0), 1)


fn test_query_map_named() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""CREATE TABLE test (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, flag INTEGER);
    INSERT INTO test(id, name) VALUES (1, "one");""")

    fn get_doubled_id(r: Row) -> Int:
        try:
            return r.get[Int](0) * 2
        except:
            return 0

    var stmt = db.prepare("SELECT id FROM test where name = :name")
    for row in stmt.query_map[transform=get_doubled_id]({":name": "one"}):
        assert_equal(row, 2)


@fieldwise_init
struct TestStruct(Defaultable, Movable):
    var id: Int
    var name: String
    var flag: Int

    fn __init__(out self):
        self.id = 0
        self.name = ""
        self.flag = 0


fn test_query_as_type_named() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""CREATE TABLE test (id INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, flag INTEGER);
    INSERT INTO test(id, name) VALUES (1, "one");""")

    var stmt = db.prepare("SELECT id FROM test where name = :name")
    for row in stmt.query_as_type[T=TestStruct]({":name": "one"}):
        assert_equal(row.id, 1)


fn test_unbound_parameters_are_null() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (x TEXT, y TEXT)")

    var stmt = db.prepare("INSERT INTO test (x, y) VALUES (:x, :y)")
    _ = stmt.execute({":x": "one"})
    fn get_value(r: Row) raises -> NoneType:
        var result = r.get_string_slice(0)
        if not result:
            return
        raise Error("Expected NULL value!")

    _ = db.query_row[get_value]("SELECT y FROM test WHERE x = 'one'")


fn test_unbound_parameters_are_reused() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE test (x TEXT, y TEXT)")

    var stmt = db.prepare("INSERT INTO test (x, y) VALUES (:x, :y)")
    _ = stmt.execute({":x": "one"})
    _ = stmt.execute({":y": "two"})

    fn get_value(r: Row) raises -> String:
        return r.get[String](0)

    var result = db.query_row[get_value]("SELECT x FROM test WHERE y = 'two'")
    assert_equal(result, "one")


fn test_insert() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER UNIQUE)")
    var stmt = db.prepare("INSERT OR IGNORE INTO foo (x) VALUES (?1)")
    assert_equal(stmt.insert([1]), 1)
    assert_equal(stmt.insert([2]), 2)

    with assert_raises(contains="0 rows"):
        _ = stmt.insert([1])

    var multi = db.prepare("INSERT INTO foo (x) SELECT 3 UNION ALL SELECT 4")
    with assert_raises(contains="2 rows"):
        _ = multi.insert()


fn test_insert_different_tables() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""
    CREATE TABLE foo(x INTEGER);
    CREATE TABLE bar(x INTEGER);
    """)

    var stmt = db.prepare("INSERT INTO foo VALUES (10)")
    assert_equal(stmt.insert(), 1)

    stmt = db.prepare("INSERT INTO bar VALUES (10)")
    assert_equal(stmt.insert(), 1)


fn test_exists() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""CREATE TABLE foo(x INTEGER);
    INSERT INTO foo VALUES(1);
    INSERT INTO foo VALUES(2);
    """)
    var stmt = db.prepare("SELECT 1 FROM foo WHERE x = ?1")
    assert_true(stmt.exists([1]))

    # TODO: How can I reuse statements after a value has been bound?
    # The statement is reset for execute, but not query
    # assert_true(stmt.exists([2]))
    # assert_false(stmt.exists([0]))


fn test_list_params() raises:
    var db = Connection.open_in_memory()

    fn get_string(r: Row) raises -> String:
        return r.get[String](0)

    var s = db.query_row[get_string]("SELECT printf('[%s]', ?1)", ["abc"])
    assert_equal(s, "[abc]")


fn test_dict_params() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER);")

    assert_equal(
        db.execute("INSERT INTO foo(x) VALUES (:x)", {":x": 1}),
        1
    )


fn test_variadic_params() raises:
    var db = Connection.open_in_memory()

    fn get_string(r: Row) raises -> String:
        return r.get[String](0)

    var s = db.query_row[get_string]("SELECT printf('[%s]', ?1)", "abc")
    assert_equal(s, "[abc]")

    var s2 = db.query_row[get_string](
        "SELECT printf('%d %s %d', ?1, ?2, ?3)",
        1, "abc", 2
    )
    assert_equal(s2, "1 abc 2")

    var s3 = db.query_row[get_string](
        "SELECT printf('%d %s %d %d', ?1, ?2, ?3, ?4)",
        1, "abc", 2, 4,
    )
    assert_equal(s3, "1 abc 2 4")
    
    # Large tuple test
    var query = """SELECT printf(
        '%d %s | %d %s | %d %s | %d %s || %d %s | %d %s | %d %s | %d %s',
        ?1, ?2, ?3, ?4,
        ?5, ?6, ?7, ?8,
        ?9, ?10, ?11, ?12,
        ?13, ?14, ?15, ?16
    )"""
    var s4 = db.query_row[get_string](
        query,
        0, "a", 1, "b", 2, "c", 3, "d", 4, "e", 5, "f", 6, "g", 7, "h"
    )
    assert_equal(s4, "0 a | 1 b | 2 c | 3 d || 4 e | 5 f | 6 g | 7 h")


fn test_query_row() raises:
    var db = Connection.open_in_memory()

    fn get_int64(r: Row) raises -> Int64:
        return r.get[Int64](0)

    db.execute_batch("""CREATE TABLE foo(x INTEGER, y INTEGER);
    INSERT INTO foo VALUES(1, 3);
    INSERT INTO foo VALUES(2, 4);""")
    var stmt = db.prepare("SELECT y FROM foo WHERE x = ?1")
    var y = stmt.query_row[transform=get_int64]([1])
    assert_equal(y, 3)


fn query_one() raises:
    var db = Connection.open_in_memory()
    
    fn get_int64(r: Row) raises -> Int64:
        return r.get[Int64](0)

    db.execute_batch("CREATE TABLE foo(x INTEGER, y INTEGER);")
    var stmt = db.prepare("SELECT y FROM foo WHERE x = ?1")
    
    # This should return no rows error
    with assert_raises(contains="Query returned no rows"):
        _ = stmt.query_row[transform=get_int64]([1])
    
    db.execute_batch("INSERT INTO foo VALUES(1, 3);")
    var y2 = stmt.query_row[transform=get_int64]([1])
    assert_equal(y2, 3)
    
    db.execute_batch("INSERT INTO foo VALUES(1, 3);")
    # This should return more than one row error
    # TODO: Implement query_one method that validates single row
    # with assert_raises(contains="Query returned more than one row"):
    #     _ = stmt.query_one[transform=get_int64]([1])


fn test_query_by_column_name() raises:
    var db = Connection.open_in_memory()
    
    fn get_string(r: Row) raises -> Int:
        return r.get[Int]("y")

    db.execute_batch("""BEGIN;
    CREATE TABLE foo(x INTEGER, y INTEGER);
    INSERT INTO foo VALUES(1, 3);
    END;""")
    var stmt = db.prepare("SELECT y FROM foo")
    var y = stmt.query_row[transform=get_string]()
    assert_equal(y, 3)


fn test_query_by_column_name_ignore_case() raises:
    var db = Connection.open_in_memory()

    fn get_int(r: Row) raises -> Int:
        return r.get[Int]("y")

    db.execute_batch("""BEGIN;
    CREATE TABLE foo(x INTEGER, y INTEGER);
    INSERT INTO foo VALUES(1, 3);
    END;""")
    var stmt = db.prepare("SELECT y as Y FROM foo")
    var y = stmt.query_row[transform=get_int]()
    assert_equal(y, 3)


fn test_expanded_sql() raises:
    var db = Connection.open_in_memory()
    var stmt = db.prepare("SELECT ?1")
    stmt.bind_parameter(1, 1)
    assert_equal(stmt.expanded_sql().value(), "SELECT 1")


fn test_bind_parameters() raises:
    var db = Connection.open_in_memory()
    
    fn get_int(r: Row) raises -> Int:
        return r.get[Int](0)

    # Test with list of parameters - query_row doesn't directly support List types like this
    # Instead we'll test parameter binding through the execute path
    var s = db.query_row[get_int]("SELECT ?1 + ?2", [5, 10])
    assert_equal(s, 15)


# fn test_parameter_name() raises:
#     var db = Connection.open_in_memory()
    
#     db.execute_batch("CREATE TABLE test (name TEXT, value INTEGER)")
#     var stmt = db.prepare("INSERT INTO test (name, value) VALUES (:name, ?3)")
    
#     # TODO: parameter_name method is not yet implemented
#     # Test parameter name retrieval
#     # var name1 = stmt.parameter_name(1)
#     # assert_true(name1 is not None)
#     # if name1:
#     #     assert_equal(name1.value(), ":name")
    
#     # var name0 = stmt.parameter_name(0)
#     # assert_true(name0 is None)
    
#     # var name2 = stmt.parameter_name(2)
#     # assert_true(name2 is None)
    
#     # For now, just test that the statement can be prepared
#     assert_true(stmt.column_count() == 0)


fn test_empty_stmt() raises:
    var db = Connection.open_in_memory()

    var stmt = db.prepare("")
    assert_equal(stmt.column_count(), 0)
    
    # Empty statement should have no SQL
    var sql = stmt.sql()
    assert_true(sql is None or sql.value() == "")
    
    # Reset should work even on empty statement
    stmt.reset()


fn test_comment_stmt() raises:
    var db = Connection.open_in_memory()
    _ = db.prepare("/*SELECT 1;*/")


fn test_comment_and_sql_stmt() raises:
    var db = Connection.open_in_memory()
    _ = db.prepare("/* ... */ SELECT 1;")


fn test_semi_colon_stmt() raises:
    var db = Connection.open_in_memory()
    var stmt = db.prepare(";")
    assert_equal(stmt.column_count(), 0)


fn test_utf16_conversion() raises:
    var db = Connection.open_in_memory()
    
    fn get_string(r: Row) raises -> String:
        return r.get[String](0)
    
    # TODO: pragma_update and pragma_query_value are not yet implemented
    # db.execute("PRAGMA encoding = 'UTF-16le'")
    # var encoding = db.query_row[transform=get_string]("PRAGMA encoding")
    # assert_equal(encoding, "UTF-16le")
    
    db.execute_batch("CREATE TABLE foo(x TEXT)")
    var expected = "テスト"
    _ = db.execute("INSERT INTO foo(x) VALUES (?1)", [expected])
    var actual = db.query_row[get_string]("SELECT x FROM foo")
    assert_equal(actual, expected)


fn test_is_explain() raises:
    var db = Connection.open_in_memory()
    var stmt = db.prepare("EXPLAIN SELECT 1;")
    assert_equal(stmt.is_explain(), 1)


fn test_is_read_only() raises:
    var db = Connection.open_in_memory()
    var stmt = db.prepare("SELECT 1;")
    assert_true(stmt.is_read_only())


fn test_column_name_in_error() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("""BEGIN;
        CREATE TABLE foo(x INTEGER, y TEXT);
        INSERT INTO foo VALUES(4, NULL);
        END;""")
    
    fn get_string_from_x(r: Row) raises -> String:
        return r.get[String](0)
    
    fn get_string_from_y(r: Row) raises -> String:
        return r.get[String]("y")
    
    var stmt = db.prepare("SELECT x as renamed, y FROM foo")
    var rows = stmt.query()
    
    for row in rows:
        # Test getting integer column as string (should fail)
        with assert_raises(contains="InvalidColumnType"):
            _ = row.get[String](0)
        
        # Test getting NULL column as string (should fail)
        with assert_raises(contains="InvalidColumnType"):
            _ = row.get[String]("y")
        
        break  # Only test first row


fn test_column_name_reference() raises:
    """The `column_name` reference should stay valid until `stmt` is reprepared (or
    reset) even if DB schema is altered (SQLite documentation is
    ambiguous here because it says reference "is valid until (...) the next
    call to `sqlite3_column_name()` or `sqlite3_column_name16()` on the same
    column.". We assume that reference is valid if only
    `sqlite3_column_name()` is used)."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE y (x);")
    var stmt = db.prepare("SELECT x FROM y;")
    var column_name = stmt.column_name(0)
    assert_equal(column_name, "x")
    
    db.execute_batch("ALTER TABLE y RENAME COLUMN x TO z;")
    # column name is not refreshed until statement is re-prepared
    var same_column_name = stmt.column_name(0)
    assert_equal(same_column_name, column_name)


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
    # var suite = TestSuite()
    # suite.test[test_variadic_params]()
    # suite^.run()