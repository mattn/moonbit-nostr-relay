///|
/// Tag-based filtering for Nostr events
pub struct TagFilter {
  name : String // Tag name (e.g., "e", "p")
  values : Array[String] // Matching values
}

///|
pub fn new_tag_filter(name : String, values : Array[String]) -> TagFilter {
  { name, values }
}

///|
/// Check if tag matches the filter
pub fn match_tag(filter : TagFilter, tag_values : Array[String]) -> Bool {
  if filter.values.length() == 0 {
    return true
  }
  for i = 0; i < filter.values.length(); i = i + 1 {
    for j = 0; j < tag_values.length(); j = j + 1 {
      if filter.values[i] == tag_values[j] {
        return true
      }
    }
  }
  false
}

///|
/// Extract tag values from event tags
pub fn extract_tag_values(
  tags : Array[Array[String]],
  tag_name : String,
) -> Array[String] {
  let values = []
  for i = 0; i < tags.length(); i = i + 1 {
    if tags[i].length() > 0 && tags[i][0] == tag_name {
      if tags[i].length() > 1 {
        values.push(tags[i][1])
      }
    }
  }
  values
}
