///|
/// Tag-based filtering for Nostr events ("#e", "#p", ... filter keys)
pub struct TagFilter {
  name : String // Tag name (e.g. "e", "p")
  values : Array[String] // Matching values
}

///|
pub fn new_tag_filter(name : String, values : Array[String]) -> TagFilter {
  { name, values }
}

///|
/// An event matches when it has at least one tag [name, v, ...] with v
/// among the filter values. An empty value list matches nothing (there is
/// no value to match, per NIP-01's OR-over-values semantics); this also
/// keeps the in-memory backend consistent with the PostgreSQL one.
pub fn TagFilter::matches(
  self : TagFilter,
  tags : Array[Array[String]],
) -> Bool {
  if self.values.length() == 0 {
    return false
  }
  for tag in tags {
    if tag.length() >= 2 && tag[0] == self.name {
      for v in self.values {
        if v == tag[1] {
          return true
        }
      }
    }
  }
  false
}
