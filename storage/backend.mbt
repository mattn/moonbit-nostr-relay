///|
/// Storage backend abstraction. The relay engine talks to storage only
/// through this trait, so backends (in-memory, PostgreSQL, ...) are
/// interchangeable.
pub(open) trait Storage {
  fn add(Self, @event.Event) -> AddOutcome
  fn query(Self, @filter.Filter) -> Array[@event.Event]
  fn count_filtered(Self, Array[@filter.Filter], UInt64) -> Int
  fn delete(Self, String, String) -> DeleteOutcome
  fn delete_gift_wrap(Self, String, String) -> DeleteOutcome
  fn count(Self) -> Int
}

///|
pub impl Storage for EventStore with fn add(self, ev) {
  EventStore::add(self, ev)
}

///|
pub impl Storage for EventStore with fn query(self, f) {
  EventStore::query(self, f)
}

///|
pub impl Storage for EventStore with fn count_filtered(self, filters, now) {
  EventStore::count_filtered(self, filters, now)
}

///|
pub impl Storage for EventStore with fn delete(self, id, pubkey) {
  EventStore::delete(self, id, pubkey)
}

///|
pub impl Storage for EventStore with fn delete_gift_wrap(self, id, recipient) {
  EventStore::delete_gift_wrap(self, id, recipient)
}

///|
pub impl Storage for EventStore with fn count(self) {
  EventStore::count(self)
}
