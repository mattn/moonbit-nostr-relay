# Testing Guide for Moonbit Nostr Relay

## Running Tests

```bash
moon test
```

## Test Coverage

Run coverage analysis:

```bash
moon coverage analyze > uncovered.log
```

## Manual Testing Examples

### Filter Tests

```moonbit
// Empty filter matches all events
let filter = new()
let matches = match_event(filter, "id1", "author1", 1, 100UL)  // true

// Filter by ID
let filter = {
  ids: ["id1"],
  authors: [],
  kinds: [],
  since: None,
  until: None,
  limit: None,
}
let matches = match_event(filter, "id1", "author1", 1, 100UL)   // true
let matches = match_event(filter, "id2", "author1", 1, 100UL)   // false

// Filter by timestamp range
let filter = {
  ids: [],
  authors: [],
  kinds: [],
  since: Some(50UL),
  until: Some(150UL),
  limit: None,
}
let matches = match_event(filter, "id1", "author1", 1, 100UL)   // true
let matches = match_event(filter, "id1", "author1", 1, 40UL)    // false
```

### Event Store Tests

```moonbit
// Create store
let store = new_store(100)

// Add event
let event = {
  id: "evt1",
  pubkey: "pk1",
  created_at: 100UL,
  kind: 1,
  tags: [],
  content: "test",
  sig: "sig1",
}
let store = add_event(store, event)

// Check event exists
let exists = has_event(store, "evt1")  // true

// Find by author
let by_author = find_by_author(store, "pk1")

// Clear store
let store = clear(store)
```

### Relay Tests

```moonbit
// Create relay
let config = default_config()
let relay = new_relay(config)

// Add subscription
let filter = new_filter()
let relay = create_subscription(relay, "sub1", [filter])

// Remove subscription
let relay = remove_subscription(relay, "sub1")

// Get stats
let stats = get_stats(relay)
```

## Integration Testing

For full integration testing with WebSocket, use the relay server CLI:

```bash
./relay --port 8080
```

Then connect with a Nostr client to test:
- EVENT messages
- REQ/CLOSE subscriptions
- Event filtering and matching
