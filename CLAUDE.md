# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`slight` is a Mojo wrapper around the SQLite3 C library (package name `slight`, repo `mojo-sqlite3`). It dynamically loads `libsqlite3` at runtime via FFI rather than statically linking — see "FFI / dynamic loading" below.

## Commands

This project uses `pixi` (not plain shell scripts) for all tasks, defined in [pixi.toml](pixi.toml).

```bash
pixi run tests        # runs every test/test_*.mojo file
pixi run examples      # runs every examples/*.mojo file
pixi run benchmarks    # runs every benchmarks/*.mojo file
pixi run format        # mojo format slight --line-length 120
pixi run lint_docs     # mojo doc --Werror --diagnose-missing-doc-strings -o /dev/null ./slight
pixi run build         # pixi build -o .
```

To run a single test file directly (not through the `tests` task):

```bash
mojo -D ASSERT=all -I . test/test_connection.mojo
```

All `tests`/`examples`/`benchmarks` tasks simply `find <dir> -name "test_*.mojo" -exec mojo ... {} \;`, so an individual file can always be invoked the same way the task does, just pointed at one file.

Pre-commit hooks (`.pre-commit-config.yaml`) run `pixi run format` and `pixi run lint_docs` — run these before committing since CI does not auto-fix formatting.

CI (`.github/workflows/test.yml`) runs `pixi run tests` on linux-64, osx-arm64, and linux-aarch64 whenever `slight/**` or `pixi.toml` changes.

## Architecture

### Layering

```
slight/c/raw_bindings.mojo   raw extern "C" FFI declarations matching sqlite3.h, loaded via DLHandle
slight/c/types.mojo          opaque pointer/callback typedefs (sqlite3_stmt, sqlite3_context, callback fn types, ...)
slight/bindings.mojo         `sqlite3` struct: thin per-function wrappers around raw_bindings, adds error/null handling
slight/api.mojo              `sqlite_ffi()` — lazily-initialized process-global handle to the `sqlite3` bindings struct
        ↓
slight/raw_statement.mojo    `RawStatement` — owns a `sqlite3_stmt*`, thin wrapper calling sqlite_ffi()
slight/inner_connection.mojo `InnerConnection` — owns a `sqlite3*`, all the actual FFI call sites for the connection
        ↓
slight/connection.mojo       `Connection` — public-facing API wrapping `InnerConnection`
slight/statement.mojo        `Statement` — public-facing API wrapping `RawStatement`, exposes `.query()`/`.query[T]()`
slight/row.mojo              `Row`, `Rows`, `MappedRows`, `TypedRows` — result iteration and column access
```

`Connection` and `Statement` are the user-facing types; `InnerConnection` and `RawStatement` hold the raw pointers and are not meant to be used directly by library consumers. When adding a new SQLite C API, the call site goes in `inner_connection.mojo` (connection-level) or `raw_statement.mojo` (statement-level), and the public method goes on `Connection`/`Statement` respectively.

### Type conversion traits

- `slight/types/to_sql.mojo` — `ToSQL` trait, Mojo → SQLite type mapping for binding parameters.
- `slight/types/from_sql.mojo` — `FromSQL` trait, SQLite → Mojo type mapping for reading columns.
- `slight/types/value_ref.mojo` — borrowed reference to a SQLite value (used in scalar/aggregate function args).
- `slight/params.mojo` — `Params` trait; `Tuple` supports heterogeneous positional params, `List`/`Dict` require homogeneous types (no trait objects yet — see README TODO section for the long-term plan here).

Both `ToSQL`/`FromSQL` and `Params`/`RowIndex` conformance are currently checked with comptime asserts inside functions that accept `AnyType`, rather than enforced in the signature itself — a known limitation tracked in the README TODO list, not a bug to "fix" casually.

### UDFs (`slight/functions.mojo`, `slight/context.mojo`)

Scalar/aggregate/window SQL functions are registered via `Connection.create_scalar_function[...]`, `create_aggregate_function[...]`, `create_window_function[...]`, all parameterized on Mojo function pointers (not closures with captured state for the per-row callback — accumulator state for aggregates is threaded through `Context` instead). `Context` (`context.mojo`) is the handle passed to UDF callbacks for argument access and result reporting.

### Virtual tables (`slight/vtab/`)

`vtab.mojo` provides the generic `VTab`/`VTabCursor` machinery (`VTabConnectFn`, `VTabBestIndexFn`, `VTabOpenFn`, `VTabFilterFn`, etc.) for implementing SQLite virtual tables in Mojo. `csvtab.mojo` is a concrete example (a CSV-backed virtual table) and is exercised by `test/test_csvtab*.mojo` and `benchmarks/bench_csvtab.mojo`.

### Resource ownership

Several types use `@explicit_destroy` (e.g. `RawStatement`, `ExtensionLoadGuard`) to make the compiler enforce that a cleanup method is called explicitly (`.finalize()`, `.disable_extension_loading()`) rather than relying on implicit destructors — this is intentional for FFI resources where forgetting cleanup is a real footgun. Don't "simplify" these into regular destructors without understanding why explicit destroy was chosen.

### FFI / dynamic loading

`slight` does **not** statically link sqlite3. `sqlite_ffi()` (`slight/api.mojo`) lazily loads `libsqlite3.{dylib,so}` once per process via `_get_global`, resolving the library path in this order: `-D SQLITE_LIB_PATH=...` compile-time flag → `SQLITE_LIB_PATH` env var → default `.pixi/envs/default/lib/libsqlite3.{dylib,so}`. Every other module gets at the C API by calling `sqlite_ffi()`, never by linking directly.

### `rusqlite/` directory

This is a vendored copy of the upstream Rust `rusqlite` crate, kept as a design reference (the README states this project is heavily inspired by `rusqlite`). It is not part of the Mojo package and is not built or tested by any pixi task — don't treat changes there as part of this project's source.

## Untracked TODOs worth knowing about

The README's TODO section documents several intentional, currently-accepted API limitations (loose `AnyType` + comptime-assert trait checking for `Params`/`Row.get`/`ToSQL`/`FromSQL`, no `collect()` on row iterators pending conditional conformance, some possibly-incorrect origins on `ValueRef`). These are deliberate trade-offs given current Mojo trait/extension system limitations, not oversights — read that section before "fixing" any of them.
