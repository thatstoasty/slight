# from emberjson import to_string
# from slight.connection import Connection
# from slight.row import Row
# from slight.types.json import Value
# from std.testing import TestSuite, assert_equal, assert_raises, assert_true

# comptime dummy = Value(None)

# # ===----------------------------------------------------------------------=== #
# # Shared row-transform helpers
# # ===----------------------------------------------------------------------=== #


# def get_value(row: Row) raises -> Value:
#     return row.get[Value](0)


# def get_int64(row: Row) raises -> Int64:
#     return row.get[Int64](0)


# def get_float64(row: Row) raises -> Float64:
#     return row.get[Float64](0)


# def get_string(row: Row) raises -> String:
#     return row.get[String](0)


# # ===----------------------------------------------------------------------=== #
# # ToSQL tests  (JSON Value → SQLite parameter)
# # ===----------------------------------------------------------------------=== #


# def test_to_sql_null() raises:
#     """JSON Null bound as a parameter stores SQLite NULL, which round-trips as JSON Null."""
#     var db = Connection.open_in_memory()
#     db.execute_batch("CREATE TABLE t (v TEXT)")
#     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(None)])
#     var v = db.one_row[get_value]("SELECT v FROM t")
#     assert_true(v.is_null())


# # def test_to_sql_integer() raises:
# #     """JSON Int64 binds as SQLite INTEGER."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v INTEGER)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(Int64(42))])
# #     assert_equal(db.one_row[get_int64]("SELECT v FROM t"), Int64(42))


# # def test_to_sql_uint() raises:
# #     """JSON UInt64 binds as SQLite INTEGER (cast to Int64)."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v INTEGER)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(UInt64(99))])
# #     assert_equal(db.one_row[get_int64]("SELECT v FROM t"), Int64(99))


# # def test_to_sql_float() raises:
# #     """JSON Float64 binds as SQLite REAL."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v REAL)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(Float64(3.14))])
# #     assert_equal(db.one_row[get_float64]("SELECT v FROM t"), Float64(3.14))


# # def test_to_sql_string() raises:
# #     """JSON String binds as SQLite TEXT (the raw string value, not JSON-encoded)."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(String("hello"))])
# #     assert_equal(db.one_row[get_string]("SELECT v FROM t"), "hello")


# # def test_to_sql_bool_true() raises:
# #     """JSON Bool true binds as SQLite INTEGER 1."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v INTEGER)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(True)])
# #     assert_equal(db.one_row[get_int64]("SELECT v FROM t"), Int64(1))


# # def test_to_sql_bool_false() raises:
# #     """JSON Bool false binds as SQLite INTEGER 0."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v INTEGER)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [Value(False)])
# #     assert_equal(db.one_row[get_int64]("SELECT v FROM t"), Int64(0))


# # def test_to_sql_object_raises() raises:
# #     """Binding a JSON Object raises a descriptive error."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     var obj = Value(parse_string='{"key": 1}')
# #     with assert_raises(contains="ToSQLError"):
# #         _ = db.execute("INSERT INTO t VALUES (?1)", [obj.copy()])


# # def test_to_sql_array_raises() raises:
# #     """Binding a JSON Array raises a descriptive error."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     var arr = Value(parse_string="[1, 2, 3]")
# #     with assert_raises(contains="ToSQLError"):
# #         _ = db.execute("INSERT INTO t VALUES (?1)", [arr.copy()])


# # # ===----------------------------------------------------------------------=== #
# # # FromSQL tests  (SQLite column → JSON Value)
# # # ===----------------------------------------------------------------------=== #


# # def test_from_sql_null() raises:
# #     """SQLite NULL column deserializes to JSON Null."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT); INSERT INTO t VALUES (NULL)")
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_null())


# # def test_from_sql_integer() raises:
# #     """SQLite INTEGER column deserializes to JSON Int64 number."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v INTEGER); INSERT INTO t VALUES (7)")
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_int())
# #     assert_equal(v.int(), Int64(7))


# # def test_from_sql_real() raises:
# #     """SQLite REAL column deserializes to JSON Float64 number."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v REAL); INSERT INTO t VALUES (2.5)")
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_float())
# #     assert_equal(v.float(), Float64(2.5))


# # def test_from_sql_text_string() raises:
# #     """SQLite TEXT containing a JSON-encoded string deserializes to JSON String."""
# #     var db = Connection.open_in_memory()
# #     # Store the JSON text '"world"' (with surrounding double quotes).
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [String('"world"')])
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_string())
# #     assert_equal(v.string(), "world")


# # def test_from_sql_text_null() raises:
# #     """SQLite TEXT 'null' deserializes to JSON Null."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT); INSERT INTO t VALUES ('null')")
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_null())


# # def test_from_sql_text_bool() raises:
# #     """SQLite TEXT 'true' deserializes to JSON Bool true."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT); INSERT INTO t VALUES ('true')")
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_bool())
# #     assert_true(v.bool())


# # def test_from_sql_text_object() raises:
# #     """SQLite TEXT containing a JSON object deserializes to JSON Object."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [String('{"x":1}')])
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_object())
# #     assert_equal(v.object()["x"].int(), Int64(1))


# # def test_from_sql_text_array() raises:
# #     """SQLite TEXT containing a JSON array deserializes to JSON Array."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [String("[10,20]")])
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_array())
# #     assert_equal(len(v.array()), 2)
# #     assert_equal(v.array()[0].int(), Int64(10))
# #     assert_equal(v.array()[1].int(), Int64(20))


# # def test_from_sql_text_invalid_json_raises() raises:
# #     """SQLite TEXT that is not valid JSON raises a parse error on read."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [String("not-json")])
# #     with assert_raises():
# #         _ = db.one_row[get_value]("SELECT v FROM t")


# # def test_roundtrip_object_via_to_string() raises:
# #     """JSON Object round-trips via explicit to_string() serialization and TEXT storage."""
# #     var db = Connection.open_in_memory()
# #     db.execute_batch("CREATE TABLE t (v TEXT)")
# #     var obj = Value(parse_string='{"score":99}')
# #     # Serialize to JSON string first (required for Object/Array).
# #     _ = db.execute("INSERT INTO t VALUES (?1)", [to_string(obj)])
# #     var v = db.one_row[get_value]("SELECT v FROM t")
# #     assert_true(v.is_object())
# #     assert_equal(v.object()["score"].int(), Int64(99))


# def main() raises:
#     TestSuite.discover_tests[__functions_in_module()]().run()
