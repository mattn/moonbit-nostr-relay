///|
fn test_config() -> Config {
  { host: "127.0.0.1", port: 0, max_events: 100, verify_sigs: false }
}

///|
fn dump(out : Array[Outgoing]) -> Array[String] {
  out.map(fn(o) { o.client_id + " <- " + o.message })
}

///|
fn head(s : String, n : Int) -> String {
  if s.length() <= n {
    s
  } else {
    s[0:n].to_owned()
  }
}

///|
fn fake_event_json(
  id : String,
  pubkey : String,
  created_at : UInt64,
  kind : UInt,
  tags_json : String,
  content : String,
) -> String {
  "[\"EVENT\",{\"id\":\"\{id}\",\"pubkey\":\"\{pubkey}\",\"created_at\":\{created_at},\"kind\":\{kind},\"tags\":\{tags_json},\"content\":\"\{content}\",\"sig\":\"\{fake_sig}\"}]"
}

///|
let fake_id1 : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

///|
let fake_id2 : String = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

///|
let fake_pk : String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

///|
let fake_sig : String = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"

///|
test "req then event broadcast" {
  let relay = Relay::new(test_config(), @storage.new_store(100))
  // Subscribe client 1 to kind-1 notes
  let r1 = relay.handle_message("1", "[\"REQ\",\"sub1\",{\"kinds\":[1]}]")
  inspect(
    dump(r1),
    content=(
      #|[1 <- ["EOSE","sub1"]]
    ),
  )
  // Client 2 publishes a kind-1 note: OK to sender, EVENT to subscriber
  let r2 = relay.handle_message(
    "2",
    fake_event_json(fake_id1, fake_pk, 1000, 1, "[]", "hello"),
  )
  inspect(
    dump(r2),
    content=(
      #|[2 <- ["OK","aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",true,""], 1 <- ["EVENT","sub1",{"id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","pubkey":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","created_at":1000,"kind":1,"tags":[],"content":"hello","sig":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}]]
    ),
  )
  // A kind-7 event does not match the subscription: OK only
  let r3 = relay.handle_message(
    "2",
    fake_event_json(fake_id2, fake_pk, 1001, 7, "[]", "+"),
  )
  inspect(
    dump(r3),
    content=(
      #|[2 <- ["OK","cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",true,""]]
    ),
  )
  // Duplicate publish
  let r4 = relay.handle_message(
    "2",
    fake_event_json(fake_id1, fake_pk, 1000, 1, "[]", "hello"),
  )
  inspect(
    dump(r4),
    content=(
      #|[2 <- ["OK","aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",true,"duplicate: already have this event"]]
    ),
  )
  // A new subscriber gets stored history (newest first) then EOSE
  let r5 = relay.handle_message(
    "3",
    "[\"REQ\",\"s\",{\"authors\":[\"\{fake_pk}\"]}]",
  )
  inspect(
    dump(r5).map(fn(s) { head(s, 30) }),
    content=(
      #|[3 <- ["EVENT","s",{"id":"ccccc, 3 <- ["EVENT","s",{"id":"aaaaa, 3 <- ["EOSE","s"]]
    ),
  )
  // CLOSE then publish: subscriber 1 closed sub1, no more broadcast
  let _ = relay.handle_message("1", "[\"CLOSE\",\"sub1\"]")
  let r6 = relay.handle_message(
    "2",
    fake_event_json(
      "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", fake_pk,
      1002, 1, "[]", "again",
    ),
  )
  inspect(
    dump(r6),
    content=(
      #|[2 <- ["OK","eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",true,""], 3 <- ["EVENT","s",{"id":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","pubkey":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","created_at":1002,"kind":1,"tags":[],"content":"again","sig":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}]]
    ),
  )
  inspect(
    relay.stats(),
    content=(
      #|events: 3, clients: 2, subscriptions: 1
    ),
  )
}

///|
test "filters: since until limit tags" {
  let relay = Relay::new(test_config(), @storage.new_store(100))
  for i = 0; i < 5; i = i + 1 {
    let id = "\{i}000000000000000000000000000000000000000000000000000000000000000"
    let tags = if i % 2 == 0 {
      "[[\"t\",\"even\"]]"
    } else {
      "[[\"t\",\"odd\"]]"
    }
    let _ = relay.handle_message(
      "1",
      fake_event_json(id, fake_pk, (1000 + i).to_uint64(), 1, tags, "n\{i}"),
    )
  }
  // since/until window
  let r1 = relay.handle_message(
    "2", "[\"REQ\",\"w\",{\"since\":1001,\"until\":1003}]",
  )
  inspect(
    dump(r1).map(fn(s) { head(s, 28) }),
    content=(
      #|[2 <- ["EVENT","w",{"id":"300, 2 <- ["EVENT","w",{"id":"200, 2 <- ["EVENT","w",{"id":"100, 2 <- ["EOSE","w"]]
    ),
  )
  // limit: newest two only
  let r2 = relay.handle_message("2", "[\"REQ\",\"l\",{\"limit\":2}]")
  inspect(
    dump(r2).map(fn(s) { head(s, 28) }),
    content=(
      #|[2 <- ["EVENT","l",{"id":"400, 2 <- ["EVENT","l",{"id":"300, 2 <- ["EOSE","l"]]
    ),
  )
  // tag filter
  let r3 = relay.handle_message("2", "[\"REQ\",\"t\",{\"#t\":[\"odd\"]}]")
  inspect(
    dump(r3).map(fn(s) { head(s, 28) }),
    content=(
      #|[2 <- ["EVENT","t",{"id":"300, 2 <- ["EVENT","t",{"id":"100, 2 <- ["EOSE","t"]]
    ),
  )
}

///|
test "replaceable and ephemeral kinds" {
  let relay = Relay::new(test_config(), @storage.new_store(100))
  // kind 0 metadata: newer replaces older
  let _ = relay.handle_message(
    "1",
    fake_event_json(fake_id1, fake_pk, 1000, 0, "[]", "old profile"),
  )
  let _ = relay.handle_message(
    "1",
    fake_event_json(fake_id2, fake_pk, 2000, 0, "[]", "new profile"),
  )
  let r1 = relay.handle_message("2", "[\"REQ\",\"m\",{\"kinds\":[0]}]")
  inspect(
    dump(r1).map(fn(s) { head(s, 28) }),
    content=(
      #|[2 <- ["EVENT","m",{"id":"ccc, 2 <- ["EOSE","m"]]
    ),
  )
  // Publishing an older replaceable event is rejected as stale
  let r2 = relay.handle_message(
    "1",
    fake_event_json(
      "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", fake_pk,
      500, 0, "[]", "stale profile",
    ),
  )
  inspect(
    dump(r2),
    content=(
      #|[1 <- ["OK","ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",false,"replaced: have a newer event for this key"]]
    ),
  )
  // Ephemeral kind: broadcast but not stored
  let _ = relay.handle_message("2", "[\"REQ\",\"e\",{\"kinds\":[20001]}]")
  let r3 = relay.handle_message(
    "1",
    fake_event_json(
      "1111111111111111111111111111111111111111111111111111111111111111", fake_pk,
      3000, 20001, "[]", "gone",
    ),
  )
  inspect(
    dump(r3).map(fn(s) { head(s, 20) }),
    content=(
      #|[1 <- ["OK","11111111, 2 <- ["EVENT","e",{"]
    ),
  )
  inspect(
    relay.stats(),
    content=(
      #|events: 1, clients: 1, subscriptions: 2
    ),
  )
}

///|
test "malformed input" {
  let relay = Relay::new(test_config(), @storage.new_store(100))
  inspect(
    dump(relay.handle_message("1", "not json")),
    content=(
      #|[1 <- ["NOTICE","invalid: unable to parse message"]]
    ),
  )
  inspect(
    dump(relay.handle_message("1", "[\"FOO\",1]")),
    content=(
      #|[1 <- ["NOTICE","invalid: unknown message type"]]
    ),
  )
  inspect(
    dump(relay.handle_message("1", "[\"EVENT\",{\"id\":5}]")),
    content=(
      #|[1 <- ["NOTICE","invalid: missing or invalid id"]]
    ),
  )
  inspect(
    dump(relay.handle_message("1", "[\"REQ\",\"s\",{\"kinds\":[\"x\"]}]")),
    content=(
      #|[1 <- ["CLOSED","s","invalid: kinds: expected an array of numbers"]]
    ),
  )
  // Shape validation still applies even with verify_sigs=false
  inspect(
    dump(
      relay.handle_message(
        "1",
        fake_event_json("zzz", fake_pk, 1000, 1, "[]", "x"),
      ),
    ),
    content=(
      #|[1 <- ["OK","zzz",false,"invalid: id must be 64 lowercase hex characters"]]
    ),
  )
}

///|
test "signature verification with real crypto" {
  let config : Config = {
    host: "127.0.0.1",
    port: 0,
    max_events: 100,
    verify_sigs: true,
  }
  let relay = Relay::new(config, @storage.new_store(100))
  // Build and sign a real event with seckey 3 (BIP-340 test key)
  let seckey = "0000000000000000000000000000000000000000000000000000000000000003"
  let pubkey = match @crypto.pubkey_from_seckey(seckey) {
    Ok(pk) => pk
    Err(e) => fail(e)
  }
  let unsigned : @event.Event = {
    id: "",
    pubkey,
    created_at: 1751234567,
    kind: 1,
    tags: [["t", "test"]],
    content: "hello from MoonBit \"relay\"\n",
    sig: "",
  }
  let id = @crypto.sha256_hex(@crypto.utf8_bytes(unsigned.serialize_for_id()))
  let aux : Array[Int] = []
  for i = 0; i < 32; i = i + 1 {
    aux.push(0)
  }
  let id_bytes = match @crypto.hex_to_bytes(id) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let sig = match @crypto.schnorr_sign(seckey, id_bytes, aux) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let signed : @event.Event = { ..unsigned, id, sig }
  let text = "[\"EVENT\"," + signed.to_json().stringify() + "]"
  let r1 = relay.handle_message("1", text)
  inspect(
    dump(r1),
    content=(
      #|[1 <- ["OK","f53047b5bf7fd42b3096c1db2b497bac2c5ad55f00bdc96322c1637b9f6a0d92",true,""]]
    ),
  )
  // Tampered content is rejected (id no longer matches)
  let tampered : @event.Event = { ..signed, content: "tampered" }
  let r2 = relay.handle_message(
    "1",
    "[\"EVENT\"," + tampered.to_json().stringify() + "]",
  )
  inspect(
    dump(r2),
    content=(
      #|[1 <- ["OK","f53047b5bf7fd42b3096c1db2b497bac2c5ad55f00bdc96322c1637b9f6a0d92",false,"invalid: event id does not match content hash"]]
    ),
  )
  // Valid id but signature from the wrong key is rejected
  let wrong_sig = match
    @crypto.schnorr_sign(
      "0000000000000000000000000000000000000000000000000000000000000005", id_bytes,
      aux,
    ) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let forged : @event.Event = { ..signed, sig: wrong_sig }
  let r3 = relay.handle_message(
    "1",
    "[\"EVENT\"," + forged.to_json().stringify() + "]",
  )
  inspect(
    dump(r3),
    content=(
      #|[1 <- ["OK","f53047b5bf7fd42b3096c1db2b497bac2c5ad55f00bdc96322c1637b9f6a0d92",false,"invalid: bad signature"]]
    ),
  )
}
