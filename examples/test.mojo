from slight.connection import Connection
from slight.row import Row
from slight import Int, Bool, SIMD, Dict, List

comptime dummy_int: Int = 1
comptime dummy_float: Float64 = 1.0
comptime dummy_string: String = ""


@fieldwise_init
struct Employee(Copyable, Movable, Writable):
    var id: Int
    var name: String
    var age: Int8
    var address: String
    var salary: Float64
    var is_active: Bool

    fn write_to[W: Writer, //](self, mut writer: W):
        writer.write("Employee(id=", self.id, ", name=", self.name, ", age=", self.age, ", address=", self.address, ", salary=", self.salary, ", is_active=", self.is_active, ")")


fn main() raises:
    var db = Connection.open_in_memory()
    print("Connected to the database successfully.")
    print("Database path:", db.path().value())
    print("Creating table...")
    db.execute_batch("""
    CREATE TABLE COMPANY(
        ID INT PRIMARY KEY NOT NULL,
        NAME TEXT NOT NULL,
        AGE INT NOT NULL,
        ADDRESS CHAR(50),
        SALARY REAL,
        IS_ACTIVE BOOLEAN NOT NULL
    );
    """)

    print("Inserting data...")
    print(db.execute("""
    INSERT INTO COMPANY (ID, NAME, AGE, ADDRESS, SALARY, IS_ACTIVE) VALUES 
    (1, 'Bob', 30, '123 Main St', 45000.0, False),
    (2, 'Alice', 30, '123 Main St', 50000.0, True);
    """), "row(s) affected.")

    var stmt = db.prepare("SELECT * FROM COMPANY WHERE NAME = ?;")
    print(stmt.sql().value())
    for row in stmt.query(["Alice"]):
        print("Alice ID:", row.get[Int]("id"))
        
    stmt = db.prepare("SELECT * FROM COMPANY;")
    for row in stmt.query():
        print("Row ID:", row.get[Int](0))
        print("Name:", row.get[String](1))
        print("Age:", row.get[Int](2))
        print("Salary:", row.get[Float64](4))
        print("Active:", row.get[Bool](5))
        print("---")

    fn transform_row(row: Row) raises -> Employee:
        return Employee(
            id=row.get[Int](0),
            name=row.get[String](1),
            age=row.get[Int](2),
            address=row.get[String](3),
            salary=row.get[Float64](4),
            is_active=row.get[Bool](5)
        )

    stmt = db.prepare("SELECT * FROM COMPANY;")
    for row in stmt.query_map[transform=transform_row]():
        print(row)

    db^.close()
