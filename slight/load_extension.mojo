@fieldwise_init
@explicit_destroy("You must call `disable_extension_loading` to explicitly destroy this guard.")
struct ExtensionLoadGuard[conn: MutOrigin]:
    """Temporarily enables extension loading on a connection, and provides a guard to disable it."""
    
    var connection: Pointer[Connection, Self.conn]
    """Pointer to a SQLite connection."""

    fn disable_extension_loading(deinit self) raises:
        """Disables extension loading on the associated connection.
        
        This MUST be called at some point to disable extension loading.

        Raises:
            Error: If disabling extension loading fails.
        """
        self.connection[].disable_extension_loading()
