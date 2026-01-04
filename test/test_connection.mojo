from testing import assert_equal, assert_true, assert_false, assert_not_equal, TestSuite, assert_raises
import tempfile
from pathlib import Path

from slight.connection import Connection
from slight.statement import eq_ignore_ascii_case
from slight.row import Row, String, Int, Bool, SIMD
from slight.flags import OpenFlag
from slight.c.raw_bindings import sqlite3_stmt, SQLITE_OK
from slight.c.api import sqlite_ffi


# @fieldwise_init
# struct Employee(Copyable, Movable, Writable):
#     var id: Int
#     var name: String
#     var age: Int8
#     var address: String
#     var salary: Float64
#     var is_active: Bool

#     fn write_to[W: Writer](self, mut writer: W):
#         writer.write("Employee(id=", self.id, ", name=", self.name, ", age=", self.age, ", address=", self.address, ", salary=", self.salary, ", is_active=", self.is_active, ")")


# fn transform_row(row: Row) raises -> Employee:
#     return Employee(
#         id=row.get[Int]("id"),
#         name=row.get[String]("name"),
#         age=row.get[Int8]("age"),
#         address=row.get[String]("address"),
#         salary=row.get[Float64]("salary"),
#         is_active=row.get[Bool]("is_active")
#     )
        

fn test_eq_ignore_ascii_case_test() raises:
    assert_true(eq_ignore_ascii_case("hello".as_bytes(), "HELLO".as_bytes()))
    assert_true(eq_ignore_ascii_case("MoJo".as_bytes(), "mojo".as_bytes()))
    assert_false(eq_ignore_ascii_case("Test".as_bytes(), "Taste".as_bytes()))
    assert_false(eq_ignore_ascii_case("Mojo".as_bytes(), "Mojo!".as_bytes()))


fn test_path() raises:
    with Connection.open_in_memory() as db:
        assert_equal(db.path().value(), "")

    db = Connection.open("file:dummy.db?mode=memory&cache=shared")
    assert_equal(db.path().value(), "")

    with tempfile.TemporaryDirectory() as tmp:
        var path = Path(tmp) / "file.db"
        var db = Connection.open(path)
        assert_true(String(db.path().value()).endswith("file.db"))


fn test_open_failure() raises:
    with assert_raises(contains="Unable to open the database file"):
        _ = Connection.open("no_such_file.db", materialize[OpenFlag.READ_ONLY]())


# fn test_close_retry() raises:
#     var db = Connection.open_in_memory()

#     # force the DB to be busy by preparing a statement; this must be done at the
#     # FFI level to allow us to call .close() without dropping the prepared
#     # statement first.
#     try:
#         var sql: String = "SELECT 1"
#         var sql_ptr = sql.unsafe_cstr_ptr()
#         var c_tail = UnsafePointer(to=sql_ptr)
#         var raw_stmt = UnsafePointer[sqlite3_stmt]()
#         var rc = sqlite_ffi()[].prepare_v3(
#             db.db.db,
#             sql_ptr,
#             Int32(len(sql) + 1),
#             1,
#             UnsafePointer(to=raw_stmt),
#             c_tail,
#         )

#         assert_equal(rc.value, SQLITE_OK)

#         # now that we have an open statement, trying (and retrying) to close should
#         # fail.
#         _ = db^.close()
#         # let (db, _) = db.close().unwrap_err()
#         # let (db, _) = db.close().unwrap_err()

#         # finalize the open statement so a final close will succeed
#         assert_eq!(ffi::SQLITE_OK, unsafe { ffi::sqlite3_finalize(raw_stmt) });

#     finally:
#         db^.close()


# fn test_table_creation_and_insertion() raises:
#     var db = Connection.open_in_memory()

#     db.execute_batch("""
#     CREATE TABLE COMPANY(
#         ID INT PRIMARY KEY NOT NULL,
#         NAME TEXT NOT NULL,
#         AGE INT NOT NULL,
#         ADDRESS CHAR(50),
#         SALARY REAL,
#         IS_ACTIVE BOOLEAN NOT NULL
#     );
#     CREATE TABLE EMPLOYEE(ID INT PRIMARY KEY NOT NULL);
#     CREATE TABLE DEPARTMENT(ID INT PRIMARY KEY NOT NULL);
#     """)

#     var stmt = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name = 'DEPARTMENT';")
#     assert_true(stmt.exists())

#     # Running multiple inserts in one query doesn't work atm. Will need to fix
#     try:
#         assert_equal(
#             String(
#                 db.execute("""
#                 INSERT INTO COMPANY (ID, NAME, AGE, ADDRESS, SALARY, IS_ACTIVE) VALUES 
#                 (1, 'Bob', 30, '123 Main St', 45000.0, False),
#                 (2, 'Alice', 30, '123 Main St', 50000.0, True);
#                 """),
#                 " row(s) affected."
#             ),
#             "2 row(s) affected.")
#     except e:
#         if e.as_string_slice() == "not an error":
#             raise

#     alias select_user_query = "SELECT * FROM COMPANY WHERE NAME = ?;"
#     stmt = db.prepare(select_user_query)
#     for row in stmt.query(["Alice"]):
#         # Column name based access
#         assert_equal(row.get[Int]("id"), 2)
#         assert_equal(row.get[String]("name"), "Alice")

#         # Index based access
#         assert_equal(row.get[Int](0), 2)
#         assert_equal(row.get[String](1), "Alice")

#     stmt = db.prepare(select_user_query)
#     var employee = stmt.query_row[transform=transform_row](["Bob"])
#     assert_equal(employee.id, 1)
#     assert_equal(employee.name, "Bob")

#     db^.close()


fn test_bad_open_flags() raises:
    var bad_flags = [
        OpenFlag.READ_ONLY | OpenFlag.READ_WRITE,
        OpenFlag.READ_ONLY | OpenFlag.CREATE
    ]

    for flags in bad_flags:
        with assert_raises(contains="Library used incorrectly"):
            var db = Connection.open_in_memory(flags)
            db^.close()


fn test_execute_batch() raises:
    var db = Connection.open_in_memory()    
    db.execute_batch("""CREATE TABLE foo(x INTEGER);
    INSERT INTO foo VALUES(1);
    INSERT INTO foo VALUES(2);
    INSERT INTO foo VALUES(3);
    INSERT INTO foo VALUES(4);""")
    db.execute_batch("UPDATE foo SET x = 3 WHERE x < 3")
    
    with assert_raises():
        db.execute_batch("INVALID SQL")
    
    # db.execute_batch("PRAGMA locking_mode = EXCLUSIVE")


# fn test_execute() raises:
#     var db = Connection.open_in_memory()
    
#     fn get_int(r: Row) raises -> Int:
#         return r.get[Int](0)
    
#     db.execute_batch("CREATE TABLE foo(x INTEGER)")
    
#     assert_equal(db.execute("INSERT INTO foo(x) VALUES (?1)", [1]), 1)
#     assert_equal(db.execute("INSERT INTO foo(x) VALUES (?1)", [2]), 1)
    
#     assert_equal(db.query_row[transform=get_int]("SELECT SUM(x) FROM foo"), 3)


fn test_execute_select_with_row() raises:
    var db = Connection.open_in_memory()
    with assert_raises(contains="Query returned rows"):
        _ = db.execute("SELECT 1")


fn test_execute_multiple() raises:
    var db = Connection.open_in_memory()
    with assert_raises(contains="MultipleStatementsError"):
        _ = db.execute("CREATE TABLE foo(x INTEGER); CREATE TABLE foo(x INTEGER)")
    
    # Tail comment should be ignored
    _ = db.execute("CREATE TABLE t(c); -- bim")


fn test_prepare_column_names() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER);")
    
    var stmt = db.prepare("SELECT * FROM foo")
    assert_equal(stmt.column_count(), 1)
    # TODO: column_names() method not yet implemented
    # assert_equal(stmt.column_names()[0], "x")
    
    var stmt2 = db.prepare("SELECT x AS a, x AS b FROM foo")
    assert_equal(stmt2.column_count(), 2)
    # assert_equal(stmt2.column_names()[0], "a")
    # assert_equal(stmt2.column_names()[1], "b")


fn test_prepare_execute() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER);")
    
    var insert_stmt = db.prepare("INSERT INTO foo(x) VALUES(?1)")
    assert_equal(insert_stmt.execute([1]), 1)
    assert_equal(insert_stmt.execute([2]), 1)
    assert_equal(insert_stmt.execute([3]), 1)
    
    assert_equal(insert_stmt.execute(["hello"]), 1)
    assert_equal(insert_stmt.execute(["goodbye"]), 1)
    # TODO: Need to implement NULL parameter binding
    # assert_equal(insert_stmt.execute([types.Null]), 1)
    
    var update_stmt = db.prepare("UPDATE foo SET x=?1 WHERE x<?2")
    assert_equal(update_stmt.execute([3, 3]), 2)
    assert_equal(update_stmt.execute([3, 3]), 0)
    assert_equal(update_stmt.execute([8, 8]), 3)


fn test_prepare_query() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER);")
    
    var insert_stmt = db.prepare("INSERT INTO foo(x) VALUES(?1)")
    assert_equal(insert_stmt.execute([1]), 1)
    assert_equal(insert_stmt.execute([2]), 1)
    assert_equal(insert_stmt.execute([3]), 1)
    
    var query = db.prepare("SELECT x FROM foo WHERE x < ?1 ORDER BY x DESC")
    
    # First query with parameter 4
    var rows = query.query([4])
    var v = List[Int]()
    for row in rows:
        v.append(row.get[Int](0))
    assert_equal(len(v), 3)
    assert_equal(v[0], 3)
    assert_equal(v[1], 2)
    assert_equal(v[2], 1)
    
    # TODO: Need to figure out how to reset and reuse statements
    # Second query with parameter 3
    # query = db.prepare("SELECT x FROM foo WHERE x < ?1 ORDER BY x DESC")
    # var rows2 = query.query([3])
    # var v2 = List[Int]()
    # for row in rows2:
    #     v2.append(row.get[Int](0))
    # assert_equal(len(v2), 2)
    # assert_equal(v2[0], 2)
    # assert_equal(v2[1], 1)


fn test_query_map() raises:
    var db = Connection.open_in_memory()    
    fn get_string(r: Row) raises -> String:
        return r.get[String](1)
    
    db.execute_batch("""CREATE TABLE foo(x INTEGER, y TEXT);
    INSERT INTO foo VALUES(4, 'hello');
    INSERT INTO foo VALUES(3, ', ');
    INSERT INTO foo VALUES(2, 'world');
    INSERT INTO foo VALUES(1, '!');""")
    
    var query = db.prepare("SELECT x, y FROM foo ORDER BY x DESC")
    var results = List[String]()
    for row in query.query():
        results.append(row.get[String](1))
    
    var concat = String("")
    for i in range(len(results)):
        concat += results[i]
    assert_equal(concat, "hello, world!")


fn test_query_row() raises:
    var db = Connection.open_in_memory()
    var sql = """CREATE TABLE foo(x INTEGER);
    INSERT INTO foo VALUES(1);
    INSERT INTO foo VALUES(2);
    INSERT INTO foo VALUES(3);
    INSERT INTO foo VALUES(4);"""
    
    fn get_int64(r: Row) raises -> Int64:
        return r.get[Int64](0)

    db.execute_batch(sql)
    assert_equal(db.query_row[get_int64]("SELECT SUM(x) FROM foo"), 10)
    
    # This should return no rows error
    with assert_raises(contains="No rows returned by query"):
        _ = db.query_row[get_int64]("SELECT x FROM foo WHERE x > 5")
    
    with assert_raises():
        _ = db.query_row[get_int64]("NOT A PROPER QUERY; test123")
    
    with assert_raises():
        _ = db.query_row[get_int64]("SELECT 1; SELECT 2;")


fn test_pragma_query_row() raises:
    var db = Connection.open_in_memory()
    fn get_string(r: Row) raises -> String:
        return r.get[String](0)

    var mode = db.query_row[transform=get_string]("PRAGMA journal_mode")
    assert_equal(mode, "memory")
    
    var mode2 = db.query_row[transform=get_string]("PRAGMA journal_mode=off")
    # Note: system SQLite behavior may vary
    assert_true(mode2 == "memory" or mode2 == "off")


fn test_prepare_failures() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER);")
    
    with assert_raises(contains="does_not_exist"):
        _ = db.prepare("SELECT * FROM does_not_exist")


fn test_last_insert_rowid() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x INTEGER PRIMARY KEY)")
    db.execute_batch("INSERT INTO foo DEFAULT VALUES")
    
    assert_equal(db.last_insert_row_id(), 1)
    
    var stmt = db.prepare("INSERT INTO foo DEFAULT VALUES")
    for _ in range(9):
        _ = stmt.execute()
    assert_equal(db.last_insert_row_id(), 10)


fn test_total_changes() raises:
    var db = Connection.open_in_memory()
    var sql = """CREATE TABLE foo(x INTEGER PRIMARY KEY, value TEXT default '' NOT NULL,
                                desc TEXT default '');
                CREATE VIEW foo_bar AS SELECT x, desc FROM foo WHERE value = 'bar';
                CREATE TRIGGER INSERT_FOOBAR
                INSTEAD OF INSERT
                ON foo_bar
                BEGIN
                    INSERT INTO foo VALUES(new.x, 'bar', new.desc);
                END;"""

    db.execute_batch(sql)
    var total_changes_before = db.total_changes()
    var stmt = db.prepare("INSERT INTO foo_bar VALUES(null, 'baz');")
    var changes = stmt.execute()
    var total_changes_after = db.total_changes()
    assert_equal(changes, 0)
    assert_equal(total_changes_after - total_changes_before, 1)


fn test_is_autocommit() raises:
    var db = Connection.open_in_memory()
    assert_true(db.is_autocommit())


fn test_column_exists() raises:
    var db = Connection.open_in_memory()
    # Check column exists in sqlite_master table
    assert_true(db.column_exists(None, "sqlite_master", "type"))
    assert_true(db.column_exists("temp", "sqlite_master", "type"))
    assert_false(db.column_exists("main", "sqlite_temp_master", "type"))


fn test_table_exists() raises:
    var db = Connection.open_in_memory()
    # Check that sqlite_master table exists
    assert_true(db.table_exists(None, "sqlite_master"))
    assert_true(db.table_exists("temp", "sqlite_master"))
    assert_false(db.table_exists("main", "sqlite_temp_master"))


fn test_column_metadata() raises:
    var db = Connection.open_in_memory()
    
    # Get column metadata for the 'type' column in sqlite_master table
    var metadata = db.column_metadata(None, "sqlite_master", "type")
    
    # Check data type (should be TEXT)
    var data_type = metadata.data_type
    if data_type:
        assert_equal(data_type.value().upper(), "TEXT")
    
    # Check collation sequence (should be BINARY)
    var coll_seq = metadata.collation_sequence
    if coll_seq:
        assert_equal(coll_seq.value(), "BINARY")
    
    # Check constraints
    assert_false(metadata.not_null)
    assert_false(metadata.primary_key)
    assert_false(metadata.auto_increment)
    
    # Test that querying non-existent column raises an error
    with assert_raises():
        _ = db.column_metadata(None, "sqlite_master", "foo")


# TODO: Need to work on this.
# fn test_is_busy() raises:
#     var db = Connection.open_in_memory()
#     try:
#         assert_false(db.is_busy())
#         var stmt = db.prepare("PRAGMA schema_version")
#         assert_false(db.is_busy())
        
#         var rows = stmt.query()
#         assert_false(db.is_busy())
#         var row = rows.__next__()
#         assert_false(db.is_busy())
#     finally:
#         db^.close()


fn test_statement_debugging() raises:
    var db = Connection.open_in_memory()
    var query = "SELECT 12345"
    var stmt = db.prepare(query)
    var repr = stmt.__repr__()
    assert_true(query in repr)


fn test_notnull_constraint_error() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo(x NOT NULL)")
    
    with assert_raises(contains="constraint"):
        _ = db.execute("INSERT INTO foo (x) VALUES (NULL)")


# Skipping test_version_string, test_interrupt, test_interrupt_close as they require special functions


fn test_get_raw() raises:
    var db = Connection.open_in_memory()
    var vals: List[String] = ["foobar", "1234", "qwerty"]
    
    db.execute_batch("CREATE TABLE foo(i, x);")
    var insert_stmt = db.prepare("INSERT INTO foo(i, x) VALUES(?1, ?2)")
    
    for i in range(len(vals)):
        assert_equal(insert_stmt.execute([i, vals[i]]), 1)
    
    # TODO: Add tests for get_ref and as_str methods when implemented
    var query = db.prepare("SELECT i, x FROM foo")
    for row in query.query():
        var i = row.get[Int](0)
        var x = row.get[String](1)
        assert_equal(x, vals[i])


# Skipping test_from_handle, test_from_handle_owned, query_and_then_tests as they require unsafe operations


fn test_dynamic() raises:
    var db = Connection.open_in_memory()
    var sql = """CREATE TABLE foo(x INTEGER, y TEXT);
    INSERT INTO foo VALUES(4, 'hello');"""
    
    fn check_columns(r: Row) raises -> NoneType:
        # TODO: column_count() method not yet implemented
        assert_equal(r.stmt[].column_count(), 2)
        return None
    
    db.execute_batch(sql)
    _ = db.query_row[check_columns]("SELECT * FROM foo")


fn test_params() raises:
    var db = Connection.open_in_memory()
    
    fn get_int(r: Row) raises -> Int:
        return r.get[Int](0)
    
    var result = db.query_row[get_int]("""
    SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10,
    ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20,
    ?21, ?22, ?23, ?24, ?25, ?26, ?27, ?28, ?29, ?30,
    ?31, ?32, ?33, ?34
    """, [
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    ]
    )
    assert_equal(result, 1)


fn test_alter_table() raises:
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE x(t);")
    db.execute_batch("ALTER TABLE x RENAME TO y;")




# Skipping test_batch, test_invalid_batch, test_returning as they require Batch type


# fn test_cache_flush() raises:
#     var db = Connection.open_in_memory()
#     try:
#         # TODO: cache_flush() method not yet implemented
#         # db.cache_flush()
#         pass
#     finally:
#         db^.close()


# fn test_db_is_read_only() raises:
#     var db = Connection.open(":memory:", OpenFlag.READ_ONLY)
#     assert_false(db.is_read_only("main"))


# Skipping prepare_and_bind, test_db_name, test_is_interrupted, release_memory
# as they require features not yet implemented


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()