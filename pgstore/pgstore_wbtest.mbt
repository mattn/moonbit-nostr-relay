///|
test "first_d_tag extracts the first d tag value" {
  // No d tag -> "" (matches @event.Event::d_tag for a missing d tag).
  inspect(first_d_tag("[]"), content="")
  inspect(first_d_tag("[[\"e\",\"x\"]]"), content="")
  // First d tag wins even when a later d tag is present.
  inspect(first_d_tag("[[\"d\",\"a\"],[\"d\",\"x\"]]"), content="a")
  // d tag after other tags.
  inspect(first_d_tag("[[\"e\",\"x\"],[\"d\",\"slug\"]]"), content="slug")
  // Empty d value.
  inspect(first_d_tag("[[\"d\",\"\"]]"), content="")
  // Malformed input -> "".
  inspect(first_d_tag("not json"), content="")
}
