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
  search : String? // NIP-50
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
    search: None,
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
  let mut search : String? = None
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
      "search" => {
        guard value is String(sv) else { return Err("search: expected a string") }
        search = Some(sv)
      }
      _ =>
        // NIP-01 tag filters use a single-letter name ("#e", "#p", ...).
        // The PostgreSQL backend only indexes single-character tag names, so
        // honouring longer keys here would match in memory but never in
        // PostgreSQL; ignore them in both, like any other unknown key.
        if key.has_prefix("#") && key.length() == 2 {
          let name = key[1:].to_owned()
          match json_string_array(value) {
            Ok(values) => tags.push(new_tag_filter(name, values))
            Err(e) => return Err(key + ": " + e)
          }
        }
    }
  }
  Ok({ ids, authors, kinds, since, until, limit, search, tags })
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
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn to_chars(s : String) -> Array[Char] {
  let out : Array[Char] = []
  for c in s {
    out.push(c)
  }
  out
}

///|
/// ASCII case-insensitive character comparison. Non-ASCII characters, which
/// is most of what gets searched here, compare unchanged.
fn eq_ignore_ascii_case(a : Char, b : Char) -> Bool {
  let mut x = a.to_int()
  let mut y = b.to_int()
  if x >= 0x41 && x <= 0x5A {
    x = x + 32
  }
  if y >= 0x41 && y <= 0x5A {
    y = y + 32
  }
  x == y
}

///|
fn contains_ignore_ascii_case(hay : Array[Char], needle : Array[Char]) -> Bool {
  let n = needle.length()
  if n == 0 {
    return true
  }
  let h = hay.length()
  if n > h {
    return false
  }
  for i = 0; i <= h - n; i = i + 1 {
    let mut matched = true
    for j = 0; j < n; j = j + 1 {
      if !eq_ignore_ascii_case(hay[i + j], needle[j]) {
        matched = false
        break
      }
    }
    if matched {
      return true
    }
  }
  false
}

///|
/// NIP-50: split the search string into words. An event matches when every
/// word occurs in its content, which is also what the PostgreSQL backend asks
/// for, so stored and live results agree.
pub fn Filter::search_words(self : Filter) -> Array[String] {
  let out : Array[String] = []
  guard self.search is Some(s) else { return out }
  let chars = to_chars(s)
  let n = chars.length()
  let mut i = 0
  while i < n {
    while i < n && is_space(chars[i]) {
      i = i + 1
    }
    if i >= n {
      break
    }
    let sb = StringBuilder::new()
    while i < n && !is_space(chars[i]) {
      sb.write_char(chars[i])
      i = i + 1
    }
    out.push(sb.to_string())
  }
  out
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
  let words = self.search_words()
  if words.length() > 0 {
    let content = to_chars(ev.content)
    for word in words {
      if !contains_ignore_ascii_case(content, to_chars(word)) {
        return false
      }
    }
  }
  for tf in self.tags {
    if !tf.matches(ev.tags) {
      return false
    }
  }
  true
}
