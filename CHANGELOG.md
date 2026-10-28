# Changelog

All notable changes to `slight` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While the version is below 1.0.0, minor releases may contain breaking changes;
these are marked **Breaking** below.

## [0.4.0] - Unreleased

Requires Mojo 1.2.0.

### Changed

- **Breaking:** Requires exactly Mojo 1.2.0 (`mojo = "=1.2.0"`), up from `>=1.1.0,<1.2.0`.
- **Breaking:** `ValueRef` is now an `__enum` with the cases `null`, `integer(Int64)`, `real(Float64)`,
  `text(StringSpan)` and `blob(Span[Byte])`. The `Null`, `Integer`, `Real`, `Text` and `Blob` wrapper
  structs, the `SQLRefType` trait, `isa[T]()` and `value[T]` access are removed, and `slight.types` no
  longer exports the wrapper structs. Inspect a value with `match`, `is_null()` or the existing
  `as_int64()`, `as_float64()` and `unsafe_as_*()` accessors, and build one with e.g.
  `ValueRef[origin].integer(42)`.
- **Breaking:** `Value` is now an `__enum` with the same five cases, owning a `String` / `List[Byte]`
  payload. Its wrapper structs and the `SQLType` trait are removed. Use `Value.text(...)`, `Value.integer(...)`
  etc., and `Value()` for NULL (`Value.null` is a compile-time value and can't be used at runtime because
  `Value` is not implicitly copyable).
- **Breaking:** `DataType`, `TextEncoding`, `CheckpointMode`, `DestructorHint`, `UpdateOperation`, `Limit` and
  `TransactionBehavior` are now `__enum`s with lowercase case names, e.g. `DataType.integer`,
  `Limit.sql_length`, `CheckpointMode.full`, `TransactionBehavior.immediate`, `UpdateOperation.insert`.
  - The raw SQLite code moved from the `.value` field to a `code()` method.
  - `DataType(code)` and `UpdateOperation(code)` convert a raw code and abort on a value SQLite never
    produces. `Limit` can no longer be built from an arbitrary integer.
  - `DestructorHint.static_destructor()` / `transient_destructor()` are now
    `DestructorHint.static.destructor()` / `DestructorHint.transient.destructor()`.
  - These types are no longer `TrivialRegisterPassable` (enums can't be); they are `ImplicitlyCopyable`.
- **Breaking:** Reworked row iteration so errors raised while stepping are no longer lost:
  - `Rows` is no longer an `Iterator` itself. Use the raising `next()`, which returns `Optional[Row]`, or a
    `for` loop. Because a `for` loop can't raise, a stepping error ends the loop and is stored; call
    `raise_if_error()` on a named `Rows` afterwards. `MappedRows` and `TypedRows` work the same way.
  - `map()` and `as_type()` now consume the `Rows`, and `collect()` now raises.
  - Destroying a `Rows` resets its statement, so stopping early (`break`, `one_row()`, `exists()`) no longer
    leaves the statement mid-query holding a read lock. `query()` and `execute()` also reset before binding,
    so a statement can always be reused.
  - `Row` is now `ImplicitlyCopyable`.
- Error messages are more informative:
  - SQLite errors include the extended code name, e.g.
    `sqlite3 Error (19, SQLITE_CONSTRAINT_UNIQUE): UNIQUE constraint failed: t.x`. Errors from stepping a
    statement now carry the code too.
  - Conversion errors name the column and both types, e.g.
    `Column 1 ("name"): InvalidColumnTypeError: value is TEXT, expected INTEGER`.
  - Parameter-count errors read `Invalid parameter count: got 3, expected 2`.
  - `InvalidColumnIndexError` reports the result's column count.
- Optional SQLite C functions (deprecated, compile-option-dependent or newer ones) are resolved when first
  used instead of at load, so a `libsqlite3` without them still loads. Calling a missing one raises an
  error instead of aborting.

### Added

- `Connection.error_code()` and `Connection.extended_error_code()` for the most recent failure.
- Constants for every SQLite extended result code on `SQLite3Result` (e.g. `CONSTRAINT_UNIQUE`,
  `IOERR_READ`, `BUSY_TIMEOUT`), plus `SQLite3Result.name()` and `SQLite3Result.primary()`.
- `sqlite_ffi()[].has_function(name)` and `require_function(name)` to check for optional C functions.
- `Rows.next()`, `Rows.raise_if_error()` and `Rows.reset()`, with matching methods on `MappedRows` and
  `TypedRows`.
- `ValueRef.type_name()`, `ValueRef.is_null()` and `ValueRef.unsafe_origin_cast()`.
- `DataType.code()`, `TextEncoding.code()`, `CheckpointMode.code()`, `UpdateOperation.code()` and
  `Limit.code()`.
- `Statement` has a readable representation, e.g. `Statement(SELECT 1)`.

### Fixed

- Aggregate and window functions: `init_fn` was never called, because SQLite hands back zeroed memory
  rather than NULL on the first `xStep`. The accumulator is now created by `init_fn`, stored on the Mojo heap
  and destroyed in `xFinal`, so non-trivial accumulators (`String`, `List`, ...) work per group and no
  longer leak. An aggregate over zero rows, or a window `xValue` before any step, now uses `init_fn` instead
  of failing with an out-of-memory error.
- Executing or querying a statement without the parameters it needs now raises instead of silently binding
  NULL.
- Reading an integer into a narrower type (e.g. `300` as `UInt8`) raises `IntegralValueOutOfRange` instead of
  wrapping, and binding an unsigned value above `Int64.MAX` is rejected.
- `as_float64()` and `Float64`/`Float32` columns accept INTEGER values, as SQLite returns for e.g. `sum()`
  over an INTEGER column.
- A zero-length BLOB column or argument is read as an empty BLOB instead of NULL or an error.
- `prepare()` no longer leaks the prepared statements when it rejects SQL containing multiple statements or a
  syntax error after the first one.
- `SQLite3Result` described `SQLITE_NOTADB` as `SQLITE_NOTFOUND`.

## [0.3.1] - 2026-09-17

### Changed

- **Breaking:** Requires Mojo `>=1.1.0,<1.2.0`, and updated for the Mojo 1.1.0 standard library
  (`CStringSlice` is now `CStringSpan`).

[0.4.0]: https://github.com/thatstoasty/slight/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/thatstoasty/slight/compare/v0.3.0...v0.3.1
