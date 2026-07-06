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
/// among the filter values. An empty value list matches any event that
/// has the tag at all.
pub fn TagFilter::matches(
  self : TagFilter,
  tags : Array[Array[String]],
) -> Bool {
  for tag in tags {
    if tag.length() >= 2 && tag[0] == self.name {
      if self.values.length() == 0 {
        return true
      }
      for v in self.values {
        if v == tag[1] {
          return true
        }
      }
    }
  }
  false
}
