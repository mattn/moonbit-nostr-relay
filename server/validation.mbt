///| Event validation

///|
/// Validate an incoming event: structural shape always; event id hash and
/// BIP-340 Schnorr signature when `verify_sigs` is enabled. Events carrying
/// a NIP-26 delegation tag are additionally checked against it.
pub fn verify_event(
  ev : @event.Event,
  verify_sigs : Bool,
) -> Result[Unit, String] {
  match ev.validate() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if verify_sigs {
    match verify_crypto(ev) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  verify_delegation(ev, verify_sigs)
}

///|
/// Cryptographic checks: recompute the event id from the NIP-01 canonical
/// serialization and verify the Schnorr signature over it.
fn verify_crypto(ev : @event.Event) -> Result[Unit, String] {
  let computed = @crypto.sha256_hex(@crypto.utf8_bytes(ev.serialize_for_id()))
  if computed != ev.id {
    return Err("event id does not match content hash")
  }
  let id_bytes = match @crypto.hex_to_bytes(ev.id) {
    Ok(b) => b
    Err(e) => return Err("bad event id: " + e)
  }
  if !@crypto.schnorr_verify(ev.pubkey, id_bytes, ev.sig) {
    return Err("bad signature")
  }
  Ok(())
}

///|
/// NIP-70: an event is protected when any of its tags has "-" as its first
/// element. This relay has no NIP-42 AUTH, so it can never prove a protected
/// event is being published by its author and must reject it.
fn is_protected(ev : @event.Event) -> Bool {
  for tag in ev.tags {
    if tag.length() >= 1 && tag[0] == "-" {
      return true
    }
  }
  false
}

///|
/// NIP-26 delegated event signing. Events without a "delegation" tag pass
/// unchanged. When the tag is present, its shape and conditions string are
/// always checked; the delegator's Schnorr signature over the delegation
/// token sha256("nostr:delegation:<pubkey>:<conditions>") is verified when
/// `verify_sig` is enabled.
fn verify_delegation(
  ev : @event.Event,
  verify_sig : Bool,
) -> Result[Unit, String] {
  let mut delegation : Array[String]? = None
  for tag in ev.tags {
    if tag.length() >= 4 && tag[0] == "delegation" {
      delegation = Some(tag)
      break
    }
  }
  let tag = match delegation {
    None => return Ok(())
    Some(t) => t
  }
  if tag.length() != 4 {
    return Err("delegation tag must have exactly 4 elements")
  }
  let delegator = tag[1]
  let conditions = tag[2]
  let signature = tag[3]
  if delegator == "" || conditions == "" || signature == "" {
    return Err("delegation tag must not have empty elements")
  }
  if delegator.length() != 64 || !(@crypto.hex_to_bytes(delegator) is Ok(_)) {
    return Err("delegation pubkey must be 64 hex characters")
  }
  if !delegation_conditions_allow(ev, conditions) {
    return Err("delegation conditions do not allow this event")
  }
  if verify_sig {
    let token = "nostr:delegation:" + ev.pubkey + ":" + conditions
    let hash = @crypto.sha256(@crypto.utf8_bytes(token))
    if !@crypto.schnorr_verify(delegator, hash, signature) {
      return Err("bad delegation signature")
    }
  }
  Ok(())
}

///|
/// Evaluate a NIP-26 conditions string ("&"-separated) against an event.
/// At least one `kind=<int>` condition must match the event kind, and every
/// `created_at<<int>` / `created_at><int>` bound must hold strictly.
/// Unknown or unparseable conditions are ignored.
fn delegation_conditions_allow(ev : @event.Event, conditions : String) -> Bool {
  let created_at = ev.created_at.reinterpret_as_int64()
  let kind = ev.kind.reinterpret_as_int().to_int64()
  let mut kind_allowed = false
  let mut created_at_valid = true
  for condition in split_on(conditions, '&') {
    match cut_prefix(condition, "kind=") {
      Some(v) => {
        match parse_decimal(v) {
          Some(allowed) => if kind == allowed { kind_allowed = true }
          None => ()
        }
        continue
      }
      None => ()
    }
    match cut_prefix(condition, "created_at<") {
      Some(v) => {
        match parse_decimal(v) {
          Some(max) => if created_at >= max { created_at_valid = false }
          None => ()
        }
        continue
      }
      None => ()
    }
    match cut_prefix(condition, "created_at>") {
      Some(v) =>
        match parse_decimal(v) {
          Some(min) => if created_at <= min { created_at_valid = false }
          None => ()
        }
      None => ()
    }
  }
  kind_allowed && created_at_valid
}

///|
fn split_on(s : String, sep : Char) -> Array[String] {
  let out : Array[String] = []
  let mut sb = StringBuilder::new()
  for c in s {
    if c == sep {
      out.push(sb.to_string())
      sb = StringBuilder::new()
    } else {
      sb.write_char(c)
    }
  }
  out.push(sb.to_string())
  out
}

///|
fn cut_prefix(s : String, prefix : String) -> String? {
  if s.length() < prefix.length() {
    return None
  }
  if s[0:prefix.length()].to_owned() == prefix {
    Some(s[prefix.length():s.length()].to_owned())
  } else {
    None
  }
}

///|
/// Parse an optionally signed decimal integer; None on any other input.
fn parse_decimal(s : String) -> Int64? {
  let mut acc : Int64 = 0
  let mut neg = false
  let mut digits = 0
  let mut first = true
  for c in s {
    if first && c == '-' {
      neg = true
    } else if c >= '0' && c <= '9' {
      acc = acc * 10 + (c.to_int() - 48).to_int64()
      digits = digits + 1
    } else {
      return None
    }
    first = false
  }
  if digits == 0 {
    None
  } else if neg {
    Some(-acc)
  } else {
    Some(acc)
  }
}
