"""Owning counterpart to `ValueRef`.

`ValueRef` borrows memory owned by SQLite (or by the Mojo value being bound),
so it can only ever describe data that already exists somewhere. `Value` owns
its payload instead, which is what makes it possible to bind a type whose SQL
representation has to be *computed* — a date formatted as ISO text, a UUID, an
enum rendered as a string — where there is no existing buffer to point at.

See `slight.types.to_sql.ToSqlOutput`, which is the enum a `ToSQL`
implementation returns to choose between borrowing and owning.
"""
from std.utils import Variant


trait SQLType(Copyable, Writable):
    """A marker trait for types that represent SQL Value types."""

    pass


@fieldwise_init
struct Null(SQLType):
    """An owned SQL NULL value."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable representation of this value.

        Args:
            writer: The writer to write to.
        """
        writer.write("NULL")


@fieldwise_init
struct Integer(SQLType):
    """An owned SQL INTEGER value."""

    var value: Int64
    """The underlying integer value."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable representation of this value.

        Args:
            writer: The writer to write to.
        """
        writer.write(self.value)


@fieldwise_init
struct Real(SQLType):
    """An owned SQL REAL value."""

    var value: Float64
    """The underlying floating-point value."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable representation of this value.

        Args:
            writer: The writer to write to.
        """
        writer.write(self.value)


@fieldwise_init
struct Text(SQLType):
    """An owned SQL TEXT value."""

    var value: String
    """The underlying text, owned by this struct."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable representation of this value.

        Args:
            writer: The writer to write to.
        """
        writer.write(self.value)


@fieldwise_init
struct Blob(SQLType):
    """An owned SQL BLOB value."""

    var value: List[Byte]
    """The underlying bytes, owned by this struct."""

    def write_to(self, mut writer: Some[Writer]):
        """Writes a human-readable representation of this value.

        Args:
            writer: The writer to write to.
        """
        # TODO: Improve blob representation
        writer.write("BLOB(")
        writer.write(len(self.value))
        writer.write(" bytes)")


struct Value(Copyable, Writable):
    """An owning dynamic SQL value.

    This mirrors `ValueRef`, but every payload is owned rather than borrowed,
    so a `Value` stays valid independently of any statement or source buffer.
    """

    comptime _type = Variant[Null, Integer, Real, Text, Blob]
    var value: Self._type
    """The actual value stored in the variant."""

    @implicit
    def __init__(out self, var value: Null):
        """Initialize a Value with a NULL value.

        Args:
            value: The Null to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Integer):
        """Initialize a Value with an INTEGER value.

        Args:
            value: The Integer to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Real):
        """Initialize a Value with a REAL value.

        Args:
            value: The Real to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Text):
        """Initialize a Value with a TEXT value.

        Args:
            value: The Text to store.
        """
        self.value = value^

    @implicit
    def __init__(out self, var value: Blob):
        """Initialize a Value with a BLOB value.

        Args:
            value: The Blob to store.
        """
        self.value = value^

    def isa[T: SQLType](self) -> Bool:
        """Check whether this Value currently holds a `T`.

        Parameters:
            T: The variant arm to test for.

        Returns:
            True if the stored value is a `T`.
        """
        return self.value.isa[T]()

    def __getitem_param__[T: SQLType](self) -> ref[origin_of(self.value)._get_owned_interior["value"]] T:
        """Access the stored value as a `T`.

        Parameters:
            T: The variant arm to read.

        Returns:
            A reference to the stored value.
        """
        return self.value[T]

    def write_to(self, mut writer: Some[Writer]):
        """Write the string representation of the SQL value to the given writer.

        This method provides a way to serialize the SQL value into a human-readable
        format, suitable for logging or debugging purposes.

        Args:
            writer: The writer to which the string representation will be written.
        """
        comptime for i in range(len(self._type.Ts)):
            comptime T = self._type.Ts[i]
            if self.value.isa[T]():
                comptime assert conforms_to(T, Writable)
                writer.write(self.value[T])
                return
