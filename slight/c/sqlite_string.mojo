from sys.ffi import c_char
from slight.c.api import sqlite_ffi
from slight.c.types import MutExternalPointer


@fieldwise_init
struct SQLiteMallocString(Copyable, Movable):
    """A string we are in charge of freeing that's allocated on the SQLite heap.
    
    Automatically calls `sqlite3_free` when deleted."""

    var ptr: MutExternalPointer[c_char]
    """A pointer to the C string allocated by SQLite."""

    fn __del__(deinit self):
        if self.ptr:
            sqlite_ffi()[].free(self.ptr.bitcast[NoneType]())
    
    fn unsafe_ptr[
        origin: Origin, address_space: AddressSpace, //
    ](ref [origin, address_space]self) -> UnsafePointer[c_char, origin, address_space=address_space]:
        """Retrieves a pointer to the underlying memory.

        Parameters:
            origin: The origin of the `SQLiteMallocString`.
            address_space: The `AddressSpace` of the `SQLiteMallocString`.

        Returns:
            The pointer to the underlying memory.
        """
        return self.ptr.unsafe_mut_cast[origin.mut]().unsafe_origin_cast[origin]().address_space_cast[address_space]()

    fn as_string_slice(mut self) -> StringSlice[origin_of(self)]:
        """Returns the C string to a `StringSlice`.

        Returns:
            A `StringSlice` representing the C string.
        """
        return StringSlice(unsafe_from_utf8_ptr=self.unsafe_ptr())
