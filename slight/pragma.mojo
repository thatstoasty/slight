"""Pragma helpers for SQLite databases.

This module provides utilities for building and executing SQLite PRAGMA statements,
as well as helper methods for common pragma operations.
"""

from slight.types.to_sql import ToSQL
from slight.types.value_ref import SQLite3Integer, SQLite3Real, SQLite3Text
from slight.error import Error
from slight.c.raw_bindings import SQLITE_MISUSE


struct Sql(Movable, Stringable):
    """A builder for SQL pragma statements.
    
    This struct provides methods to construct properly formatted and escaped
    SQL pragma statements dynamically.
    """
    
    var buf: String
    """The internal buffer storing the SQL statement."""
    
    fn __init__(out self):
        """Create a new empty SQL builder."""
        self.buf = String()
    
    fn __str__(self) -> String:
        """Get the current SQL statement."""
        return self.buf.copy()
    
    fn as_string_slice(self) -> StringSlice[origin_of(self.buf)]:
        """Get the current SQL statement as a string slice.
        
        Returns:
            A string slice containing the SQL statement.
        """
        return self.buf.as_string_slice()
    
    fn push_pragma(mut self, pragma: StringSlice, schema: Optional[String] = None) raises:
        """Push a PRAGMA statement prefix to the buffer.
        
        Args:
            pragma: The name of the pragma.
            schema: Optional schema name (e.g., "main", "temp").
        
        Raises:
            Error: If the pragma name is invalid.
        """
        self.push_keyword("PRAGMA")
        self.push_space()
        if schema:
            self.push_schema(schema.value())
            self.push_dot()

        self.push_keyword(pragma)
    
    fn push_keyword(mut self, keyword: StringSlice) raises:
        """Push a SQL keyword to the buffer.
        
        Args:
            keyword: The keyword to push (must be a valid identifier).
        
        Raises:
            Error: If the keyword is empty or not a valid identifier.
        """
        if len(keyword) > 0 and is_identifier(keyword):
            self.buf.write_string(keyword)
        else:
            raise Error(
                SQLITE_MISUSE,
                "Invalid keyword \"" + keyword + "\""
            )
    
    fn push_schema(mut self, schema: StringSlice):
        """Push a schema name to the buffer, escaping if necessary.
        
        Args:
            schema: The schema name to push.
        """
        self.push_identifier(schema)
    
    fn push_identifier(mut self, s: StringSlice):
        """Push an identifier to the buffer, escaping if necessary.
        
        Args:
            s: The identifier to push.
        """
        if is_identifier(s):
            self.buf.write_string(s)
        else:
            self.wrap_and_escape(s, '"')
    
    fn push_value[T: ToSQL, //](mut self, value: T) raises:
        """Push a parameter value to the buffer.

        Parameters:
            T: The type of the parameter value.
        
        Args:
            value: The parameter value to push.
        
        Raises:
            Error: If the value type is unsupported.
        """
        var sql = value.to_sql()

        if sql.isa[SQLite3Integer]():
            self.push_int(Int(sql[SQLite3Integer].value))
        elif sql.isa[SQLite3Real]():
            self.push_real(sql[SQLite3Real].value)
        elif sql.isa[SQLite3Text[sql.stmt]]():
            self.push_string_literal(sql[SQLite3Text[sql.stmt]].value)
        else:
            raise Error(
                SQLITE_MISUSE,
                "Unsupported parameter type for pragma value"
            )
    
    fn push_string_literal(mut self, s: StringSlice):
        """Push a string literal to the buffer, properly escaped.
        
        Args:
            s: The string to push as a literal.
        """
        self.wrap_and_escape(s, '\'')
    
    fn push_int(mut self, i: Int):
        """Push an integer value to the buffer.
        
        Args:
            i: The integer to push.
        """
        self.buf.write(i)
    
    fn push_real(mut self, f: Float64):
        """Push a floating-point value to the buffer.
        
        Args:
            f: The float to push.
        """
        self.buf.write(f)
    
    fn push_space(mut self):
        """Push a space character to the buffer."""
        self.buf.write_string(" ")
    
    fn push_dot(mut self):
        """Push a dot character to the buffer."""
        self.buf.write_string(".")
    
    fn push_equal_sign(mut self):
        """Push an equal sign to the buffer."""
        self.buf.write_string("=")
    
    fn open_brace(mut self):
        """Push an opening parenthesis to the buffer."""
        self.buf.write_string("(")
    
    fn close_brace(mut self):
        """Push a closing parenthesis to the buffer."""
        self.buf.write_string(")")
    
    fn wrap_and_escape(mut self, s: StringSlice, quote: StringSlice):
        """Wrap a string in quotes and escape internal quotes by doubling.
        
        Args:
            s: The string to wrap and escape.
            quote: The quote character to use.
        """
        self.buf.write_string(quote)
        for ch in s.codepoint_slices():
            # Escape quote by doubling it
            if ch == quote:
                self.buf.write_string(ch)
            self.buf.write_string(ch)
        self.buf.write_string(quote)


fn is_identifier(s: StringSlice) -> Bool:
    """Check if a string is a valid SQL identifier.
    
    Args:
        s: The string to check.
    
    Returns:
        True if the string is a valid identifier, False otherwise.
    """
    if len(s) == 0:
        return False
    
    var i = 0
    for ch in s.codepoint_slices():
        if i == 0:
            if not is_identifier_start(ch):
                return False
        else:
            if not is_identifier_continue(ch):
                return False
        i += 1
    return True


fn is_identifier_start(c: StringSlice) -> Bool:
    """Check if a character can start an identifier.
    
    Args:
        c: The character to check (as a single-character string).
    
    Returns:
        True if the character can start an identifier.
    """
    if len(c) != 1:
        return False
    
    var byte = ord(c)
    # ASCII uppercase (A-Z)
    if 65 <= byte <= 90:
        return True
    # Underscore
    if byte == 95:
        return True
    # ASCII lowercase (a-z)
    if 97 <= byte <= 122:
        return True
    # Non-ASCII (> 127)
    if byte > 127:
        return True
    return False


fn is_identifier_continue(c: StringSlice) -> Bool:
    """Check if a character can continue an identifier.
    
    Args:
        c: The character to check (as a single-character string).
    
    Returns:
        True if the character can continue an identifier.
    """
    if len(c) != 1:
        return False
    
    var byte = ord(c)
    # Dollar sign
    if byte == 36:
        return True
    # ASCII digits (0-9)
    if 48 <= byte <= 57:
        return True
    # ASCII uppercase (A-Z)
    if 65 <= byte <= 90:
        return True
    # Underscore
    if byte == 95:
        return True
    # ASCII lowercase (a-z)
    if 97 <= byte <= 122:
        return True
    # Non-ASCII (> 127)
    if byte > 127:
        return True
    return False
