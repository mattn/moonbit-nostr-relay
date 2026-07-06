///|
test "sha256 empty input" {
  inspect(
    @crypto.sha256_hex([]),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 abc" {
  inspect(
    @crypto.sha256_hex(@crypto.utf8_bytes("abc")),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 multi-block input" {
  // 56 bytes -> padding spills into a second block
  inspect(
    @crypto.sha256_hex(
      @crypto.utf8_bytes(
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
      ),
    ),
    content="248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "sha256 exactly 64 bytes" {
  let data : Array[Int] = []
  for i = 0; i < 64; i = i + 1 {
    data.push(i)
  }
  inspect(
    @crypto.sha256_hex(data),
    content="fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108",
  )
}

///|
test "hex roundtrip and errors" {
  inspect(@crypto.bytes_to_hex([0, 1, 171, 255]), content="0001abff")
  inspect(@crypto.hex_to_bytes("0001ABff"), content="Ok([0, 1, 171, 255])")
  inspect(
    @crypto.hex_to_bytes("abc"),
    content=(
      #|Err(hex string has odd length)
    ),
  )
  inspect(
    @crypto.hex_to_bytes("zz"),
    content=(
      #|Err(invalid hex character)
    ),
  )
}

///|
test "utf8_bytes ascii, accented, emoji" {
  inspect(
    @crypto.utf8_bytes("héllo"),
    content="[104, 195, 169, 108, 108, 111]",
  )
  // U+1F600 GRINNING FACE -> f0 9f 98 80
  inspect(@crypto.utf8_bytes("a\u{1F600}"), content="[97, 240, 159, 152, 128]")
}

///|
test "tagged_hash structure" {
  // tagged_hash(tag, data) == sha256(th || th || data) where th = sha256(utf8(tag))
  let th = @crypto.sha256(@crypto.utf8_bytes("BIP0340/challenge"))
  let data = @crypto.utf8_bytes("hello")
  let manual : Array[Int] = []
  manual.append(th)
  manual.append(th)
  manual.append(data)
  assert_eq(
    @crypto.tagged_hash("BIP0340/challenge", data),
    @crypto.sha256(manual),
  )
}

///|
test "pubkey_from_seckey known vectors" {
  inspect(
    @crypto.pubkey_from_seckey(
      "0000000000000000000000000000000000000000000000000000000000000001",
    ),
    content=(
      #|Ok(79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)
    ),
  )
  // BIP-340 test vector 0 key
  inspect(
    @crypto.pubkey_from_seckey(
      "0000000000000000000000000000000000000000000000000000000000000003",
    ),
    content=(
      #|Ok(f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9)
    ),
  )
}

///|
test "pubkey_from_seckey rejects bad keys" {
  inspect(
    @crypto.pubkey_from_seckey(
      "0000000000000000000000000000000000000000000000000000000000000000",
    ),
    content=(
      #|Err(secret key out of range)
    ),
  )
  // wrong length (not 64 hex chars)
  inspect(
    @crypto.pubkey_from_seckey(
      "fffffffffffffffffffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
    ),
    content=(
      #|Err(secret key must be 64 hex characters)
    ),
  )
  // the group order n itself (64 hex chars) is out of range
  inspect(
    @crypto.pubkey_from_seckey(
      "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
    ),
    content=(
      #|Err(secret key out of range)
    ),
  )
}

///|
test "bip340 test vector 0" {
  // BIP-340 reference test vector index 0
  let seckey = "0000000000000000000000000000000000000000000000000000000000000003"
  let pubkey = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
  let aux = match
    @crypto.hex_to_bytes(
      "0000000000000000000000000000000000000000000000000000000000000000",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let msg = match
    @crypto.hex_to_bytes(
      "0000000000000000000000000000000000000000000000000000000000000000",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let expected_sig = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
  match @crypto.schnorr_sign(seckey, msg, aux) {
    Ok(sig) => assert_eq(sig, expected_sig)
    Err(e) => fail(e)
  }
  assert_true(@crypto.schnorr_verify(pubkey, msg, expected_sig))
}

///|
test "sign verify roundtrip" {
  let seckey = "c90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b14e5c9"
  let msg = match
    @crypto.hex_to_bytes(
      "243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let aux = match
    @crypto.hex_to_bytes(
      "0000000000000000000000000000000000000000000000000000000000000001",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let pubkey = match @crypto.pubkey_from_seckey(seckey) {
    Ok(pk) => pk
    Err(e) => fail(e)
  }
  let sig = match @crypto.schnorr_sign(seckey, msg, aux) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  assert_true(@crypto.schnorr_verify(pubkey, msg, sig))

  // second key / aux pair
  let seckey2 = "0000000000000000000000000000000000000000000000000000000000000042"
  let aux2 = match
    @crypto.hex_to_bytes(
      "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let pubkey2 = match @crypto.pubkey_from_seckey(seckey2) {
    Ok(pk) => pk
    Err(e) => fail(e)
  }
  let sig2 = match @crypto.schnorr_sign(seckey2, msg, aux2) {
    Ok(s) => s
    Err(e) => fail(e)
  }
  assert_true(@crypto.schnorr_verify(pubkey2, msg, sig2))
  // signatures from different keys are not interchangeable
  assert_false(@crypto.schnorr_verify(pubkey, msg, sig2))
}

///|
test "tampered signature, message and pubkey are rejected" {
  let seckey = "c90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b14e5c9"
  let msg = match
    @crypto.hex_to_bytes(
      "243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c89",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let aux = match
    @crypto.hex_to_bytes(
      "0000000000000000000000000000000000000000000000000000000000000001",
    ) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  let pubkey = match @crypto.pubkey_from_seckey(seckey) {
    Ok(pk) => pk
    Err(e) => fail(e)
  }
  let sig = match @crypto.schnorr_sign(seckey, msg, aux) {
    Ok(s) => s
    Err(e) => fail(e)
  }

  // flip one byte of the signature
  let sig_bytes = match @crypto.hex_to_bytes(sig) {
    Ok(b) => b
    Err(e) => fail(e)
  }
  sig_bytes[10] = sig_bytes[10] ^ 0xFF
  assert_false(
    @crypto.schnorr_verify(pubkey, msg, @crypto.bytes_to_hex(sig_bytes)),
  )

  // flip one byte of the message
  let msg2 = msg.copy()
  msg2[0] = msg2[0] ^ 0x01
  assert_false(@crypto.schnorr_verify(pubkey, msg2, sig))

  // wrong pubkey (valid point, wrong key)
  let other_pubkey = match
    @crypto.pubkey_from_seckey(
      "0000000000000000000000000000000000000000000000000000000000000005",
    ) {
    Ok(pk) => pk
    Err(e) => fail(e)
  }
  assert_false(@crypto.schnorr_verify(other_pubkey, msg, sig))
}

///|
test "verify rejects malformed inputs without crashing" {
  let msg : Array[Int] = Array::make(32, 0)
  let sig = String::make(128, '0')
  // BIP-340 vector: public key not on the curve
  assert_false(
    @crypto.schnorr_verify(
      "eefdea4cdb677750a420fee807eacf21eb9898ae79b9768766e4faa04a2d4a34", msg, "6cff5c3ba86c69ea4b7376f31a9bcb4f74c1976089b2d9963da2e5543e17776969e89b4c5564d00349106b8497785dd7d1d713a8ae82b32fa79d5f7fc407d39b",
    ),
  )
  // x >= p
  assert_false(
    @crypto.schnorr_verify(
      "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc30", msg, sig,
    ),
  )
  // not hex / wrong length
  assert_false(@crypto.schnorr_verify("zz", msg, sig))
  assert_false(@crypto.schnorr_verify("abcd", msg, sig))
  let pubkey = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
  assert_false(@crypto.schnorr_verify(pubkey, msg, "abcd"))
  assert_false(@crypto.schnorr_verify(pubkey, msg, "zz"))
}
