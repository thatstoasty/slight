from slight.connection import Connection
from slight.row import Row
from slight import Int, Bool, SIMD, Dict, List

comptime dummy_int: Int = 1


fn main() raises:
    var db = Connection.open_in_memory()

    # Execute batch can be used to execute multiple statements at once.
    db.execute_batch("""
    CREATE TABLE COMPANY(
        ID INT PRIMARY KEY NOT NULL,
        NAME TEXT NOT NULL,
        AGE INT NOT NULL,
        ADDRESS CHAR(50),
        SALARY REAL,
        IS_ACTIVE BOOLEAN NOT NULL
    );
    INSERT INTO COMPANY (ID, NAME, AGE, ADDRESS, SALARY, IS_ACTIVE) VALUES 
    (1, 'Bob', 30, '123 Main St', 45000.0, False),
    (2, 'Alice', 30, '123 Main St', 50000.0, True);
    """)

    var stmt = db.prepare("SELECT * FROM COMPANY;")
    for row in stmt.query():
        print("Row ID:", row.get[Int](0))
        print("Name:", row.get[String](1))
        print("Age:", row.get[Int](2))
        print("Salary:", row.get[Float64](4))
        print("Active:", row.get[Bool](5))
        print("---")
