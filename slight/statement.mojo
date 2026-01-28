from sys import stderr
from os import abort
from utils.variant import Variant
from slight.result import SQLite3Result
from slight.c.raw_bindings import sqlite3_stmt
from slight.c.sqlite_string import SQLiteMallocString
from slight.c.types import (
    DataType,
    DestructorHint,
    ResultDestructorFn,
    MutExternalPointer,
)
from slight.connection import Connection
from slight.params import Params, List
from slight.raw_statement import RawStatement
from slight.row import Row, Rows, TypedRows, MappedRows
from slight.types.value_ref import SQLite3Blob, SQLite3Integer, SQLite3Null, SQLite3Real, SQLite3Text, ValueRef
from slight.types.from_sql import FromSQL
from slight.types.to_sql import ToSQL


@fieldwise_init
@register_passable("trivial")
struct InvalidColumnIndexError(Movable, Writable):
    comptime msg = "InvalidColumnIndex: Index provided is greater than the number of columns."

    fn write_to[W: Writer, //](self, mut writer: W):
        writer.write_string(Self.msg)


@fieldwise_init
struct InvalidColumnNameError(Movable, Writable):
    comptime msg = "InvalidColumnNameError: Name provided does not match any column. Column name: "
    var column: String

    fn write_to[W: Writer, //](self, mut writer: W):
        writer.write_string(Self.msg)
        writer.write_string(self.column)



@fieldwise_init
struct InvalidColumnError(Movable, Writable):
    comptime msg = "InvalidColumnNameError: Name provided does not match any column. Column name: "
    var err: Variant[InvalidColumnNameError, InvalidColumnIndexError]

    @implicit
    fn __init__(out self, var e: InvalidColumnNameError):
        self.err = e^
    
    @implicit
    fn __init__(out self, e: InvalidColumnIndexError):
        self.err = e
    # fn write_to[W: Writer, //](self, mut writer: W):
    #     writer.write_string(self.err)
    #     writer.write_string(self.column)


fn eq_ignore_ascii_case(a: Span[Byte], b: Span[Byte]) -> Bool:
    """Compares two StringSlices for equality, ignoring ASCII case differences.

    Args:
        a: The first byte slice to compare.
        b: The second byte slice to compare.

    Returns:
        True if the byte slices are equal (case-insensitive), False otherwise.
    """
    if len(a) != len(b):
        return False

    for i in range(0, len(a)):
        var ac = a[i]
        var bc = b[i]

        if ac >= ord("A") and ac <= ord("Z"):
            ac = ac + 32  # Convert to lowercase

        if bc >= ord("A") and bc <= ord("Z"):
            bc = bc + 32  # Convert to lowercase

        if ac != bc:
            return False

    return True


struct Statement[conn: ImmutOrigin](Movable):
    """A prepared SQL statement that can be executed multiple times with different parameters.

    This struct wraps a SQLite prepared statement and provides methods for binding parameters,
    executing queries, and retrieving results. It automatically manages the lifecycle of the
    underlying SQLite statement.
    """

    var connection: Pointer[Connection, Self.conn]
    """A pointer to the SQLite connection that created this statement."""
    var stmt: RawStatement
    """The raw SQLite statement wrapper."""

    fn __init__(out self, connection: Pointer[Connection, Self.conn], var stmt: RawStatement):
        """Initializes a new Statement with the given connection and raw statement pointer.

        Args:
            connection: A pointer to the SQLite connection.
            stmt: The prepared SQLite statement.
        """
        self.connection = connection
        self.stmt = stmt^

    # TODO: When should statements be finalized? Also we shouldn't be absorbing the error.
    fn __del__(deinit self):
        """Destructor that automatically finalizes the statement.

        Note: This currently absorbs any errors that occur during finalization.
        """
        try:
            self^.finalize()
        except e:
            print("Error finalizing statement:", e, file=stderr)

    fn __repr__(self) -> String:
        """Returns a string representation of the statement for debugging purposes."""
        var sql = String(self.sql().value()) if self.stmt else String("")
        return String("Statement(", sql, ")")

    fn column_count(self) -> UInt:
        """Returns the number of columns in the result set.

        Returns:
            The number of columns that will be returned by this statement.
        """
        return UInt(self.stmt.column_count())

    fn value_ref(self, col: UInt) -> ValueRef[origin_of(self)]:
        """Returns a reference to the value in the specified column of the current row.

        `sqlite3` behavior can be found here: https://sqlite.org/c3ref/column_blob.html

        Args:
            col: The column index (0-based).

        Returns:
            A ValueRef containing the column's value with its appropriate type.
        """
        # TODO: Generally need to handle nulls here, for now we're kind of asserting that
        # data requested via this function is not null.
        var column_type = self.stmt.column_type(col)
        if DataType.NULL == column_type:
            return ValueRef[origin_of(self)](SQLite3Null())
        elif DataType.INTEGER == column_type:
            return ValueRef[origin_of(self)](SQLite3Integer(self.stmt.column_int64(col)))
        elif DataType.FLOAT == column_type:
            return ValueRef[origin_of(self)](SQLite3Real(self.stmt.column_double(col)))
        elif DataType.TEXT == column_type:
            try:
                return ValueRef[origin_of(self)](SQLite3Text(
                    StringSlice(unsafe_from_utf8_ptr=self.stmt.column_text(col).unsafe_origin_cast[origin_of(self)]()))
                )
            except e:
                abort(String(e))
        elif DataType.BLOB == column_type:
            try:
                return ValueRef[origin_of(self)](SQLite3Blob(self.stmt.column_blob(col)))
            except e:
                abort(String(e))
        else:
            abort(String("[UNREACHABLE] sqlite3_column_type returned an invalid value: ", column_type))

    fn finalize(deinit self) raises -> None:
        """Finalizes the statement and releases its resources.

        After calling this method, the statement should not be used again.

        Raises:
            Error: If the finalization fails.
        """
        self.connection[].raise_if_error(self.stmt^.finalize())

    fn step(self) raises -> Bool:
        """Executes the statement and advances to the next row.

        Returns:
            True if a row is available, False if execution is complete.

        Raises:
            Error: If an error occurs during statement execution.
        """
        var r = self.stmt.step()
        if r == SQLite3Result.ROW:
            return True
        elif r == SQLite3Result.DONE:
            return False
        else:
            var error = self.connection[].error_msg(r)
            if error:
                raise Error(error[])
            else:
                raise Error("Unknown error occurred during step execution: ", r)

    fn reset(self) raises -> None:
        """Resets the statement to its initial state for re-execution.

        This allows the statement to be executed again with the same or different
        bound parameter values.

        Raises:
            Error: If the reset operation fails.
        """
        self.connection[].raise_if_error(self.stmt.reset())

    fn _execute(self) raises -> Int64:
        """Executes the statement.

        This is a private function meant to be called by the public execute methods, which handle parameter binding.
        This method is intended for statements that don't return rows (INSERT, UPDATE, DELETE).
        For SELECT statements, use `query()` instead.

        Returns:
            The number of database rows that were changed, inserted, or deleted.

        Raises:
            Error: If the statement returns rows (use `query()` for SELECT statements),
                   or if any other error occurs during execution.
        """
        # TODO: check update
        var r = self.stmt.step()
        var rr = self.stmt.reset()

        if r == SQLite3Result.DONE:
            self.connection[].raise_if_error(rr)
            return self.connection[].changes()
        elif r == SQLite3Result.ROW:
            raise Error("Query returned rows.")
        else:
            var error = self.connection[].error_msg(r)
            if error:
                raise Error(error[])
            else:
                raise Error("Unknown error occurred during step execution: ", r)
    
    fn execute[T: Params, //](self, params: T) raises -> Int64:
        """Executes the statement with the given parameters and returns the number of affected rows.

        This method is intended for statements that don't return rows (INSERT, UPDATE, DELETE).
        For SELECT statements, use query() instead.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            The number of database rows that were changed, inserted, or deleted.

        Raises:
            Error: If the statement returns rows (use query() for SELECT statements),
                   or if any other error occurs during execution.
        """
        params.bind(self)
        return self._execute()
    
    fn execute[*Ts: ToSQL](self, *params: *Ts) raises -> Int64:
        """Executes the statement with the given parameters and returns the number of affected rows.

        This method is intended for statements that don't return rows (INSERT, UPDATE, DELETE).
        For SELECT statements, use query() instead.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            The number of database rows that were changed, inserted, or deleted.

        Raises:
            Error: If the statement returns rows (use query() for SELECT statements),
                   or if any other error occurs during execution.
        """
        self.bind_parameters(params)
        return self._execute()
    
    fn execute[*Ts: ToSQL](self, params: VariadicPack[_, ToSQL, *Ts]) raises -> Int64:
        """Executes the statement with the given parameters and returns the number of affected rows.

        This method is intended for statements that don't return rows (INSERT, UPDATE, DELETE).
        For SELECT statements, use query() instead.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            The number of database rows that were changed, inserted, or deleted.

        Raises:
            Error: If the statement returns rows (use query() for SELECT statements),
                   or if any other error occurs during execution.
        """
        self.bind_parameters(params)
        return self._execute()

    fn bind_null(self, index: UInt) raises -> None:
        """Binds a NULL value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.

        Raises:
            Error: If the bind operation fails.
        """
        self.connection[].raise_if_error(self.stmt.bind_null(index))

    fn bind_int64(self, index: UInt, value: Int64) raises -> None:
        """Binds a 64-bit integer value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The integer value to bind.

        Raises:
            Error: If the bind operation fails.
        """
        self.connection[].raise_if_error(self.stmt.bind_int64(index, value))

    fn bind_double(self, index: UInt, value: Float64) raises -> None:
        """Binds a double-precision float value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The float value to bind.

        Raises:
            Error: If the bind operation fails.
        """
        self.connection[].raise_if_error(self.stmt.bind_double(index, value))

    fn bind_text(self, index: UInt, var value: String, destructor_callback: ResultDestructorFn) raises -> None:
        """Binds a text string value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The string value to bind.
            destructor_callback: The destructor function to call when SQLite is done with the text.

        Raises:
            Error: If the bind operation fails.
        """
        self.connection[].raise_if_error(self.stmt.bind_text(index, value, destructor_callback))
    
    fn bind_blob(self, index: UInt, value: Span[Byte], destructor_callback: ResultDestructorFn) raises -> None:
        """Binds a blob value to the specified parameter.

        Args:
            index: The 1-based index of the parameter to bind.
            value: The blob value to bind.
            destructor_callback: The destructor function to call when SQLite is done with the blob.

        Raises:
            Error: If the bind operation fails.
        """
        self.connection[].raise_if_error(self.stmt.bind_blob(index, value, destructor_callback))

    fn parameter_index(self, var name: String) -> Optional[UInt]:
        """Returns the index of the parameter with the specified name.

        Args:
            name: The name of the parameter (e.g., ":param", "@param", "$param").

        Returns:
            The 1-based index of the parameter.
        """
        return self.stmt.bind_parameter_index(name^)
    
    fn bind_parameter[T: ToSQL, //](self, parameter: T, index: UInt) raises:
        """Binds a parameter to a specific position in the statement.

        Args:
            parameter: The parameter value to bind.
            index: The position where to bind the parameter.

        Raises:
            Error: If the parameter type is unsupported or binding fails.
        """
        var value = parameter.to_sql()
        if value.isa[SQLite3Null]():
            self.bind_null(index)
        elif value.isa[SQLite3Text[value.stmt]]():
            # TODO: Don't copy the string here if possible
            self.bind_text(index, String(value[SQLite3Text[value.stmt]].value), DestructorHint.transient_destructor())
        elif value.isa[SQLite3Integer]():
            self.bind_int64(index, value[SQLite3Integer].value)
        elif value.isa[SQLite3Real]():
            self.bind_double(index, value[SQLite3Real].value)
        elif value.isa[SQLite3Blob[value.stmt]]():
            self.bind_blob(index, value[SQLite3Blob[value.stmt]].value, DestructorHint.transient_destructor())
        else:
            raise Error("Unsupported parameter type")
    
    fn bind_parameters[*Ts: ToSQL](self, params: VariadicPack[_, ToSQL, *Ts]) raises -> None:
        """Binds a list of parameters to the statement in order.

        Args:
            params: List of parameter values to bind to the statement.

        Raises:
            Error: If the number of parameters doesn't match what the statement expects
                   or if any parameter binding fails.
        """
        var expected = Int(self.stmt.bind_parameter_count())
        var index = 0

        # for p in params:
        @parameter
        for i in range(params.__len__()):
            index += 1  # The leftmost SQL parameter has an index of 1.
            if index > expected:
                break
            self.bind_parameter(params[i], UInt(index))
        if index != expected:
            raise Error("Invalid parameter count: ", index, ", expected: ", expected)
    
    fn query[T: Params, //](self, params: T) raises -> Rows[Self.conn, origin_of(self)]:
        """Executes the statement as a query and returns an iterator over the result rows.

        This method is intended for SELECT statements that return data.
        For non-SELECT statements, use execute() instead.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A Rows iterator for iterating over the query results.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        params.bind(self)
        return Rows(Pointer(to=self))
    
    fn query[*Ts: ToSQL](self, *params: *Ts) raises -> Rows[Self.conn, origin_of(self)]:
        """Executes the statement as a query and returns an iterator over the result rows.

        This method is intended for SELECT statements that return data.
        For non-SELECT statements, use execute() instead.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A Rows iterator for iterating over the query results.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        self.bind_parameters(params)
        return Rows(Pointer(to=self))
    
    fn query[*Ts: ToSQL](self, params: VariadicPack[_, ToSQL, *Ts]) raises -> Rows[Self.conn, origin_of(self)]:
        """Executes the statement as a query and returns an iterator over the result rows.

        This method is intended for SELECT statements that return data.
        For non-SELECT statements, use execute() instead.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A Rows iterator for iterating over the query results.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        self.bind_parameters(params)
        return Rows(Pointer(to=self))
    
    fn query_map[
        T: Movable, P: Params, //, transform: fn (Row) raises -> T
    ](self, params: P) raises -> MappedRows[Self.conn, origin_of(self), transform]:
        """Executes the query and returns a mapped iterator that transforms each row.

        This method applies a transformation function to each row returned by the query,
        allowing you to convert database rows into custom types.

        Parameters:
            T: The type that each row will be transformed into.
            P: The type of the parameters to bind.
            transform: A function that takes a Row and returns a value of type T.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A MappedRows iterator that yields transformed values of type T.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        return MappedRows[Self.conn, origin_of(self), transform](self.query(params))

    fn query_map[
        T: Movable, //, transform: fn (Row) raises -> T, *Ts: ToSQL
    ](self, *params: *Ts) raises -> MappedRows[Self.conn, origin_of(self), transform]:
        """Executes the query and returns a mapped iterator that transforms each row.

        This method applies a transformation function to each row returned by the query,
        allowing you to convert database rows into custom types.

        Parameters:
            T: The type that each row will be transformed into.
            transform: A function that takes a Row and returns a value of type T.
            Ts: The types of the parameters to bind.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A MappedRows iterator that yields transformed values of type T.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        return MappedRows[Self.conn, origin_of(self), transform](self.query(params))

    fn query_row[
        T: Movable, P: Params, //, transform: fn (Row) raises -> T
    ](self, params: P) raises -> T:
        """Executes the query and returns a single row.

        This is a convenience method for queries that are expected to return exactly one row.
        If the query returns more than one row, the rest are ignored.

        Parameters:
            T: The type that the row will be transformed into.
            P: The type of the parameters to bind.
            transform: A function that takes a Row and returns a value of type T.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            The single Row returned by the query.

        Raises:
            Error: If parameter binding fails, no rows are returned, or more than one row is returned.
        """
        var rows = self.query(params)
        var row: Row[Self.conn, origin_of(self)]
        try:
            row = rows.__next__()
        except StopIteration:
            raise Error("No rows returned by query.")
        
        return transform(row)

    fn query_row[
        T: Movable, //, transform: fn (Row) raises -> T, *Ts: ToSQL
    ](self, *params: *Ts) raises -> T:
        """Executes the query and returns a single row.

        This is a convenience method for queries that are expected to return exactly one row.
        If the query returns more than one row, the rest are ignored.

        Parameters:
            T: The type that the row will be transformed into.
            transform: A function that takes a Row and returns a value of type T.
            Ts: The types of the parameters to bind.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            The single Row returned by the query.

        Raises:
            Error: If parameter binding fails, no rows are returned, or more than one row is returned.
        """
        var rows = self.query(params)
        var row: Row[Self.conn, origin_of(self)]
        try:
            row = rows.__next__()
        except StopIteration:
            raise Error("No rows returned by query.")
        
        return transform(row)
    
    fn query_row[
        T: Movable, //, transform: fn (Row) raises -> T, *Ts: ToSQL
    ](self, params: VariadicPack[_, ToSQL, *Ts]) raises -> T:
        """Executes the query and returns a single row.

        This is a convenience method for queries that are expected to return exactly one row.
        If the query returns more than one row, the rest are ignored.

        Parameters:
            T: The type that the row will be transformed into.
            transform: A function that takes a Row and returns a value of type T.
            Ts: The types of the parameters to bind.
        
        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            The single Row returned by the query.

        Raises:
            Error: If parameter binding fails, no rows are returned, or more than one row is returned.
        """
        var rows = self.query(params)
        var row: Row[Self.conn, origin_of(self)]
        try:
            row = rows.__next__()
        except StopIteration:
            raise Error("No rows returned by query.")
        
        return transform(row)
    
    fn query_as_type[
        P: Params, //, T: Defaultable & Movable,
    ](self, params: P) raises -> TypedRows[Self.conn, origin_of(self), T]:
        """Executes the query and returns a mapped iterator that transforms each row.

        This method applies a transformation function to each row returned by the query,
        allowing you to convert database rows into custom types.

        Parameters:
            P: The type of the parameters to bind.
            T: The type that each row will be transformed into.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A MappedRows iterator that yields transformed values of type T.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        return TypedRows[Self.conn, origin_of(self), T](self.query(params))

    fn query_as_type[
        T: Defaultable & Movable, *Ts: ToSQL
    ](self, *params: *Ts) raises -> TypedRows[Self.conn, origin_of(self), T]:
        """Executes the query and returns a mapped iterator that transforms each row.

        This method applies a transformation function to each row returned by the query,
        allowing you to convert database rows into custom types.

        Parameters:
            T: The type that each row will be transformed into.
            Ts: The types of the parameters to bind.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            A MappedRows iterator that yields transformed values of type T.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        return TypedRows[Self.conn, origin_of(self), T](self.query(params))

    fn exists[T: Params, //](self, params: T) raises -> Bool:
        """Checks if the query returns at least one row.

        This is a convenience method that executes the query and returns True
        if any rows are found, False otherwise. It's more efficient than
        counting all rows when you only need to know if results exist.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            True if the query returns at least one row, False otherwise.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        var rows = self.query(params)
        try:
            _ = rows.__next__()
            return True
        except StopIteration:
            return False

    fn exists[*Ts: ToSQL](self, *params: *Ts) raises -> Bool:
        """Checks if the query returns at least one row.

        This is a convenience method that executes the query and returns True
        if any rows are found, False otherwise. It's more efficient than
        counting all rows when you only need to know if results exist.

        Args:
            params: A list of parameters to bind to the statement.

        Returns:
            True if the query returns at least one row, False otherwise.

        Raises:
            Error: If parameter binding fails or the query execution fails.
        """
        var rows = self.query(params)
        try:
            _ = rows.__next__()
            return True
        except StopIteration:
            return False

    fn clear_bindings(self) raises -> None:
        """Clears all bound parameters from the statement.

        This resets the statement's parameter bindings, allowing you to
        bind new values before re-executing the statement.

        Raises:
            Error: If clearing bindings fails.
        """
        self.connection[].raise_if_error(self.stmt.clear_bindings())

    fn sql(self) -> Optional[StringSlice[origin_of(self.stmt)]]:
        """Returns the original SQL text of the prepared statement.

        Returns:
            The original SQL statement as a StringSlice.
        """
        return self.stmt.sql()

    fn expanded_sql(self) raises -> Optional[String]:
        """Returns the SQL text of the prepared statement with bound parameters expanded.

        Returns:
            The SQL statement with parameter values substituted.

        Raises:
            Error: If the expanded SQL is NULL.
        """
        var sql = self.stmt.expanded_sql()
        if not sql:
            return None

        return String(sql.value().as_string_slice())

    fn column_name(self, idx: UInt) raises -> StringSlice[origin_of(self)]:
        """Returns the name of the column at the specified index.

        Args:
            idx: The column index (0-based).

        Returns:
            The name of the column as a StringSlice.

        Raises:
            InvalidColumnIndexError: If the column index is out of bounds.
        """
        var name = self.stmt.column_name(idx)
        if not name:
            raise Error("InvalidColumnIndexError: column index is out of bounds.")

        return StringSlice(unsafe_from_utf8_ptr=name.value().unsafe_origin_cast[origin_of(self)]())

    fn column_index(self, name: StringSlice) raises -> UInt:
        """Returns the index of the column with the specified name.

        Args:
            name: The name of the column.

        Returns:
            The column index (0-based).

        Raises:
            InvalidColumnNameError: If no column with the specified name exists.
        """
        for i in range(0, self.column_count()):
            # Note: `column_name` is only fallible if `i` is out of bounds,
            # which we've already checked.
            if eq_ignore_ascii_case(name.as_bytes(), self.column_name(i).as_bytes()):
                return i 
            
        raise Error("InvalidColumnNameError: no column with the specified name exists.")
    
    fn insert[T: Params, //](self, params: T) raises -> Int64:
        """Executes an INSERT statement and returns the last inserted row ID.

        This is a convenience method for executing INSERT statements that
        return the last inserted row ID. It ensures that exactly one row
        was inserted.

        Returns:
            The last inserted row ID.

        Raises:
            Error: If the number of affected rows is not exactly one,
            or if any error occurs during execution.
        """
        var changes = self.execute(params)
        if changes == 1:
            return self.connection[].last_insert_row_id()
        else:
            raise Error("StatementChangedRows: Expected 1 row to be inserted, but ", changes, " rows were affected.")

    fn insert[*Ts: ToSQL](self, *params: *Ts) raises -> Int64:
        """Executes an INSERT statement and returns the last inserted row ID.

        This is a convenience method for executing INSERT statements that
        return the last inserted row ID. It ensures that exactly one row
        was inserted.

        Returns:
            The last inserted row ID.

        Raises:
            Error: If the number of affected rows is not exactly one,
            or if any error occurs during execution.
        """
        var changes = self.execute(params)
        if changes == 1:
            return self.connection[].last_insert_row_id()
        else:
            raise Error("StatementChangedRows: Expected 1 row to be inserted, but ", changes, " rows were affected.")

    fn is_explain(self) -> Int32:
        """Returns whether the prepared statement is an EXPLAIN statement.

        * 1 if the prepared statement is an EXPLAIN statement,
        * 2 if the statement is an EXPLAIN QUERY PLAN,
        * 0 if it is an ordinary statement or a NULL pointer.
        """
        return self.stmt.is_explain()

    fn is_read_only(self) -> Bool:
        """Returns whether the prepared statement is read-only."""
        return self.stmt.is_read_only()

    fn column_names(self) raises -> List[StringSlice[origin_of(self)]]:
        """Get all the column names in the result set of the prepared statement.

        If associated DB schema can be altered concurrently, you should make
        sure that current statement has already been stepped once before
        calling this method.

        Returns:
            A list of column names.

        Raises:
            InvalidColumnIndexError: If a column index is out of bounds.
        """
        var n = self.column_count()
        var cols = List[StringSlice[origin_of(self)]](capacity=Int(n))
        for i in range(n):
            cols.append(self.column_name(i))
        return cols^
