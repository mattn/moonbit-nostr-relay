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

///|
test "NIP-01 empty filter lists match nothing" {
  let ev : @event.Event = {
    id: "a".repeat(64),
    pubkey: "b".repeat(64),
    created_at: 1000,
    kind: 1,
    tags: [["e", "ref"]],
    content: "x",
    sig: "d".repeat(128),
  }
  for key in ["ids", "authors", "kinds", "#e"] {
    let empty : Array[String] = []
    let m : Map[String, Json] = Map::from_array([(key, empty.to_json())])
    let f = match Filter::from_json(m.to_json()) {
      Ok(f) => f
      Err(e) => {
        fail(e)
        return
      }
    }
    inspect(f.match_nothing, content="true")
    inspect(f.matches(ev), content="false")
  }
  // A filter without those keys still matches everything.
  let all : Map[String, Json] = { "limit": (3).to_json() }
  match Filter::from_json(all.to_json()) {
    Ok(f) => inspect(f.matches(ev), content="true")
    Err(e) => fail(e)
  }
}
