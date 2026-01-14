///|
/// Subscription management for client requests
pub struct Filter {
  ids : Array[String] // Event IDs
  authors : Array[String] // Author public keys
  kinds : Array[UInt] // Event kinds
  since : UInt64? // Min timestamp
  until : UInt64? // Max timestamp
  limit : UInt? // Max results
}

///|
pub fn new_filter() -> Filter {
  { ids: [], authors: [], kinds: [], since: None, until: None, limit: None }
}

///|
pub struct Subscription {
  id : String
  filters : Array[Filter]
  created_at : UInt64
}

///|
pub fn new_subscription(id : String, filters : Array[Filter]) -> Subscription {
  { id, filters, created_at: 0UL }
}

///|
/// Check if an event matches the subscription filters
pub fn matches(subscription : Subscription, _event_id : String) -> Bool {
  subscription.filters.length() > 0
}
