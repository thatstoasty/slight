"""Minimal test: create CSV vtab and run a SELECT."""
from slight.connection import Connection
from slight.csvtab import csv_connect, csv_best_index, csv_open, csv_filter, csv_next, csv_eof, csv_column, csv_rowid, CsvState, CsvCursor


def main() raises:
    var conn = Connection.open_in_memory()
    conn.create_module[
        CsvState,
        CsvCursor,
        csv_connect,
        csv_best_index,
        csv_open,
        csv_filter,
        csv_next,
        csv_eof,
        csv_column,
        csv_rowid,
    ]("csv")
    print("Module registered OK")
    conn.execute_batch(
        "CREATE VIRTUAL TABLE vtab USING csv(filename='rusqlite/test.csv', header=yes)"
    )
    print("CREATE VIRTUAL TABLE OK")
    var stmt = conn.prepare("SELECT * FROM vtab LIMIT 1")
    print("prepare OK")
    for row in stmt.query():
        print("row:", row.get[String](0))
