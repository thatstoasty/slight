"""Serialize / Deserialize Examples.

This example demonstrates how to copy an in-memory SQLite database into a
byte buffer and load it back, e.g. to snapshot, transmit, or clone a
database that has no backing file on disk.
"""

from slight.connection import Connection
from slight.row import Row


def example_serialize_and_deserialize() raises:
    """Serializes a database and loads it into a fresh connection."""
    print("=== Serialize / Deserialize Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
        INSERT INTO users VALUES (1, 'Alice');
        INSERT INTO users VALUES (2, 'Bob');
    """)

    # Serialize copies the database (in the standard SQLite file format) into
    # an in-memory buffer. This works even though there's no file on disk.
    var data = db.serialize()
    print("Serialized database to", len(data), "bytes")

    # Deserialize loads that buffer into another connection, replacing its
    # current contents.
    var copy = Connection.open_in_memory()
    copy.deserialize(data^)

    print("Users in the deserialized copy:")
    var stmt = copy.prepare("SELECT id, name FROM users ORDER BY id")
    for row in stmt.query():
        print("  ", row.get[Int](0), ":", row.get[String](1))


def example_deserialize_read_only() raises:
    """Demonstrates loading a serialized database as read-only."""
    print("\n=== Read-Only Deserialize Example ===")
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE counters (value INTEGER); INSERT INTO counters VALUES (0);")
    var data = db.serialize()

    var snapshot = Connection.open_in_memory()
    snapshot.deserialize(data^, read_only=True)

    try:
        _ = snapshot.execute("UPDATE counters SET value = value + 1")
        print("Unexpected: write succeeded on a read-only snapshot")
    except e:
        print("Write rejected, as expected:", e)


def main() raises:
    example_serialize_and_deserialize()
    example_deserialize_read_only()
