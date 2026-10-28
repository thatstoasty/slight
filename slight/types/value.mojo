"""Owning counterpart to `ValueRef`.

`ValueRef` borrows memory owned by SQLite (or by the Mojo value being bound),
so it can only ever describe data that already exists somewhere. `Value` owns
its payload instead, which is what makes it possible to bind a type whose SQL
representation has to be *computed* — a date formatted as ISO text, a UUID, an
enum rendered as a string — where there is no existing buffer to point at.

See `slight.types.to_sql.ToSqlOutput`, which is the enum a `ToSQL`
implementation returns to choose between borrowing and owning.
"""


__enum Value(Copyable, Defaultable, Writable):
    """An owning dynamic SQL value.

    This mirrors `ValueRef`, but every payload is owned rather than borrowed,
    so a `Value` stays valid independently of any statement or source buffer.

    Use `Value()` for NULL at runtime. `Value.null` is a comptime value, and
    since `Value` is not `ImplicitlyCopyable` it cannot be used as a runtime
    value directly; `match` arms such as `case .null:` are unaffected.
    """

    case null
    """An owned SQL NULL value."""
    case integer(Int64)
    """An owned SQL INTEGER value."""
    case real(Float64)
    """An owned SQL REAL value."""
    case text(String)
    """An owned SQL TEXT value."""
    case blob(List[Byte])
    """An owned SQL BLOB value."""

    def __init__(out self):
        """Initialize a NULL value."""
        self = materialize[Self.null]()

    def write_to(self, mut writer: Some[Writer]):
        """Write the string representation of the SQL value to the given writer.

        This method provides a way to serialize the SQL value into a human-readable
        format, suitable for logging or debugging purposes.

        Args:
            writer: The writer to which the string representation will be written.
        """
        match self:
            case .null:
                writer.write("NULL")
            case .integer(value):
                writer.write(value)
            case .real(value):
                writer.write(value)
            case .text(value):
                writer.write(value)
            case .blob(value):
                # TODO: Improve blob representation
                writer.write("BLOB(", len(value), " bytes)")
