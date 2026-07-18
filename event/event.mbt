///| Nostr event structure (NIP-01)

///| https://github.com/nostr-protocol/nips/blob/master/01.md

///|
pub(all) struct Event {
  id : String // 32-byte lowercase hex, SHA-256 of serialized event
  pubkey : String // 32-byte lowercase hex, x-only public key
  created_at : UInt64 // Unix timestamp in seconds
  kind : UInt // Event kind
  tags : Array[Array[String]] // Tags
  content : String // Event content
  sig : String // 64-byte lowercase hex, BIP-340 Schnorr signature
}

///|
/// Event kinds
pub let kind_set_metadata : UInt = 0

///|
pub let kind_text_note : UInt = 1

///|
pub let kind_recommend_relay : UInt = 2

///|
pub let kind_contacts : UInt = 3

///|
pub let kind_encrypted_dm : UInt = 4

///|
pub let kind_event_deletion : UInt = 5

///|
pub let kind_repost : UInt = 6

///|
pub let kind_reaction : UInt = 7

///|
/// Kind 0, 3 and 10000-19999: only the latest event per (pubkey, kind) is kept
pub fn is_replaceable_kind(kind : UInt) -> Bool {
  kind == 0 || kind == 3 || (kind >= 10000 && kind < 20000)
}

///|
/// Kind 20000-29999: relayed to subscribers but never stored
pub fn is_ephemeral_kind(kind : UInt) -> Bool {
  kind >= 20000 && kind < 30000
}

///|
/// Kind 30000-39999: only the latest event per (pubkey, kind, d-tag) is kept
pub fn is_addressable_kind(kind : UInt) -> Bool {
  kind >= 30000 && kind < 40000
}

///|
/// Value of the first "d" tag, or "" if absent (used for addressable events)
pub fn Event::d_tag(self : Event) -> String {
  for tag in self.tags {
    if tag.length() >= 2 && tag[0] == "d" {
      return tag[1]
    }
  }
  ""
}

///|
/// NIP-40: value of the first parseable "expiration" tag as a unix
/// timestamp, or None when absent or malformed (malformed tags are ignored)
pub fn Event::expiration(self : Event) -> UInt64? {
  for tag in self.tags {
    if tag.length() >= 2 && tag[0] == "expiration" {
      match parse_timestamp(tag[1]) {
        Some(t) => return Some(t)
        None => ()
      }
    }
  }
  None
}

///|
/// NIP-40: true when the event carries an expiration timestamp at or
/// before `now` and must no longer be served to clients
pub fn Event::is_expired(self : Event, now : UInt64) -> Bool {
  match self.expiration() {
    Some(t) => t <= now
    None => false
  }
}

///|
/// Parse a non-empty all-digit decimal string; None on any other input
fn parse_timestamp(s : String) -> UInt64? {
  if s.length() == 0 {
    return None
  }
  let mut acc : UInt64 = 0
  for c in s {
    if c >= '0' && c <= '9' {
      acc = acc * 10 + (c.to_int() - 48).reinterpret_as_uint().to_uint64()
    } else {
      return None
    }
  }
  Some(acc)
}

///|
fn is_lower_hex(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for c in s {
    if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
      return false
    }
  }
  true
}

///|
/// Validate the structural shape of an event (not its cryptographic validity)
pub fn Event::validate(self : Event) -> Result[Unit, String] {
  if self.id.length() != 64 || !is_lower_hex(self.id) {
    return Err("id must be 64 lowercase hex characters")
  }
  if self.pubkey.length() != 64 || !is_lower_hex(self.pubkey) {
    return Err("pubkey must be 64 lowercase hex characters")
  }
  if self.sig.length() != 128 || !is_lower_hex(self.sig) {
    return Err("sig must be 128 lowercase hex characters")
  }
  if self.kind >= 65536 {
    return Err("kind must be between 0 and 65535")
  }
  Ok(())
}

///|
/// Parse an event from its JSON representation
pub fn Event::from_json(j : Json) -> Result[Event, String] {
  guard j is Object(obj) else { return Err("event must be a JSON object") }
  guard obj.get("id") is Some(String(id)) else {
    return Err("missing or invalid id")
  }
  guard obj.get("pubkey") is Some(String(pubkey)) else {
    return Err("missing or invalid pubkey")
  }
  guard obj.get("created_at") is Some(Number(created_at, ..)) else {
    return Err("missing or invalid created_at")
  }
  guard obj.get("kind") is Some(Number(kind, ..)) else {
    return Err("missing or invalid kind")
  }
  guard obj.get("content") is Some(String(content)) else {
    return Err("missing or invalid content")
  }
  guard obj.get("sig") is Some(String(sig)) else {
    return Err("missing or invalid sig")
  }
  guard obj.get("tags") is Some(Array(tags_json)) else {
    return Err("missing or invalid tags")
  }
  if created_at < 0.0 || kind < 0.0 || kind >= 65536.0 {
    return Err("created_at or kind out of range")
  }
  let tags : Array[Array[String]] = []
  for tag_json in tags_json {
    guard tag_json is Array(items) else { return Err("tag must be an array") }
    let tag : Array[String] = []
    for item in items {
      guard item is String(s) else { return Err("tag item must be a string") }
      tag.push(s)
    }
    tags.push(tag)
  }
  Ok({
    id,
    pubkey,
    created_at: created_at.to_uint64(),
    kind: kind.to_int().reinterpret_as_uint(),
    tags,
    content,
    sig,
  })
}

///|
/// Convert an event to its JSON representation
pub fn Event::to_json(self : Event) -> Json {
  let obj : Map[String, Json] = {}
  obj.set("id", self.id.to_json())
  obj.set("pubkey", self.pubkey.to_json())
  obj.set("created_at", self.created_at.to_double().to_json())
  obj.set("kind", self.kind.to_uint64().to_double().to_json())
  obj.set("tags", self.tags.to_json())
  obj.set("content", self.content.to_json())
  obj.set("sig", self.sig.to_json())
  obj.to_json()
}

///|
/// NIP-01 string escaping for the id serialization: only the characters
/// listed in the spec are escaped, everything else is included verbatim.
fn escape_nip01(sb : StringBuilder, s : String) -> Unit {
  for c in s {
    match c {
      '\n' => sb.write_string("\\n")
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\r' => sb.write_string("\\r")
      '\t' => sb.write_string("\\t")
      '\u{08}' => sb.write_string("\\b")
      '\u{0C}' => sb.write_string("\\f")
      _ => sb.write_char(c)
    }
  }
}

///|
/// NIP-01 canonical serialization used to compute the event id:
/// [0,"pubkey",created_at,kind,tags,"content"]
pub fn Event::serialize_for_id(self : Event) -> String {
  let sb = StringBuilder::new()
  sb.write_string("[0,\"")
  sb.write_string(self.pubkey)
  sb.write_string("\",")
  sb.write_string(self.created_at.to_string())
  sb.write_string(",")
  sb.write_string(self.kind.to_string())
  sb.write_string(",[")
  for i, tag in self.tags {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string("[")
    for k, item in tag {
      if k > 0 {
        sb.write_string(",")
      }
      sb.write_string("\"")
      escape_nip01(sb, item)
      sb.write_string("\"")
    }
    sb.write_string("]")
  }
  sb.write_string("],\"")
  escape_nip01(sb, self.content)
  sb.write_string("\"]")
  sb.to_string()
}
