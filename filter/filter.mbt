///| Event filtering (NIP-01)

///| https://github.com/nostr-protocol/nips/blob/master/01.md

///|
pub struct Filter {
  ids : Array[String]
  authors : Array[String]
  kinds : Array[UInt]
  since : UInt64?
  until : UInt64?
  limit : Int?
  tags : Array[TagFilter] // "#e", "#p", ... entries
}

///|
/// Create an empty filter that matches all events
pub fn new() -> Filter {
  {
    ids: [],
    authors: [],
    kinds: [],
    since: None,
    until: None,
    limit: None,
    tags: [],
  }
}

///|
fn json_string_array(j : Json) -> Result[Array[String], String] {
  guard j is Array(items) else { return Err("expected an array of strings") }
  let out : Array[String] = []
  for item in items {
    guard item is String(s) else { return Err("expected an array of strings") }
    out.push(s)
  }
  Ok(out)
}

///|
/// Parse a filter from its JSON representation. Unknown keys are ignored.
pub fn Filter::from_json(j : Json) -> Result[Filter, String] {
  guard j is Object(obj) else { return Err("filter must be a JSON object") }
  let ids : Array[String] = []
  let authors : Array[String] = []
  let kinds : Array[UInt] = []
  let tags : Array[TagFilter] = []
  let mut since : UInt64? = None
  let mut until : UInt64? = None
  let mut limit : Int? = None
  for key, value in obj {
    match key {
      "ids" =>
        match json_string_array(value) {
          Ok(v) => ids.append(v)
          Err(e) => return Err("ids: " + e)
        }
      "authors" =>
        match json_string_array(value) {
          Ok(v) => authors.append(v)
          Err(e) => return Err("authors: " + e)
        }
      "kinds" => {
        guard value is Array(items) else {
          return Err("kinds: expected an array of numbers")
        }
        for item in items {
          guard item is Number(n, ..) else {
            return Err("kinds: expected an array of numbers")
          }
          if n < 0.0 || n >= 65536.0 {
            return Err("kinds: kind out of range")
          }
          kinds.push(n.to_int().reinterpret_as_uint())
        }
      }
      "since" => {
        guard value is Number(n, ..) else {
          return Err("since: expected a number")
        }
        since = Some(n.to_uint64())
      }
      "until" => {
        guard value is Number(n, ..) else {
          return Err("until: expected a number")
        }
        until = Some(n.to_uint64())
      }
      "limit" => {
        guard value is Number(n, ..) else {
          return Err("limit: expected a number")
        }
        limit = Some(n.to_int())
      }
      _ =>
        if key.has_prefix("#") && key.length() >= 2 {
          let name = key[1:].to_owned()
          match json_string_array(value) {
            Ok(values) => tags.push(new_tag_filter(name, values))
            Err(e) => return Err(key + ": " + e)
          }
        }
    }
  }
  Ok({ ids, authors, kinds, since, until, limit, tags })
}

///|
fn contains(arr : Array[String], s : String) -> Bool {
  for item in arr {
    if item == s {
      return true
    }
  }
  false
}

///|
/// Match an event against this filter
pub fn Filter::matches(self : Filter, ev : @event.Event) -> Bool {
  if self.ids.length() > 0 && !contains(self.ids, ev.id) {
    return false
  }
  if self.authors.length() > 0 && !contains(self.authors, ev.pubkey) {
    return false
  }
  if self.kinds.length() > 0 {
    let mut found = false
    for k in self.kinds {
      if k == ev.kind {
        found = true
        break
      }
    }
    if !found {
      return false
    }
  }
  match self.since {
    Some(since) => if ev.created_at < since { return false }
    None => ()
  }
  match self.until {
    Some(until) => if ev.created_at > until { return false }
    None => ()
  }
  for tf in self.tags {
    if !tf.matches(ev.tags) {
      return false
    }
  }
  true
}
