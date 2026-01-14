# Moonbit Nostr Relay

A Nostr relay server implementation in MoonBit, providing efficient event storage and subscription management.

## Quick Start

### Build

```bash
moon check       # Type check
moon fmt         # Format code
moon info        # Update interfaces
```

### Run

```bash
moon run cmd/main
```

### Test

```bash
moon test
```

See [TESTING.md](TESTING.md) for test examples.

## Architecture

The relay is organized into 5 core packages:

1. **event** - Nostr event types and constants
2. **filter** - Event filtering logic (ID, author, kind, timestamp)
3. **storage** - In-memory event store with indexing
4. **server** - Relay core with subscription management
5. **cmd** - CLI entry point

See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for detailed architecture.

## Features

- ✅ In-memory event storage with capacity management
- ✅ Flexible event filtering (multiple criteria)
- ✅ Subscription management for clients
- ✅ Nostr protocol message types
- ⏳ WebSocket server (pending)
- ⏳ JSON serialization
- ⏳ Signature verification

## Event Storage

Events are stored in a circular buffer that automatically evicts oldest events when max capacity is reached:

```
// Create store with 100,000 max events
let store = new_store(100000)

// Add event
let event = { id, pubkey, created_at, kind, tags, content, sig }
let store = add_event(store, event)

// Find events
let by_author = find_by_author(store, pubkey)
let by_kind = find_by_kind(store, kind)
let in_range = find_by_timestamp(store, since, until)
```

## Filtering

Filter events by multiple criteria:

```
let filter = {
  ids: ["event_id"],
  authors: ["author_pubkey"],
  kinds: [1, 2, 7],
  since: Some(1000UL),
  until: Some(2000UL),
  limit: Some(100),
}

let matches = match_event(filter, id, author, kind, created_at)
```

## Relay Logic

Create and manage subscriptions:

```
// Create relay
let relay = new_relay(config)

// Client sends REQ with filters
let relay = create_subscription(relay, "sub_id", [filter])

// Find matching events
let events = find_matching_events(relay, filter, limit)

// Client sends CLOSE
let relay = remove_subscription(relay, "sub_id")
```

## Protocol

Implements Nostr NIP-1 with message types:

- `EVENT` - Client sends event to relay
- `REQ` - Client requests events with filters
- `CLOSE` - Client closes subscription
- `EVENT` (server) - Relay sends stored event
- `EOSE` - End of stored events
- `OK` - Event acceptance result
- `NOTICE` - Server message

## Configuration

Default server configuration:

```
Host: 0.0.0.0
Port: 8080
Max Events: 100,000
Max Connections: 1,000
```

Customize:

```
let config = {
  host: "127.0.0.1",
  port: 8080,
  max_connections: 500,
  max_events: 50000,
}
let server = new_server(config)
```

## Project Layout

```
event/           - Event types (0 deps)
filter/          - Filtering logic (0 deps)
storage/         - Event storage (0 deps)
server/          - Relay core (3 deps)
cmd/main/        - CLI entry point
```

All packages are self-contained with minimal dependencies for modularity.

## Development

Code style follows MoonBit conventions with blocks separated by `///|`:

```moonbit
///| Block 1 - Implementation

pub fn function1() -> Type { ... }

///| Block 2 - Related implementation

pub fn function2() -> Type { ... }
```

Run `moon fmt` to format, `moon check` to validate.

## Status

**Core Implementation**: ✅ Complete
- Event storage and retrieval
- Multi-criteria filtering
- Subscription management
- Protocol message types

**Integration**: ⏳ Pending
- WebSocket server
- JSON serialization
- Signature verification
- Production hardening

## Next Steps

1. WebSocket server integration
2. JSON message serialization
3. Signature verification
4. Comprehensive testing
5. Performance optimization
6. Database persistence

See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for detailed roadmap.

## References

- [Nostr Protocol](https://github.com/nostr-protocol/nostr)
- [MoonBit Docs](https://docs.moonbitlang.com)

## License

Apache 2.0
