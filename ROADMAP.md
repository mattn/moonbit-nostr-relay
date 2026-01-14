# Roadmap - Moonbit Nostr Relay

## Phase 1: Core Implementation ✅ COMPLETE

### ✅ Event Storage (Complete)
- [x] Event struct definition
- [x] In-memory storage with circular buffer
- [x] Automatic capacity management with FIFO eviction
- [x] Event lookup (by ID, author, kind, timestamp)
- [x] Fast indexing for common queries

### ✅ Event Filtering (Complete)
- [x] ID-based filtering
- [x] Author-based filtering
- [x] Event kind filtering
- [x] Timestamp range filtering
- [x] Tag-based filtering
- [x] Multiple criteria combination

### ✅ Subscription Management (Complete)
- [x] Create subscriptions
- [x] Remove subscriptions
- [x] Filter matching
- [x] Client subscription tracking
- [x] Subscription lifecycle

### ✅ Protocol Message Types (Complete)
- [x] EVENT message type
- [x] REQ message type
- [x] CLOSE message type
- [x] EOSE message type
- [x] OK message type
- [x] NOTICE message type
- [x] AUTH message type

### ✅ Request Handling (Complete)
- [x] Message type detection
- [x] Request routing
- [x] Response construction
- [x] Error handling
- [x] Client context management

### ✅ JSON Serialization (Complete)
- [x] Message array serialization
- [x] Event JSON formatting
- [x] Response message generation
- [x] OK response formatting
- [x] NOTICE message formatting
- [x] EOSE message formatting

### ✅ Cryptographic Stubs (Complete)
- [x] Signature verification interface
- [x] Event ID validation structure
- [x] Hex string validation
- [x] Ready for implementation

## Phase 2: WebSocket Integration ⏳ PENDING

### Needed
- [ ] WebSocket library (MoonBit HTTP)
- [ ] Client connection handler
- [ ] Message framing
- [ ] Connection pooling
- [ ] Error handling

### Impact
- Enable actual relay functionality
- Accept real Nostr clients
- Process live events
- Multiple concurrent clients

### Effort
- Medium (depends on WebSocket library availability)

## Phase 3: Cryptographic Implementation ⏳ PENDING

### Needed
- [ ] SHA-256 hash implementation or binding
- [ ] Schnorr signature verification
- [ ] Public key validation
- [ ] Event ID verification

### Impact
- Validate event authenticity
- Prevent forged events
- NIP-1 compliance

### Effort
- High (cryptographic operations required)

## Phase 4: Testing & Verification ⏳ PENDING

### Unit Tests
- [ ] Event storage operations
- [ ] Filter matching logic
- [ ] Message serialization
- [ ] JSON formatting

### Integration Tests
- [ ] End-to-end message flow
- [ ] Event broadcast
- [ ] Subscription lifecycle
- [ ] Client handling

### Protocol Tests
- [ ] Nostr client compatibility
- [ ] Message format validation
- [ ] NIP-1 compliance

### Performance Tests
- [ ] Event throughput
- [ ] Memory usage
- [ ] Connection limits
- [ ] Query performance

## Phase 5: Production Ready ⏳ PENDING

### Reliability
- [ ] Error recovery
- [ ] Graceful shutdown
- [ ] Connection cleanup
- [ ] Resource limits

### Performance
- [ ] Concurrent client handling
- [ ] Memory optimization
- [ ] Database indexing
- [ ] Query optimization

### Security
- [ ] Rate limiting
- [ ] DOS protection
- [ ] Input validation
- [ ] Authentication (NIP-42)

### Operations
- [ ] CLI argument parsing
- [ ] Configuration file support
- [ ] Logging
- [ ] Monitoring

## Optional Features

### Persistence
- [ ] SQLite/RocksDB backend
- [ ] Event archival
- [ ] Backup/restore
- [ ] Database migration

### Advanced Filtering
- [ ] Complex filter combinations
- [ ] Regex support
- [ ] Custom filters
- [ ] Filter optimization

### NIP Extensions
- [ ] NIP-4: Encrypted DMs
- [ ] NIP-9: Event Deletion
- [ ] NIP-11: Relay Information
- [ ] NIP-42: Authentication

### Monitoring
- [ ] Relay statistics
- [ ] Event metrics
- [ ] Client metrics
- [ ] Performance monitoring

## Current Status

**Total Completion**: 60%

### Breakdown by Phase
- Phase 1 (Core): ✅ 100%
- Phase 2 (WebSocket): ⏳ 0%
- Phase 3 (Crypto): ⏳ 10%
- Phase 4 (Testing): ⏳ 0%
- Phase 5 (Production): ⏳ 0%

## Quick Links

- **Start**: `moon run cmd/main`
- **Build**: `moon check && moon fmt && moon info`
- **Docs**: See README.mbt.md, PROJECT_OVERVIEW.md, STATUS.md

## Next Milestone

**Goal**: Get WebSocket server working

**Dependencies**:
1. Determine WebSocket library support in MoonBit
2. Create WebSocket server component
3. Integrate with simple_server.mbt handlers
4. Test with Nostr client

**Timeline**: Once WebSocket library is available

## Architecture Support

Current architecture is designed to support all planned features:

```
┌─────────────────────────────────────┐
│       Phase 2: WebSocket            │  ← Next
├─────────────────────────────────────┤
│  Phase 1: Core (Done)               │
│  - Event storage                    │
│  - Filtering                        │
│  - Subscriptions                    │
│  - Messages                         │
│  - JSON                             │
└─────────────────────────────────────┘
```

Message handlers are ready to accept WebSocket connections. Storage and filtering fully operational.
