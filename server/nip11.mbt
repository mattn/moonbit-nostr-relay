///|
/// NIP-11 relay information document
pub fn nip11_doc(
  name? : String = "moonbit-nostr-relay",
  description? : String = "A Nostr relay implemented in MoonBit",
  pubkey? : String = "",
  contact? : String = "",
  icon? : String = "",
  countries? : String = "JP",
  min_pow_difficulty? : Int = 0,
) -> String {
  let m : Map[String, Json] = {}
  m.set("name", Json(name))
  m.set("description", Json(description))
  if pubkey != "" {
    m.set("pubkey", Json(pubkey))
  }
  if contact != "" {
    m.set("contact", Json(contact))
  }
  if icon != "" {
    m.set("icon", Json(icon))
  }
  m.set("software", Json("https://github.com/mattn/moonbit-nostr-relay"))
  m.set("version", Json("0.1.3"))
  m.set(
    "supported_nips",
    Json::array([
      Json(1.0),
      Json(4.0),
      Json(9.0),
      Json(11.0),
      Json(13.0),
      Json(17.0),
      Json(26.0),
      Json(40.0),
      Json(42.0),
      Json(45.0),
      Json(50.0),
      Json(59.0),
      Json(66.0),
      Json(70.0),
      Json(78.0),
    ]),
  )
  // NIP-11 relay_countries: the two letter codes of the jurisdictions the
  // relay operates under, comma separated in RELAY_COUNTRIES.
  let country_list : Array[Json] = []
  for country in countries.split(",") {
    let trimmed = country.to_string().trim(chars=" \t").to_string()
    if trimmed != "" {
      country_list.push(Json(trimmed))
    }
  }
  if country_list.length() > 0 {
    m.set("relay_countries", Json(country_list))
  }
  let limitation : Map[String, Json] = {}
  limitation.set("max_message_length", Json(1048576.0))
  limitation.set("max_event_tags", Json(2000.0))
  limitation.set("min_pow_difficulty", Json(min_pow_difficulty.to_double()))
  m.set("limitation", Json(limitation))
  Json(m).stringify()
}
