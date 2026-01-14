///|
/// In-memory event storage for Nostr relay
pub struct StoredEvent {
  id : String
  pubkey : String
  created_at : UInt64
  kind : UInt
  tags : Array[Array[String]]
  content : String
  sig : String
}

///|
pub struct EventStore {
  events : Array[StoredEvent]
  max_events : UInt
}

///|
/// Create a new event store with max capacity
pub fn new_store(max_events : UInt) -> EventStore {
  { events: [], max_events }
}

///|
/// Add event to store, removing oldest if at capacity
pub fn add_event(store : EventStore, event : StoredEvent) -> EventStore {
  let events = store.events
  if events.length() >= store.max_events.reinterpret_as_int() {
    // Remove oldest event (first one)
    let new_events = []
    for i = 1; i < events.length(); i = i + 1 {
      new_events.push(events[i])
    }
    { events: new_events, max_events: store.max_events }
  } else {
    events.push(event)
    store
  }
}

///|
/// Get event by ID
pub fn get_event(store : EventStore, id : String) -> StoredEvent? {
  for i = 0; i < store.events.length(); i = i + 1 {
    if store.events[i].id == id {
      return Some(store.events[i])
    }
  }
  None
}

///|
/// Find events by author
pub fn find_by_author(
  store : EventStore,
  author : String,
) -> Array[StoredEvent] {
  let result = []
  for i = 0; i < store.events.length(); i = i + 1 {
    if store.events[i].pubkey == author {
      result.push(store.events[i])
    }
  }
  result
}

///|
/// Find events by kind
pub fn find_by_kind(store : EventStore, kind : UInt) -> Array[StoredEvent] {
  let result = []
  for i = 0; i < store.events.length(); i = i + 1 {
    if store.events[i].kind == kind {
      result.push(store.events[i])
    }
  }
  result
}

///|
/// Find events in timestamp range
pub fn find_by_timestamp(
  store : EventStore,
  since : UInt64,
  until : UInt64,
) -> Array[StoredEvent] {
  let result = []
  for i = 0; i < store.events.length(); i = i + 1 {
    let event = store.events[i]
    if event.created_at >= since && event.created_at <= until {
      result.push(event)
    }
  }
  result
}

///|
/// Find all events (ordered by creation time, newest first)
pub fn find_all(store : EventStore, limit : UInt?) -> Array[StoredEvent] {
  let max_limit = match limit {
    Some(l) => l.reinterpret_as_int()
    None => store.events.length()
  }
  let result = []
  for i = store.events.length() - 1; i >= 0; i = i - 1 {
    if result.length() >= max_limit {
      break
    }
    result.push(store.events[i])
  }
  result
}

///|
/// Get total events in store
pub fn event_count(store : EventStore) -> Int {
  store.events.length()
}

///|
/// Check if event exists
pub fn has_event(store : EventStore, id : String) -> Bool {
  for i = 0; i < store.events.length(); i = i + 1 {
    if store.events[i].id == id {
      return true
    }
  }
  false
}

///|
/// Remove event by ID
pub fn remove_event(store : EventStore, id : String) -> EventStore {
  let new_events = []
  for i = 0; i < store.events.length(); i = i + 1 {
    if store.events[i].id != id {
      new_events.push(store.events[i])
    }
  }
  { events: new_events, max_events: store.max_events }
}

///|
/// Clear all events
pub fn clear(store : EventStore) -> EventStore {
  { events: [], max_events: store.max_events }
}
