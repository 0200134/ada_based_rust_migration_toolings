# Ada Rust Edition Migration Tool

This project provides an Ada command-line tool for inspecting and updating the Rust edition in a crate's `Cargo.toml`.

## Requirements

- macOS or Linux
- Ada Alire (`alr`)
- Rust and Cargo for validating the migrated crate

## Build

From the repository root:

```sh
make build
```

The same `make` commands also work after changing into the `migrations/` directory.

The executable is created at `migrations/bin/migrations`.

Show the commands:

```sh
make help
```

## Use

Create a Rust 2021 test crate:

```sh
mkdir -p /tmp/rust-edition-demo
cargo init --bin --edition 2021 /tmp/rust-edition-demo
```

Inspect its current edition:

```sh
make inspect CRATE=/tmp/rust-edition-demo
```

Preview an upgrade without changing files:

```sh
make dry-run CRATE=/tmp/rust-edition-demo EDITION=2024
```

Apply the upgrade:

```sh
make migrate CRATE=/tmp/rust-edition-demo EDITION=2024
```

Validate the Rust crate:

```sh
cargo check --manifest-path /tmp/rust-edition-demo/Cargo.toml
```

You can also pass a direct `Cargo.toml` path to the Ada executable:

```sh
./migrations/bin/migrations inspect /tmp/rust-edition-demo/Cargo.toml
```

## Check Mode

Use `make check` in CI or scripts. It returns exit code `1` when a migration is needed and `0` when the requested edition is already configured:

```sh
make check CRATE=/tmp/rust-edition-demo EDITION=2024
```

The tool updates only `Cargo.toml`. Use `cargo check` or `cargo fix --edition` to handle Rust source-code changes after changing the manifest edition.