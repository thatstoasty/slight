"""Column metadata."""


@fieldwise_init
struct ColumnMetadata(Copyable, Movable):
    """Metadata information about a database column."""

    var data_type: Optional[String]
    """The declared data type of the column, if available."""
    var collation_sequence: Optional[String]
    """The collation sequence name of the column, if available."""
    var not_null: Bool
    """Indicates whether the column has a NOT NULL constraint."""
    var primary_key: Bool
    """Indicates whether the column is part of the primary key."""
    var auto_increment: Bool
    """Indicates whether the column is auto-incrementing."""
