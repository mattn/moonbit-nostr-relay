///|
/// Indexing for fast event lookup
pub struct EventIndex {
  by_id : Array[(String, String)] // id -> event_id mapping
  by_author : Array[(String, Array[String])] // author -> event_ids
  by_kind : Array[(UInt, Array[String])] // kind -> event_ids
}

///|
pub fn new_index() -> EventIndex {
  { by_id: [], by_author: [], by_kind: [] }
}

///|
/// Add event to indices
pub fn index_event(
  idx : EventIndex,
  event_id : String,
  author : String,
  kind : UInt,
) -> EventIndex {
  let by_id = idx.by_id
  by_id.push((event_id, event_id))

  // Index by author - add or update
  let by_author = idx.by_author
  let mut found_author = false
  for i = 0; i < by_author.length(); i = i + 1 {
    if by_author[i].0 == author {
      by_author[i].1.push(event_id)
      found_author = true
    }
  }
  if !found_author {
    let ids = [event_id]
    by_author.push((author, ids))
  }

  // Index by kind - add or update
  let by_kind = idx.by_kind
  let mut found_kind = false
  for i = 0; i < by_kind.length(); i = i + 1 {
    if by_kind[i].0 == kind {
      by_kind[i].1.push(event_id)
      found_kind = true
    }
  }
  if !found_kind {
    let ids = [event_id]
    by_kind.push((kind, ids))
  }
  idx
}

///|
/// Get event IDs for author
pub fn get_by_author(idx : EventIndex, author : String) -> Array[String] {
  for i = 0; i < idx.by_author.length(); i = i + 1 {
    if idx.by_author[i].0 == author {
      return idx.by_author[i].1
    }
  }
  []
}

///|
/// Get event IDs for kind
pub fn get_by_kind(idx : EventIndex, kind : UInt) -> Array[String] {
  for i = 0; i < idx.by_kind.length(); i = i + 1 {
    if idx.by_kind[i].0 == kind {
      return idx.by_kind[i].1
    }
  }
  []
}
