from testing import assert_equal, assert_true, assert_false, assert_not_equal, TestSuite, assert_raises

from slight.connection import Connection
from slight.transaction import Transaction, Savepoint, TransactionBehavior, DropBehavior
from slight.row import Row, String, Int, Bool, SIMD

comptime dummy_int: Int = 1

# fn insert(x: Int, conn: Pointer[Connection, _]) raises -> Int:
#     """Insert a value into the foo table."""
#     return conn[].execute("INSERT INTO foo VALUES(?1)", [x])


fn assert_current_sum(x: Int, conn: Connection) raises:
    """Assert that the sum of all values in foo equals x."""
    fn get_int(r: Row) raises -> Int:
        return r.get[Int](0)
    
    var result = conn.query_row[get_int]("SELECT SUM(x) FROM foo")
    assert_equal(result, x)


fn test_drop() raises:
    """Test default rollback and commit behaviors using drop behavior."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    # Test 1: Default behavior is rollback
    var tx = db.transaction()
    tx.conn[].execute_batch("INSERT INTO foo VALUES(1)")
    tx^.finish()
    
    # Test 2: Explicit commit via drop_behavior
    tx = db.transaction()
    tx.conn[].execute_batch("INSERT INTO foo VALUES(2)")
    tx.drop_behavior = DropBehavior.COMMIT
    tx^.finish()
    
    # Test 3: Verify only the committed transaction persisted
    fn get_sum(r: Row) raises -> Int:
        return r.get[Int](0)
    
    tx = db.transaction()
    var sum = tx.conn[].query_row[get_sum]("SELECT SUM(x) FROM foo")
    assert_equal(sum, 2)
    tx^.finish()


fn test_explicit_rollback_commit() raises:
    """Test explicit rollback and commit with savepoints."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        with tx.savepoint() as sp:
            sp.conn[].execute_batch("INSERT INTO foo VALUES(1)")
            sp.rollback()
            sp.conn[].execute_batch("INSERT INTO foo VALUES(2)")
            sp.commit()
        tx.commit()
    
    with db.transaction() as tx:
        tx.conn[].execute_batch("INSERT INTO foo VALUES(4)")
        tx.commit()
    
    fn get_sum(r: Row) raises -> Int:
        return r.get[Int](0)
    
    with db.transaction() as tx:
        var sum = tx.conn[].query_row[get_sum]("SELECT SUM(x) FROM foo")
        assert_equal(sum, 6)


fn test_savepoint() raises:
    """Test nested savepoints with various commit/rollback scenarios."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        tx.conn[].execute_batch("INSERT INTO foo VALUES(1)")
        assert_current_sum(1, tx.conn[])
        tx.drop_behavior = DropBehavior.COMMIT
        
        # First savepoint level
        with tx.savepoint() as sp:
            sp.conn[].execute_batch("INSERT INTO foo VALUES(2)")
            assert_current_sum(3, sp.conn[])
            # sp will roll back by default
        
            # Second savepoint level
            var sp2 = sp.savepoint()
            sp2.conn[].execute_batch("INSERT INTO foo VALUES(4)")
            assert_current_sum(7, sp2.conn[])
            # sp2 will roll back by default
            
            # Third savepoint level
            var sp3 = sp2.savepoint()
            sp3.conn[].execute_batch("INSERT INTO foo VALUES(8)")
            assert_current_sum(15, sp3.conn[])
            sp3.commit()
            # sp3 committed, but will be erased by sp2 rollback
            sp3^.finish()
            
            assert_current_sum(15, sp2.conn[])
            sp2^.finish()  # rollback
            
            assert_current_sum(3, sp.conn[])
            # sp scope ends and rolls back
            
        assert_current_sum(1, tx.conn[])
        # tx scope ends and commits
    
    assert_current_sum(1, db)


fn test_ignore_drop_behavior() raises:
    """Test IGNORE drop behavior which leaves savepoint active."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        with tx.savepoint() as sp:
            _ = sp.conn[].execute("INSERT INTO foo VALUES(?1)", [1])
            sp.rollback()
            _ = sp.conn[].execute("INSERT INTO foo VALUES(?1)", [2])
        
            with sp.savepoint() as sp2:
                sp2.drop_behavior = DropBehavior.IGNORE
                _ = sp2.conn[].execute("INSERT INTO foo VALUES(?1)", [4])
                # IGNORE means the savepoint stays active
        
            assert_current_sum(6, sp.conn[])
            sp.commit()
        assert_current_sum(6, tx.conn[])


fn test_savepoint_drop_behavior_releases() raises:
    """Test that savepoints with COMMIT/ROLLBACK drop behaviors properly release."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    # Test COMMIT drop behavior
    with db.savepoint() as sp:
        sp.drop_behavior = DropBehavior.COMMIT
    assert_true(db.is_autocommit())
    
    # Test ROLLBACK drop behavior
    with db.savepoint() as sp2:
        sp2.drop_behavior = DropBehavior.ROLLBACK
    assert_true(db.is_autocommit())


fn test_savepoint_names() raises:
    """Test savepoints with custom names."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.savepoint("my_sp") as sp:
        _ = sp.conn[].execute("INSERT INTO foo VALUES(?1)", [1])
        assert_current_sum(1, sp.conn[])
    
        # Nested savepoint with same name
        with sp.savepoint("my_sp") as sp2:
            sp2.drop_behavior = DropBehavior.COMMIT
            _ = sp2.conn[].execute("INSERT INTO foo VALUES(?1)", [2])
            assert_current_sum(3, sp2.conn[])
            sp2.rollback()
            assert_current_sum(1, sp2.conn[])
            _ = sp2.conn[].execute("INSERT INTO foo VALUES(?1)", [4])
            # commit
        
        assert_current_sum(5, sp.conn[])
        sp.rollback()
        
        # Another nested savepoint with IGNORE
        with sp.savepoint("my_sp") as sp3:
            sp3.drop_behavior = DropBehavior.IGNORE
            _ = sp3.conn[].execute("INSERT INTO foo VALUES(?1)", [8])
            # ignore
        
        assert_current_sum(8, sp.conn[])
        sp.commit()
    
    assert_current_sum(8, db)


fn test_transaction_behavior() raises:
    """Test different transaction behaviors (DEFERRED, IMMEDIATE, EXCLUSIVE)."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    # Test DEFERRED transaction (default)
    with db.transaction(TransactionBehavior.DEFERRED) as tx:
        tx.conn[].execute_batch("INSERT INTO foo VALUES(1)")
        tx.commit()
    
    # Test IMMEDIATE transaction
    with db.transaction(TransactionBehavior.IMMEDIATE) as tx2:
        tx2.conn[].execute_batch("INSERT INTO foo VALUES(2)")
        tx2.commit()
    
    # Test EXCLUSIVE transaction
    with db.transaction(TransactionBehavior.EXCLUSIVE) as tx3:
        tx3.conn[].execute_batch("INSERT INTO foo VALUES(3)")
        tx3.commit()
    
    fn get_sum(r: Row) raises -> Int:
        return r.get[Int](0)
    
    var sum = db.query_row[get_sum]("SELECT SUM(x) FROM foo")
    assert_equal(sum, 6)


fn test_rollback_after_commit() raises:
    """Test that rolling back after commit raises an error."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        tx.conn[].execute_batch("INSERT INTO foo VALUES(1)")
        tx.commit()
    
        # Attempting to rollback after commit should fail
        with assert_raises(contains="cannot rollback - no transaction is active"):
            tx.rollback()


fn test_commit_after_commit() raises:
    """Test that committing after commit raises an error."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        tx.conn[].execute_batch("INSERT INTO foo VALUES(1)")
        tx.commit()
        
        # Attempting to commit again should fail
        with assert_raises(contains="cannot commit - no transaction is active"):
            tx.commit()
        

fn test_savepoint_rollback_after_commit() raises:
    """Test that rolling back a savepoint after commit raises an error."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        with tx.savepoint() as sp:
            sp.conn[].execute_batch("INSERT INTO foo VALUES(1)")
            sp.commit()
    
            # Attempting to rollback after commit should fail
            with assert_raises(contains="no such savepoint"):
                sp.rollback()


fn test_multiple_inserts_in_transaction() raises:
    """Test multiple inserts within a single transaction."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        @parameter
        for i in range(10):
            _ = tx.conn[].execute("INSERT INTO foo VALUES(?1)", [i])
        tx.commit()
    
    fn get_sum(r: Row) raises -> Int:
        return r.get[Int](0)
    
    var sum = db.query_row[get_sum]("SELECT SUM(x) FROM foo")
    assert_equal(sum, 45)  # 0+1+2+...+9 = 45


fn test_nested_savepoint_rollback() raises:
    """Test nested savepoint rollback behavior."""
    var db = Connection.open_in_memory()
    db.execute_batch("CREATE TABLE foo (x INTEGER)")
    
    with db.transaction() as tx:
        _ = tx.conn[].execute("INSERT INTO foo VALUES(?1)", [1])

        with tx.savepoint() as sp:
            _ = tx.conn[].execute("INSERT INTO foo VALUES(?1)", [2])
    
            with sp.savepoint() as sp2:
                _ = tx.conn[].execute("INSERT INTO foo VALUES(?1)", [4])
                sp2.rollback()  # Rolls back the insert of 4
    
            assert_current_sum(3, sp.conn[])
            sp.commit()
    
        tx.commit()
    
    assert_current_sum(3, db)


fn main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
