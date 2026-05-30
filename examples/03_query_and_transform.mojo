from slight.connection import Connection
from slight.row import Row


@fieldwise_init
struct Employee(Copyable, Writable, Defaultable):
    var id: Int
    var name: String
    var age: Int8
    var address: String
    var salary: Float64
    var is_active: Bool

    def __init__(out self):
        self.id = 0
        self.name = ""
        self.age = 0
        self.address = ""
        self.salary = 0.0
        self.is_active = False

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Employee(id=", self.id, ", name=", self.name, ", age=", self.age, ", address=", self.address, ", salary=", self.salary, ", is_active=", self.is_active, ")")


def main() raises:
    var db = Connection.open_in_memory()
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

    def transform_row(row: Row) raises -> Employee:
        return Employee(
            id=row.get[Int](0),
            name=row.get[String](1),
            age=row.get[Int8](2),
            address=row.get[String](3),
            salary=row.get[Float64](4),
            is_active=row.get[Bool](5)
        )

    # one_row returns a single row transformed into an Employee struct.
    # For convenience, we can call it directly on the Connection which will
    # prepare the statement for us internally. Connections cannot return row iterators, because
    # results are tied to the lifetime of the statement, so we have to use one_row for single rows and stmt.query for multiple rows.
    stmt = db.prepare("SELECT * FROM COMPANY LIMIT 1;")
    print("Employee:", db.one_row[transform_row]("SELECT * FROM COMPANY LIMIT 1;"))

    # query returns an iterator which transforms rows into Employee structs.
    stmt = db.prepare("SELECT * FROM COMPANY;")
    print("\nAll employees mapped by transform function:")
    for row in stmt.query[transform_row]():
        print(row)
    
    # Alternatively, we can call `.map` on the Rows iterator returned by `query`.
    # This will return a `MappedRows` iterator which applies the transform function on each row.
    stmt.reset()
    for row in stmt.query().map[transform_row]():
        print(row)
    
    # Finally, we can use `as_type` to directly map rows to Employee structs.
    stmt.reset()
    print("\nAll employees mapped by type:")
    for employee in stmt.query[Employee]():
        print(employee)
    
    # Same as with `query`, we can also call `as_type` on the `Rows` iterator returned by `query`.
    stmt.reset()
    for employee in stmt.query().as_type[Employee]():
        print(employee)
