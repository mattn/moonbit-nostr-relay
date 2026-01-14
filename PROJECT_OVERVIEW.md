# Moonbit Nostr Relay - Project Overview

A Nostr relay server implementation in MoonBit language, providing core relay functionality with in-memory event storage and subscription management.

## Project Structure

```
moonbit-nostr-relay/
├── event/                  # Event types and validation
│   └── event.mbt          # Core Nostr event struct and constants
│
├── filter/                # Event filtering logic
│   ├── filter.mbt         # Filter matching (ID, author, kind, timestamp)
│   └── tag_filter.mbt     # Tag-based filtering
│
├── storage/               # Event persistence layer
│   ├── event_store.mbt    # In-memory event storage
│   ├── index.mbt          # Indexing for fast lookup
│   └── persistence.mbt    # Serialization/deserialization (stub)
│
├── server/                # Relay server core
│   ├── message.mbt        # Nostr protocol messages
│   ├── subscription.mbt   # Subscription and filter handling
│   ├── relay.mbt          # Main relay logic
│   ├── request_handler.mbt # Request processing
│   ├── client_manager.mbt # Client lifecycle management
│   └── server.mbt         # Server config and startup
│
├── cmd/main/              # CLI entry point
│   └── main.mbt          # Command-line interface
│
└── [docs]
    ├── README.md         # Project documentation
    └── TESTING.md        # Testing guide
```

## Package Architecture

### Event Package
Defines the core Nostr event structure with:
- Event ID (SHA-256 hash)
- Public key and signature
- Event kind (constants for NIP-1, NIP-4, NIP-42, etc.)
- Tags and content
- Created timestamp

### Filter Package
Implements event filtering according to NIP-1 specification:
- **ID filtering** - Exact match on event IDs
- **Author filtering** - Match by public key
- **Kind filtering** - Match by event kind
- **Timestamp filtering** - Range matching (since/until)
- **Tag filtering** - Filter by event tags (e, p, etc.)

### Storage Package
In-memory event store with:
- **Event storage** - FIFO circular buffer with max capacity
- **Lookup operations** - By ID, author, kind, timestamp range
- **Indexing** - Fast O(1) lookup by author and kind
- **Persistence interface** - Ready for JSON serialization

### Server Package
Relay server logic including:
- **Message types** - EVENT, REQ, CLOSE, EOSE, NOTICE, OK, AUTH
- **Subscription management** - Track client subscriptions with filters
- **Request handling** - Process incoming Nostr protocol messages
- **Client management** - Connection lifecycle and subscription tracking
- **Relay core** - Main relay logic with event routing

## Key Features

✅ **Core Implemented:**
- Event storage with capacity management
- Flexible event filtering (multiple criteria)
- Subscription management
- Client connection tracking
- Request routing architecture
- Protocol message types

⏳ **Pending Implementation:**
- WebSocket server (needs HTTP library integration)
- JSON serialization/deserialization
- Cryptographic signature verification
- Event validation (NIP-1 compliance)
- Multi-client event broadcasting
- Rate limiting and DOS protection
- Persistent database backend
- CLI argument parsing

## Data Flow

```
Client (WebSocket)
  │
  ├─→ EVENT message → Request Handler → Validate → Storage
  │                                         │
  │                                         ↓
  │                                    Match Subscriptions
  │                                         │
  │                                         ↓
  │                                    Broadcast to Clients
  │
  └─→ REQ message → Request Handler → Create Subscription
                         │
                         ↓
                    Find Matching Events
                         │
                         ↓
                    Return EVENT messages
```

## Type System

### Core Types
- `Event` - Event definition with validation
- `Filter` - Subscription filter criteria
- `Subscription` - Client subscription with ID and filters
- `EventStore` - In-memory storage with capacity
- `Relay` - Relay state and subscriptions
- `Client` - Connected client with subscriptions
- `ClientManager` - Manages all connected clients

### Message Types
- `Event(id, json)` - Client sends event
- `Req(sub_id, filters...)` - Client requests events
- `Close(sub_id)` - Client closes subscription
- `EventMsg(sub_id, event_json)` - Server sends stored event
- `Eose(sub_id)` - End of stored events
- `Notice(message)` - Server notification
- `Ok(id, success, message)` - Event processing result
- `Auth(challenge)` - Authentication challenge

## Configuration

Default server configuration:
```
Host: 0.0.0.0
Port: 8080
Max Events: 100,000
Max Connections: 1,000
```

## Module Dependencies

```
event/
  └─ (no dependencies)

filter/
  └─ (no dependencies)

storage/
  └─ (no dependencies)

server/
  ├─ event/
  ├─ filter/
  ├─ storage/
  └─ (standard library only)

cmd/main/
  └─ server/
```

## Build & Test

```bash
# Type check and lint
moon check

# Format code
moon fmt

# Update interfaces
moon info

# Full validation
moon check && moon fmt && moon info
```

## Nostr Protocol Compliance

Implements Nostr basic protocol (NIP-1) with support for:
- Core event types (0-7, 40-44)
- Event filtering
- Subscription lifecycle
- Multiple filter criteria

Future support planned for:
- NIP-4: Encrypted Direct Messages
- NIP-9: Event Deletion
- NIP-11: Relay Information
- NIP-42: Authentication

## Performance Characteristics

- **Event lookup**: O(n) linear scan, optimizable with indexing
- **Filter matching**: O(m) per filter criterion
- **Subscription management**: O(n) for client subscriptions
- **Storage capacity**: Circular buffer, O(1) add with automatic eviction

## Next Steps

1. **WebSocket Integration** - Integrate with HTTP server library
2. **JSON Serialization** - Implement event/message serialization
3. **Signature Verification** - Add cryptographic validation
4. **Testing** - Comprehensive test suite with real Nostr events
5. **CLI** - Full command-line argument parsing
6. **Performance** - Optimize for production workloads
7. **Persistence** - Add database backend option

## Code Statistics

- **Packages**: 5 (event, filter, storage, server, cmd)
- **Modules**: 13 core implementation files
- **Lines of Code**: ~1,500 (excluding tests/docs)
- **Supported Event Kinds**: 8+ (extensible)
- **Filter Criteria**: 5 (ID, Author, Kind, Since, Until, Tags)

## MoonBit Features Used

- Pattern matching and algebraic data types
- Structural typing
- Option types for null safety
- Array processing and loops
- String interpolation
- Module system with namespacing

## License

Apache 2.0

## References

- [Nostr Protocol](https://github.com/nostr-protocol/nostr)
- [NIP-1: Basic Protocol](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [MoonBit Documentation](https://docs.moonbitlang.com)
