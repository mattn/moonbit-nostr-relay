# Moonbit Nostr Relay

<p align="center"><img src="public/logo.png" width="300" alt="logo"></p>

A working Nostr relay server written in [MoonBit](https://www.moonbitlang.com/), with full NIP-01 message handling and real cryptographic verification (SHA-256 event ids + BIP-340 Schnorr signatures) implemented in pure MoonBit.

A public instance is running at **wss://relay.example.com** (the same URL serves the landing page and the NIP-11 document over HTTPS).

## Quick Start

### Docker (recommended)

Prebuilt images are published to GitHub Container Registry:

```bash
docker run -p 8080:8080 \
  -e DATABASE_URL=postgres://user:pass@host:5432/nostr \
  ghcr.io/mattn/moonbit-nostr-relay:latest
```

Or bring up relay + PostgreSQL together:

```bash
docker compose up --build
# relay on ws://localhost:8080, PostgreSQL data in the pgdata volume
```

### Build from source (native)

The native backend uses moonbitlang/async for the WebSocket transport and
mattn/postgres (libpq) for storage. Requires libpq (`libpq-dev`) and node
(used by a prebuild script).

```bash
moon build --target native
DATABASE_URL=postgres://user:pass@localhost:5432/nostr \
  ./_build/native/debug/build/cmd/native/native.exe
# listening on ws://0.0.0.0:8080
```

Without `DATABASE_URL` it falls back to the in-memory store. The schema
(an `event` table with indexes) is created automatically on startup.

### JS backend (in-memory, no dependencies)

The JS transport runs on Node.js 22+ with no npm dependencies:

```bash
moon run --target js cmd/main
```

### Try it

With [nak](https://github.com/fiatjaf/nak):

```bash
nak event -c 'hello' ws://127.0.0.1:8080     # publish (signature is verified)
nak req -k 1 ws://127.0.0.1:8080             # query stored events
curl -H 'Accept: application/nostr+json' http://127.0.0.1:8080   # NIP-11 info
```

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | (unset) | PostgreSQL connection string; in-memory storage when unset |
| `HOST` | `0.0.0.0` | Listen address |
| `PORT` | `8080` | Listen port |
| `WEB_ROOT` | `public` | Static site directory served on the HTTP endpoint (`/` → `index.html`) |
| `RELAY_NAME` | `moonbit-nostr-relay` | NIP-11 `name` |
| `RELAY_DESCRIPTION` | (built-in) | NIP-11 `description` |
| `RELAY_PUBKEY` | (unset) | NIP-11 `pubkey` |
| `RELAY_CONTACT` | (unset) | NIP-11 `contact` |
| `RELAY_ICON` | (unset) | NIP-11 `icon` |

## Features

- **NIP-01**: EVENT / REQ / CLOSE handling, OK / EOSE / NOTICE / CLOSED responses,
  filters (ids, authors, kinds, since, until, limit, `#tag`), live subscription broadcast
- **Event verification**: NIP-01 canonical serialization → SHA-256 id check, and
  BIP-340 Schnorr signature verification over secp256k1 — all in pure MoonBit (BigInt),
  validated against official test vectors
- **Storage backends**: PostgreSQL (durable, via mattn/postgres) or in-memory,
  selected at startup; duplicate detection, replaceable (kind 0/3/1xxxx),
  addressable (3xxxx, d-tag) and ephemeral (2xxxx) kinds. The PostgreSQL
  schema and query semantics are compatible with
  [fiatjaf/eventstore](https://github.com/fiatjaf/eventstore)'s postgresql
  driver, so an existing khatru/eventstore database can be reused as-is
- **NIP-11**: relay information document, configurable via `RELAY_*` variables
- **Static site**: files under `WEB_ROOT` are served on the same HTTP endpoint,
  so one URL is both the relay and its landing page
- **Transports**: native (moonbitlang/async HTTP + WebSocket) and JS
  (dependency-free RFC 6455 server over `node:http` FFI)

## Architecture

```
event/      Event struct, JSON conversion, NIP-01 id serialization, kind classes
filter/     Filter parsing and matching (incl. tag filters)
storage/    Storage trait + in-memory store with NIP-01 replacement semantics
pgstore/    PostgreSQL backend implementing the Storage trait (native only)
crypto/     SHA-256, BIP-340 Schnorr sign/verify, secp256k1 (pure MoonBit)
server/     Transport-agnostic relay engine (parse → validate → store → route)
cmd/native  Native entry point (WebSocket + PostgreSQL + static files)
cmd/main    JS entry point (Node FFI WebSocket, in-memory only)
```

The relay engine is transport-agnostic: `Relay::handle_message(client_id, text)`
returns the list of `(client_id, message)` pairs to deliver, so a transport
only needs to move strings between sockets and the engine.

## Develop

```bash
moon check       # Type check
moon test        # Run test suite (relay flows, SHA-256/BIP-340 test vectors)
moon info && moon fmt
```

Pushing to `main` builds and publishes `ghcr.io/mattn/moonbit-nostr-relay:latest`;
a `v*` tag publishes the corresponding semver tag.

## Not yet implemented

- NIP-09 deletion, NIP-42 auth, rate limiting / PoW
- PostgreSQL on the JS backend (pgstore is native-only)

## License

Apache-2.0
