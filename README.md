# slight

`slight` is a Mojo wrapper around the SQLite3 C library, providing a safe and ergonomic interface for interacting with SQLite databases in Mojo applications.

![Mojo Version](https://img.shields.io/badge/Mojo%F0%9F%94%A5-26.1-orange)
![Build Status](https://github.com/thatstoasty/mojo-sqlite3/actions/workflows/build.yml/badge.svg)
![Test Status](https://github.com/thatstoasty/mojo-sqlite3/actions/workflows/test.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

More documentation will come, but for now please use the test files as reference for usage examples.

## Attributions

This project was heavily inspired by:

- The [rusqlite](https://github.com/rusqlite/rusqlite) Rust crate.

## TODO

1. Support features for different compilation options.
2. Coalesce different parameter specification types into a Trait, to reduce code duplication.
