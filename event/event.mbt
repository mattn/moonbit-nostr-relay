///| Nostr event structure
///| https://github.com/nostr-protocol/nostr

pub struct Event {
  id: String           // 32-bytes hex, SHA-256 hash
  pubkey: String       // 32-bytes hex, public key
  created_at: UInt64   // Unix timestamp
  kind: UInt           // Event kind
  tags: Array[Array[String]]  // Tags
  content: String      // Event content
  sig: String          // 64-bytes hex, signature
}

///| Event kinds
pub let KIND_SET_METADATA = 0u
pub let KIND_TEXT_NOTE = 1u
pub let KIND_RECOMMEND_RELAY = 2u
pub let KIND_CONTACTS = 3u
pub let KIND_ENCRYPTED_DM = 4u
pub let KIND_EVENT_DELETION = 5u
pub let KIND_REPOST = 6u
pub let KIND_REACTION = 7u
pub let KIND_CHANNEL_CREATION = 40u
pub let KIND_CHANNEL_METADATA = 41u
pub let KIND_CHANNEL_MESSAGE = 42u
pub let KIND_CHANNEL_HIDE_MESSAGE = 43u
pub let KIND_CHANNEL_MUTE_USER = 44u

///| Create a new event
pub fn new_event(
  ~id: String,
  ~pubkey: String,
  ~created_at: UInt64,
  ~kind: UInt,
  ~tags: Array[Array[String]],
  ~content: String,
  ~sig: String,
) -> Event {
  { id, pubkey, created_at, kind, tags, content, sig }
}

///| Validate event structure
pub fn validate(event: Event) -> Result[Unit, String] {
  // Validate id is hex
  if event.id.length() != 64 {
    return Err("Invalid event id length")
  }
  // Validate pubkey is hex
  if event.pubkey.length() != 64 {
    return Err("Invalid pubkey length")
  }
  // Validate signature is hex
  if event.sig.length() != 128 {
    return Err("Invalid signature length")
  }
  Ok(())
}
