from slight.connection import Connection
from slight.row import Row
from slight import Int, Bool, SIMD, Dict, List

comptime dummy_int: Int = 1
comptime dummy_float: Float64 = 1.0


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

    fn transform_row(row: Row) raises -> Employee:
        return Employee(
            id=row.get[Int](0),
            name=row.get[String](1),
            age=row.get[Int8](2),
            address=row.get[String](3),
            salary=row.get[Float64](4),
            is_active=row.get[Bool](5)
        )

    # query_row returns a single row transformed into an Employee struct.
    # For convenience, we can also call it directly on the Connection which will
    # prepare the statement for us internally.
    stmt = db.prepare("SELECT * FROM COMPANY LIMIT 1;")
    print("Employee:", stmt.query_row[transform=transform_row]())
    print("Employee:", db.query_row[transform_row]("SELECT * FROM COMPANY LIMIT 1;"))

    # query_map returns an iterator which transforms rows into Employee structs.
    stmt = db.prepare("SELECT * FROM COMPANY;")
    print("All Employees:")
    for row in stmt.query_map[transform=transform_row]():
        print(row)
