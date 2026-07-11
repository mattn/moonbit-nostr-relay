///|
test "only single-letter tag keys become tag filters" {
  let m : Map[String, Json] = {
    "#e": ["ref"].to_json(),
    "#foo": ["bar"].to_json(),
  }
  let f = match Filter::from_json(m.to_json()) {
    Ok(f) => f
    Err(e) => {
      fail(e)
      return
    }
  }
  // "#e" is kept, "#foo" is ignored (not a NIP-01 tag filter).
  inspect(f.tags.length(), content="1")
  let with_e : Array[Array[String]] = [["e", "ref"]]
  let with_foo : Array[Array[String]] = [["foo", "bar"]]
  inspect(new_tag_filter("e", ["ref"]).matches(with_e), content="true")
  // The event carrying only a "foo" tag is not constrained by the filter.
  inspect(f.matches({
    id: "a".repeat(64),
    pubkey: "b".repeat(64),
    created_at: 1000,
    kind: 1,
    tags: with_foo,
    content: "x",
    sig: "d".repeat(128),
  }), content="false")
}
