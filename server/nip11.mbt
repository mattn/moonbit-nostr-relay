///|
/// NIP-11 relay information document
pub fn nip11_doc(
  name? : String = "moonbit-nostr-relay",
  description? : String = "A Nostr relay implemented in MoonBit",
  pubkey? : String = "",
  contact? : String = "",
  icon? : String = "",
) -> String {
  let m : Map[String, Json] = {}
  m.set("name", name.to_json())
  m.set("description", description.to_json())
  if pubkey != "" {
    m.set("pubkey", pubkey.to_json())
  }
  if contact != "" {
    m.set("contact", contact.to_json())
  }
  if icon != "" {
    m.set("icon", icon.to_json())
  }
  m.set("software", "https://github.com/mattn/moonbit-nostr-relay".to_json())
  m.set("version", "0.1.3".to_json())
  m.set(
    "supported_nips",
    (
      [
        1.0.to_json(),
        2.0.to_json(),
        4.0.to_json(),
        9.0.to_json(),
        11.0.to_json(),
        12.0.to_json(),
        15.0.to_json(),
        16.0.to_json(),
        20.0.to_json(),
        22.0.to_json(),
        26.0.to_json(),
        28.0.to_json(),
        33.0.to_json(),
        40.0.to_json(),
        70.0.to_json(),
      ] : Array[Json]).to_json(),
  )
  let limitation : Map[String, Json] = {}
  limitation.set("max_message_length", 1048576.0.to_json())
  limitation.set("max_event_tags", 2000.0.to_json())
  m.set("limitation", limitation.to_json())
  m.to_json().stringify()
}
