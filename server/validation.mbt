///| Event validation

///|
/// Validate an incoming event: structural shape always; event id hash and
/// BIP-340 Schnorr signature when `verify_sigs` is enabled.
pub fn verify_event(
  ev : @event.Event,
  verify_sigs : Bool,
) -> Result[Unit, String] {
  match ev.validate() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if verify_sigs {
    verify_crypto(ev)
  } else {
    Ok(())
  }
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
