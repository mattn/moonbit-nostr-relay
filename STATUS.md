# Project Status

## Current State

The relay is **functional end-to-end**: clients can connect over WebSocket,
publish signed events (signatures are actually verified), and subscribe with
filters including live broadcast.

```bash
# native + PostgreSQL
DATABASE_URL=postgres://... ./_build/native/debug/build/cmd/native/native.exe
# or JS backend (in-memory)
moon run --target js cmd/main
```

Verified against real clients: `nak event` / `nak req` round-trips, NIP-11
over HTTP, forged-signature and tampered-id rejection, UTF-8 content
(Japanese, quotes, newlines) id computation matching other implementations.

## What's Working

- ✅ NIP-01 messages: EVENT, REQ (multi-filter), CLOSE / OK, EOSE, NOTICE, CLOSED
- ✅ Filters: ids, authors, kinds, since, until, limit, #tags; newest-first ordering
- ✅ Live subscription broadcast to all matching clients
- ✅ SHA-256 (FIPS 180-4) in pure MoonBit — NIST test vectors
- ✅ BIP-340 Schnorr verify + sign over secp256k1 (BigInt, Jacobian coords) — official test vectors
- ✅ Event id check via NIP-01 canonical serialization (exact escaping rules)
- ✅ Replaceable / addressable / ephemeral kind semantics, duplicate detection
- ✅ NIP-09 event deletion: kind-5 events delete the events referenced by
  their "e" tags (same author only) and are themselves stored and served
- ✅ NIP-26 delegated event signing: delegation tag shape, kind / created_at
  conditions, delegator Schnorr signature over the delegation token
- ✅ NIP-70 protected events: events tagged ["-"] are rejected with
  "auth-required" (no NIP-42 AUTH, so their author can never be proven)
- ✅ NIP-11 relay information document
- ✅ Native transport: moonbitlang/async HTTP server + WebSocket
- ✅ PostgreSQL storage backend (mattn/postgres / libpq) behind a Storage trait;
  events survive restarts, verified end-to-end with nak against PostgreSQL 16
- ✅ JS transport: WebSocket server (RFC 6455) via inline JS FFI on node:http
- ✅ 26 tests green (`moon test`)

## What's Pending

- ⏳ NIP-42 AUTH
- ⏳ Rate limiting / max subscriptions per client
- ⏳ Native-backend transport (currently JS backend only)
- ⏳ CLI flags for host/port/limits (currently defaults in `server/config.mbt`)
