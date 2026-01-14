///| Event filtering implementation

///|
/// https://github.com/nostr-protocol/nostr/blob/master/PROTOCOL.md#filtering
pub struct Filter {
  ids : Array[String]
  authors : Array[String]
  kinds : Array[UInt]
  since : UInt64?
  until : UInt64?
  limit : UInt?
}

///|
/// Create an empty filter that matches all events
pub fn new() -> Filter {
  { ids: [], authors: [], kinds: [], since: None, until: None, limit: None }
}

///|
/// Check if event ID matches the filter
fn match_id(filter : Filter, event_id : String) -> Bool {
  if filter.ids.length() == 0 {
    return true
  }
  for i = 0; i < filter.ids.length(); i = i + 1 {
    if filter.ids[i] == event_id {
      return true
    }
  }
  false
}

///|
/// Check if author matches the filter
fn match_author(filter : Filter, author : String) -> Bool {
  if filter.authors.length() == 0 {
    return true
  }
  for i = 0; i < filter.authors.length(); i = i + 1 {
    if filter.authors[i] == author {
      return true
    }
  }
  false
}

///|
/// Check if event kind matches the filter
fn match_kind(filter : Filter, kind : UInt) -> Bool {
  if filter.kinds.length() == 0 {
    return true
  }
  for i = 0; i < filter.kinds.length(); i = i + 1 {
    if filter.kinds[i] == kind {
      return true
    }
  }
  false
}

///|
/// Check if timestamp matches the filter
fn match_timestamp(filter : Filter, created_at : UInt64) -> Bool {
  match (filter.since, filter.until) {
    (Some(since), Some(until)) => created_at >= since && created_at <= until
    (Some(since), None) => created_at >= since
    (None, Some(until)) => created_at <= until
    (None, None) => true
  }
}

///|
/// Match event against filter
pub fn match_event(
  filter : Filter,
  event_id : String,
  author : String,
  kind : UInt,
  created_at : UInt64,
) -> Bool {
  if !match_id(filter, event_id) {
    return false
  }
  if !match_author(filter, author) {
    return false
  }
  if !match_kind(filter, kind) {
    return false
  }
  match_timestamp(filter, created_at)
}
