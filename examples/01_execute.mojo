from slight.connection import Connection
from slight.row import Row
from slight import Int, Bool, SIMD, Dict, List

comptime dummy_int: Int = 1


fn main() raises:
    var db = Connection.open_in_memory()

    # Execute statements to create table and insert data.
    # Executed statements should not return any results, the function returns the number of affected rows.
    _ = db.execute("""
    CREATE TABLE COMPANY(
        ID INT PRIMARY KEY NOT NULL,
        NAME TEXT NOT NULL,
        AGE INT NOT NULL,
        ADDRESS CHAR(50),
        SALARY REAL,
        IS_ACTIVE BOOLEAN NOT NULL
    );
    """)

    _ = db.execute("""
    INSERT INTO COMPANY (ID, NAME, AGE, ADDRESS, SALARY, IS_ACTIVE) VALUES 
    (1, 'Bob', 30, '123 Main St', 45000.0, False),
    (2, 'Alice', 30, '123 Main St', 50000.0, True);
    """)

    # Query is used to retrieve data, returning rows that can be iterated over.
    var stmt = db.prepare("SELECT * FROM COMPANY;")
    for row in stmt.query():
        # Rows are printable, but still require column level access or mapping to structs.
        # It's not perfect, BOOLEAN is stored as INT under the hood. So, it's printed as 0/1.
        print(row)

        # Accessing individual columns works as expected.
        print("Row ID:", row.get[Int](0))
        print("Name:", row.get[String](1))
        print("Age:", row.get[Int](2))
        print("Salary:", row.get[Float64](4))
        print("Active:", row.get[Bool](5))
        print("---")

    # The connection is closed automatically when the object is destroyed, but we can close it explicitly.
    db^.close()
