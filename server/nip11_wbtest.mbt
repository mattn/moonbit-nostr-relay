///|
/// NIP-11 relay_countries: comma separated, whitespace tolerated, and the key
/// is left out entirely rather than emitted empty.
test "nip11 relay_countries" {
  let one = nip11_doc()
  assert_true(one.contains("\"relay_countries\":[\"JP\"]"))

  let many = nip11_doc(countries="JP, US ,DE")
  assert_true(many.contains("\"relay_countries\":[\"JP\",\"US\",\"DE\"]"))

  let none = nip11_doc(countries="")
  assert_false(none.contains("relay_countries"))

  let blanks = nip11_doc(countries=" , ")
  assert_false(blanks.contains("relay_countries"))
}
