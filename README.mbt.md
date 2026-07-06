# Moonbit Nostr Relay

A working Nostr relay server written in [MoonBit](https://www.moonbitlang.com/), with full NIP-01 message handling and real cryptographic verification (SHA-256 event ids + BIP-340 Schnorr signatures) implemented in pure MoonBit.

## Quick Start

### Run the relay (native + PostgreSQL)

The native backend uses moonbitlang/async for the WebSocket transport and
mattn/postgres (libpq) for storage. Requires libpq (`libpq-dev`).

```bash
moon build --target native
DATABASE_URL=postgres://user:pass@localhost:5432/nostr \
  ./_build/native/debug/build/cmd/native/native.exe
# listening on ws://0.0.0.0:8080  (PORT / HOST to override)
```

Without `DATABASE_URL` it falls back to the in-memory store. The schema
(an `events` table with indexes) is created automatically on startup.

### Run with Docker

```bash
docker compose up --build
# relay on ws://localhost:8080, PostgreSQL data in the pgdata volume
```

Or standalone (in-memory unless DATABASE_URL is set):

```bash
docker build -t moonbit-nostr-relay .
docker run -p 8080:8080 -e DATABASE_URL=postgres://... moonbit-nostr-relay
```

### Run the relay (JS backend, in-memory)

The JS transport runs on Node.js 22+ with no npm dependencies:

```bash
moon run --target js cmd/main
# listening on ws://0.0.0.0:8080
```

Try it with [nak](https://github.com/fiatjaf/nak):

```bash
nak event -c 'hello' ws://127.0.0.1:8080     # publish (signature is verified)
nak req -k 1 ws://127.0.0.1:8080             # query stored events
curl -H 'Accept: application/nostr+json' http://127.0.0.1:8080   # NIP-11 info
```

### Develop

```bash
moon check       # Type check
moon test        # Run test suite (relay flows, SHA-256/BIP-340 test vectors)
moon info && moon fmt
```

## Features

- **NIP-01**: EVENT / REQ / CLOSE handling, OK / EOSE / NOTICE / CLOSED responses,
  filters (ids, authors, kinds, since, until, limit, `#tag`), live subscription broadcast
- **Event verification**: NIP-01 canonical serialization → SHA-256 id check, and
  BIP-340 Schnorr signature verification over secp256k1 — all in pure MoonBit (BigInt),
  validated against official test vectors
- **Storage backends**: PostgreSQL (durable, via mattn/postgres) or in-memory,
  selected at startup; duplicate detection, replaceable (kind 0/3/1xxxx),
  addressable (3xxxx, d-tag) and ephemeral (2xxxx) kinds
- **NIP-11**: relay information document
- **Transport**: minimal RFC 6455 WebSocket server as inline JS FFI over `node:http`
  (no external dependencies)

## Architecture

```
event/      Event struct, JSON conversion, NIP-01 id serialization, kind classes
filter/     Filter parsing and matching (incl. tag filters)
storage/    Storage trait + in-memory store with NIP-01 replacement semantics
pgstore/    PostgreSQL backend implementing the Storage trait (native only)
crypto/     SHA-256, BIP-340 Schnorr sign/verify, secp256k1 (pure MoonBit)
server/     Transport-agnostic relay engine (parse → validate → store → route)
cmd/native  Native entry point (moonbitlang/async WebSocket + PostgreSQL)
cmd/main    JS entry point (Node FFI WebSocket, in-memory only)
```

The relay engine is transport-agnostic: `Relay::handle_message(client_id, text)`
returns the list of `(client_id, message)` pairs to deliver, so alternative
transports (e.g. a native backend socket layer) only need to move strings.

## Not yet implemented

- NIP-09 deletion, NIP-42 auth, rate limiting / PoW
- PostgreSQL on the JS backend (pgstore is native-only)

## License

Apache-2.0
