///|
test "empty tag value list matches nothing" {
  let tags = [["e", "ref"], ["t", "x"]]
  // A non-empty value list matches when a value is present.
  inspect(new_tag_filter("e", ["ref"]).matches(tags), content="true")
  inspect(new_tag_filter("e", ["other"]).matches(tags), content="false")
  // An empty value list matches nothing, even for a tag the event carries.
  inspect(new_tag_filter("e", []).matches(tags), content="false")
  inspect(new_tag_filter("t", []).matches(tags), content="false")
}
