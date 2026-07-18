///| NIP-26 delegation tests

///|
let delegatee_seckey : String = "1111111111111111111111111111111111111111111111111111111111111111"

///|
let delegator_seckey : String = "2222222222222222222222222222222222222222222222222222222222222222"

///|
let test_conditions : String = "kind=1&created_at>1&created_at<4102444800"

///|
fn must_pubkey(seckey : String) -> String {
  match @crypto.pubkey_from_seckey(seckey) {
    Ok(pk) => pk
    Err(e) => abort(e)
  }
}

///|
/// Sign the NIP-26 delegation token
/// sha256("nostr:delegation:<delegatee pubkey>:<conditions>") with the
/// delegator's key.
fn delegation_signature(
  delegator_seckey : String,
  delegatee_pubkey : String,
  conditions : String,
) -> String {
  let token = "nostr:delegation:" + delegatee_pubkey + ":" + conditions
  let hash = @crypto.sha256(@crypto.utf8_bytes(token))
  match @crypto.schnorr_sign(delegator_seckey, hash, Array::make(32, 0)) {
    Ok(s) => s
    Err(e) => abort(e)
  }
}

///|
fn delegated_event(
  delegation_tag : Array[String],
  created_at : UInt64,
  kind : UInt,
) -> @event.Event {
  {
    id: fake_id1,
    pubkey: must_pubkey(delegatee_seckey),
    created_at,
    kind,
    tags: [delegation_tag],
    content: "delegated",
    sig: fake_sig,
  }
}

///|
test "delegation signature verification" {
  let delegatee_pk = must_pubkey(delegatee_seckey)
  let delegator_pk = must_pubkey(delegator_seckey)
  let sig = delegation_signature(
    delegator_seckey, delegatee_pk, test_conditions,
  )
  // Valid delegation is accepted
  let valid = delegated_event(
    ["delegation", delegator_pk, test_conditions, sig],
    100,
    1,
  )
  inspect(verify_delegation(valid, true), content="Ok(())")
  // Forged signature is rejected
  let forged_sig = String::make(128, '3')
  let forged = delegated_event(
    ["delegation", delegator_pk, test_conditions, forged_sig],
    100,
    1,
  )
  inspect(
    verify_delegation(forged, true),
    content=(
      #|Err(bad delegation signature)
    ),
  )
  // Signature by a key other than the delegator is rejected
  let wrong_signer = delegation_signature(
    delegatee_seckey, delegatee_pk, test_conditions,
  )
  let wrong = delegated_event(
    ["delegation", delegator_pk, test_conditions, wrong_signer],
    100,
    1,
  )
  inspect(
    verify_delegation(wrong, true),
    content=(
      #|Err(bad delegation signature)
    ),
  )
}

///|
test "delegation conditions" {
  let delegatee_pk = must_pubkey(delegatee_seckey)
  let delegator_pk = must_pubkey(delegator_seckey)
  let sig = delegation_signature(
    delegator_seckey, delegatee_pk, test_conditions,
  )
  let tag = ["delegation", delegator_pk, test_conditions, sig]
  // Kind not listed in the conditions
  inspect(
    verify_delegation(delegated_event(tag, 100, 7), true),
    content=(
      #|Err(delegation conditions do not allow this event)
    ),
  )
  // created_at outside the strict bounds
  inspect(
    verify_delegation(delegated_event(tag, 1, 1), true),
    content=(
      #|Err(delegation conditions do not allow this event)
    ),
  )
  inspect(
    verify_delegation(delegated_event(tag, 4102444800, 1), true),
    content=(
      #|Err(delegation conditions do not allow this event)
    ),
  )
  // Bounds are exclusive: 2 and 4102444799 are inside
  inspect(verify_delegation(delegated_event(tag, 2, 1), true), content="Ok(())")
  inspect(
    verify_delegation(delegated_event(tag, 4102444799, 1), true),
    content="Ok(())",
  )
  // A conditions string without any kind= entry never matches
  let no_kind = "created_at<4102444800"
  let no_kind_sig = delegation_signature(
    delegator_seckey, delegatee_pk, no_kind,
  )
  inspect(
    verify_delegation(
      delegated_event(
        ["delegation", delegator_pk, no_kind, no_kind_sig],
        100,
        1,
      ),
      true,
    ),
    content=(
      #|Err(delegation conditions do not allow this event)
    ),
  )
  // Any one of several kind= entries may match
  let two_kinds = "kind=0&kind=7"
  let two_kinds_sig = delegation_signature(
    delegator_seckey, delegatee_pk, two_kinds,
  )
  inspect(
    verify_delegation(
      delegated_event(
        ["delegation", delegator_pk, two_kinds, two_kinds_sig],
        100,
        7,
      ),
      true,
    ),
    content="Ok(())",
  )
}

///|
test "delegation tag shape" {
  let delegator_pk = must_pubkey(delegator_seckey)
  // No delegation tag: accepted untouched
  let plain : @event.Event = {
    id: fake_id1,
    pubkey: fake_pk,
    created_at: 100,
    kind: 1,
    tags: [["t", "test"]],
    content: "",
    sig: fake_sig,
  }
  inspect(verify_delegation(plain, true), content="Ok(())")
  // A short "delegation" tag is not treated as a delegation
  inspect(
    verify_delegation(
      { ..plain, tags: [["delegation", delegator_pk, "kind=1"]] },
      true,
    ),
    content="Ok(())",
  )
  // More than 4 elements
  inspect(
    verify_delegation(
      { ..plain, tags: [["delegation", delegator_pk, "kind=1", fake_sig, "x"]] },
      true,
    ),
    content=(
      #|Err(delegation tag must have exactly 4 elements)
    ),
  )
  // Empty conditions
  inspect(
    verify_delegation(
      { ..plain, tags: [["delegation", delegator_pk, "", fake_sig]] },
      true,
    ),
    content=(
      #|Err(delegation tag must not have empty elements)
    ),
  )
  // Delegator pubkey must be 64 hex characters
  inspect(
    verify_delegation(
      { ..plain, tags: [["delegation", "xyz", "kind=1", fake_sig]] },
      true,
    ),
    content=(
      #|Err(delegation pubkey must be 64 hex characters)
    ),
  )
}

///|
test "delegated event through the relay" {
  let config : Config = {
    host: "127.0.0.1",
    port: 0,
    max_events: 100,
    verify_sigs: true,
    now: fn() { 1751234567 },
  }
  let relay = Relay::new(config, @storage.new_store(100))
  let delegatee_pk = must_pubkey(delegatee_seckey)
  let delegator_pk = must_pubkey(delegator_seckey)
  let delegation_sig = delegation_signature(
    delegator_seckey, delegatee_pk, test_conditions,
  )
  let aux = Array::make(32, 0)
  let publish = fn(tags : Array[Array[String]]) -> Array[String] {
    let unsigned : @event.Event = {
      id: "",
      pubkey: delegatee_pk,
      created_at: 1751234567,
      kind: 1,
      tags,
      content: "delegated note",
      sig: "",
    }
    let id = @crypto.sha256_hex(@crypto.utf8_bytes(unsigned.serialize_for_id()))
    let id_bytes = match @crypto.hex_to_bytes(id) {
      Ok(b) => b
      Err(e) => abort(e)
    }
    let sig = match @crypto.schnorr_sign(delegatee_seckey, id_bytes, aux) {
      Ok(s) => s
      Err(e) => abort(e)
    }
    let signed : @event.Event = { ..unsigned, id, sig }
    dump(
      relay.handle_message(
        "1",
        "[\"EVENT\"," + signed.to_json().stringify() + "]",
      ),
    )
  }
  // Validly delegated event is accepted
  inspect(
    publish([["delegation", delegator_pk, test_conditions, delegation_sig]]),
    content=(
      #|[1 <- ["OK","c1cd6dcea328d226420ed992d01ee4dfc80a17d90dd1b6439129afc3ba74411a",true,""]]
    ),
  )
  // Forged delegation signature is rejected
  inspect(
    publish([
      ["delegation", delegator_pk, test_conditions, String::make(128, '3')],
    ]),
    content=(
      #|[1 <- ["OK","ec5efc9d090ad7ac53f2685a95d8c4e0fc418122b47b431529cc25028739a5a7",false,"invalid: bad delegation signature"]]
    ),
  )
}
