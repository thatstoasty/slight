from slight.connection import Connection
from slight.vtab.csvtab import load_module


def main() raises:
    var conn = Connection.open_in_memory()
    load_module(conn)
    conn.execute_batch(
        "CREATE VIRTUAL TABLE people USING csv(filename='sample.csv', header=yes)"
    )

    print("All rows:")
    var stmt = conn.prepare(
        "SELECT rowid, name, age, city, role FROM people ORDER BY rowid"
    )
    for row in stmt.query():
        print(
            row.get[Int64](0),
            row.get[String](1),
            row.get[String](2),
            row.get[String](3),
            row.get[String](4),
        )

    print("\nEngineers:")
    stmt = conn.prepare(
        "SELECT name, city FROM people WHERE role = 'Engineer' ORDER BY name"
    )
    for row in stmt.query():
        print(row.get[String](0), "-", row.get[String](1))

    stmt = conn.prepare("SELECT COUNT(*) FROM people")
    for row in stmt.query():
        print("\nTotal people:", row.get[Int64](0))
