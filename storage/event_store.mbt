///|
/// In-memory event storage for the Nostr relay
pub struct EventStore {
  events : Array[@event.Event]
  max_events : Int
}

///|
pub(all) enum AddOutcome {
  Added // stored (possibly replacing an older replaceable event)
  Duplicate // already have this exact event id
  Stale // a newer replaceable/addressable event exists for this key
  Failed(String) // storage backend error
}

///|
pub fn new_store(max_events : Int) -> EventStore {
  { events: [], max_events }
}

///|
fn find_index(store : EventStore, pred : (@event.Event) -> Bool) -> Int {
  for i, ev in store.events {
    if pred(ev) {
      return i
    }
  }
  -1
}

///|
/// Add an event to the store, honouring NIP-01 storage semantics for
/// replaceable and addressable kinds. Ephemeral events must not be passed
/// here (the relay layer broadcasts them without storing).
pub fn EventStore::add(self : EventStore, ev : @event.Event) -> AddOutcome {
  if find_index(self, fn(e) { e.id == ev.id }) >= 0 {
    return Duplicate
  }
  let replace_idx = if @event.is_replaceable_kind(ev.kind) {
    find_index(self, fn(e) { e.pubkey == ev.pubkey && e.kind == ev.kind })
  } else if @event.is_addressable_kind(ev.kind) {
    let d = ev.d_tag()
    find_index(self, fn(e) {
      e.pubkey == ev.pubkey && e.kind == ev.kind && e.d_tag() == d
    })
  } else {
    -1
  }
  if replace_idx >= 0 {
    let existing = self.events[replace_idx]
    // On equal timestamps NIP-01 keeps the event with the lowest id
    if existing.created_at > ev.created_at ||
      (existing.created_at == ev.created_at && existing.id < ev.id) {
      return Stale
    }
    let _ = self.events.remove(replace_idx)
  }
  if self.events.length() >= self.max_events {
    let _ = self.events.remove(0)
  }
  self.events.push(ev)
  Added
}

///|
/// Return events matching the filter, newest first, honouring the
/// filter's limit when present.
pub fn EventStore::query(
  self : EventStore,
  f : @filter.Filter,
) -> Array[@event.Event] {
  let result : Array[@event.Event] = []
  for ev in self.events {
    if f.matches(ev) {
      result.push(ev)
    }
  }
  result.sort_by(fn(a, b) {
    if a.created_at > b.created_at {
      -1
    } else if a.created_at < b.created_at {
      1
    } else if a.id < b.id {
      -1
    } else if a.id > b.id {
      1
    } else {
      0
    }
  })
  match f.limit {
    Some(limit) => {
      let n = if limit < 0 { 0 } else { limit }
      if result.length() > n {
        result.truncate(n)
      }
    }
    None => ()
  }
  result
}

///|
pub fn EventStore::count(self : EventStore) -> Int {
  self.events.length()
}
