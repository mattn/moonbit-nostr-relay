///|
/// NIP-11 relay information document
pub fn nip11_doc() -> String {
  let m : Map[String, Json] = {}
  m.set("name", "moonbit-nostr-relay".to_json())
  m.set("description", "A Nostr relay implemented in MoonBit".to_json())
  m.set("software", "https://github.com/mattn/moonbit-nostr-relay".to_json())
  m.set("version", "0.1.1".to_json())
  m.set(
    "supported_nips",
    ([1.0.to_json(), 11.0.to_json()] : Array[Json]).to_json(),
  )
  let limitation : Map[String, Json] = {}
  limitation.set("max_message_length", 1048576.0.to_json())
  limitation.set("max_event_tags", 2000.0.to_json())
  m.set("limitation", limitation.to_json())
  m.to_json().stringify()
}
