///|
/// BIP-340 Schnorr signatures over secp256k1, implemented with BigInt.
///
/// Field prime p of secp256k1.
let secp_p : BigInt = BigInt::from_string(
  "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f",
  radix=16,
)

///|
/// Group order n of secp256k1.
let secp_n : BigInt = BigInt::from_string(
  "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
  radix=16,
)

///|
let secp_gx : BigInt = BigInt::from_string(
  "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
  radix=16,
)

///|
let secp_gy : BigInt = BigInt::from_string(
  "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8",
  radix=16,
)

///|
/// Reduce modulo the field prime p, always returning a value in [0, p).
fn modp(a : BigInt) -> BigInt {
  let r = a % secp_p
  if r < 0N {
    r + secp_p
  } else {
    r
  }
}

///|
/// Reduce modulo the group order n, always returning a value in [0, n).
fn modn(a : BigInt) -> BigInt {
  let r = a % secp_n
  if r < 0N {
    r + secp_n
  } else {
    r
  }
}

///|
/// Point in Jacobian coordinates; the point at infinity has z == 0.
priv struct Jac {
  x : BigInt
  y : BigInt
  z : BigInt
}

///|
fn jac_infinity() -> Jac {
  { x: 1N, y: 1N, z: 0N }
}

///|
fn jac_double(p : Jac) -> Jac {
  if p.z.is_zero() || p.y.is_zero() {
    return jac_infinity()
  }
  let y2 = modp(p.y * p.y)
  let s = modp(4N * p.x * y2)
  let m = modp(3N * p.x * p.x) // curve parameter a = 0
  let x3 = modp(m * m - 2N * s)
  let y3 = modp(m * (s - x3) - 8N * y2 * y2)
  let z3 = modp(2N * p.y * p.z)
  { x: x3, y: y3, z: z3 }
}

///|
fn jac_add(p : Jac, q : Jac) -> Jac {
  if p.z.is_zero() {
    return q
  }
  if q.z.is_zero() {
    return p
  }
  let z1z1 = modp(p.z * p.z)
  let z2z2 = modp(q.z * q.z)
  let u1 = modp(p.x * z2z2)
  let u2 = modp(q.x * z1z1)
  let s1 = modp(p.y * z2z2 * q.z)
  let s2 = modp(q.y * z1z1 * p.z)
  if u1 == u2 {
    if s1 == s2 {
      return jac_double(p)
    }
    return jac_infinity()
  }
  let h = modp(u2 - u1)
  let r = modp(s2 - s1)
  let h2 = modp(h * h)
  let h3 = modp(h * h2)
  let u1h2 = modp(u1 * h2)
  let x3 = modp(r * r - h3 - 2N * u1h2)
  let y3 = modp(r * (u1h2 - x3) - s1 * h3)
  let z3 = modp(h * p.z * q.z)
  { x: x3, y: y3, z: z3 }
}

///|
/// Scalar multiplication k * (px, py) with (px, py) affine, k >= 0.
fn jac_mul(px : BigInt, py : BigInt, k : BigInt) -> Jac {
  let base : Jac = { x: px, y: py, z: 1N }
  let mut acc = jac_infinity()
  for i = k.bit_length() - 1; i >= 0; i = i - 1 {
    acc = jac_double(acc)
    if !((k >> i) & 1N).is_zero() {
      acc = jac_add(acc, base)
    }
  }
  acc
}

///|
/// Convert a Jacobian point to affine coordinates; None for infinity.
fn jac_to_affine(p : Jac) -> (BigInt, BigInt)? {
  if p.z.is_zero() {
    return None
  }
  let zinv = p.z.pow(secp_p - 2N, modulus=secp_p) // Fermat inverse
  let zinv2 = modp(zinv * zinv)
  Some((modp(p.x * zinv2), modp(p.y * zinv2 * zinv)))
}

///|
fn bytes_to_bigint(b : Array[Int]) -> BigInt {
  let mut acc = 0N
  for x in b {
    acc = (acc << 8) + BigInt::from_int(x & 0xFF)
  }
  acc
}

///|
/// Big-endian 32-byte encoding of a non-negative BigInt < 2^256.
fn bigint_to_bytes32(v : BigInt) -> Array[Int] {
  let out = Array::make(32, 0)
  let mut x = v
  for i = 31; i >= 0; i = i - 1 {
    out[i] = (x & 255N).to_int()
    x = x >> 8
  }
  out
}

///|
/// BIP-340 lift_x: recover the point with even y whose x coordinate is `x`.
/// Returns None if x >= p or x is not on the curve.
fn lift_x(x : BigInt) -> (BigInt, BigInt)? {
  if x < 0N || x >= secp_p {
    return None
  }
  let c = modp(x * x * x + 7N)
  // p == 3 (mod 4), so a square root (if any) is c^((p+1)/4) mod p.
  let y = c.pow((secp_p + 1N) >> 2, modulus=secp_p)
  if modp(y * y) != c {
    return None
  }
  if (y & 1N).to_int() == 1 {
    Some((x, secp_p - y))
  } else {
    Some((x, y))
  }
}

///|
/// Decode a hex string that must represent exactly `n` bytes.
fn hex_to_fixed_bytes(s : String, n : Int) -> Array[Int]? {
  match hex_to_bytes(s) {
    Ok(b) => if b.length() == n { Some(b) } else { None }
    Err(_) => None
  }
}

///|
/// Verify a BIP-340 Schnorr signature.
///
/// `pubkey_hex` is the 32-byte x-only public key in hex, `sig_hex` the
/// 64-byte signature in hex, `msg` the signed message bytes (32 bytes for
/// Nostr). Returns false for any malformed input; never aborts.
pub fn schnorr_verify(
  pubkey_hex : String,
  msg : Array[Int],
  sig_hex : String,
) -> Bool {
  let pk_bytes = match hex_to_fixed_bytes(pubkey_hex, 32) {
    Some(b) => b
    None => return false
  }
  let sig_bytes = match hex_to_fixed_bytes(sig_hex, 64) {
    Some(b) => b
    None => return false
  }
  let (px, py) = match lift_x(bytes_to_bigint(pk_bytes)) {
    Some(pt) => pt
    None => return false
  }
  let r = bytes_to_bigint(sig_bytes[0:32].to_owned())
  let s = bytes_to_bigint(sig_bytes[32:64].to_owned())
  if r >= secp_p || s >= secp_n {
    return false
  }
  let challenge : Array[Int] = []
  challenge.append(bigint_to_bytes32(r))
  challenge.append(pk_bytes)
  challenge.append(msg)
  let e = modn(bytes_to_bigint(tagged_hash("BIP0340/challenge", challenge)))
  // R = s*G - e*P == s*G + (n - e)*P
  let sg = jac_mul(secp_gx, secp_gy, s)
  let ep = jac_mul(px, py, modn(secp_n - e))
  match jac_to_affine(jac_add(sg, ep)) {
    None => false // point at infinity
    Some((rx, ry)) => (ry & 1N).to_int() == 0 && rx == r
  }
}

///|
/// Parse and range-check a 32-byte secret key hex string.
/// Returns the secret scalar d' in [1, n-1].
fn parse_seckey(seckey_hex : String) -> Result[BigInt, String] {
  match hex_to_fixed_bytes(seckey_hex, 32) {
    Some(b) => {
      let d = bytes_to_bigint(b)
      if d.is_zero() || d >= secp_n {
        Err("secret key out of range")
      } else {
        Ok(d)
      }
    }
    None => Err("secret key must be 64 hex characters")
  }
}

///|
/// Derive the x-only public key (32-byte lowercase hex) from a secret key
/// given as 64 hex characters.
pub fn pubkey_from_seckey(seckey_hex : String) -> Result[String, String] {
  match parse_seckey(seckey_hex) {
    Ok(d) =>
      match jac_to_affine(jac_mul(secp_gx, secp_gy, d)) {
        Some((x, _)) => Ok(bytes_to_hex(bigint_to_bytes32(x)))
        None => Err("invalid secret key") // unreachable for d in [1, n-1]
      }
    Err(e) => Err(e)
  }
}

///|
/// Produce a BIP-340 Schnorr signature.
///
/// `seckey_hex` is the 32-byte secret key in hex, `msg` the message bytes,
/// and `aux` exactly 32 bytes of auxiliary randomness. Returns the 64-byte
/// signature as 128 lowercase hex characters.
pub fn schnorr_sign(
  seckey_hex : String,
  msg : Array[Int],
  aux : Array[Int],
) -> Result[String, String] {
  if aux.length() != 32 {
    return Err("aux randomness must be exactly 32 bytes")
  }
  let d0 = match parse_seckey(seckey_hex) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let (px, py) = match jac_to_affine(jac_mul(secp_gx, secp_gy, d0)) {
    Some(pt) => pt
    None => return Err("invalid secret key")
  }
  let d = if (py & 1N).to_int() == 0 { d0 } else { secp_n - d0 }
  let pk_bytes = bigint_to_bytes32(px)
  // t = d XOR tagged_hash("BIP0340/aux", aux)
  let aux_hash = tagged_hash("BIP0340/aux", aux)
  let d_bytes = bigint_to_bytes32(d)
  let t : Array[Int] = []
  for i = 0; i < 32; i = i + 1 {
    t.push(d_bytes[i] ^ aux_hash[i])
  }
  // rand = tagged_hash("BIP0340/nonce", t || pk || msg)
  let nonce_input : Array[Int] = []
  nonce_input.append(t)
  nonce_input.append(pk_bytes)
  nonce_input.append(msg)
  let k0 = modn(bytes_to_bigint(tagged_hash("BIP0340/nonce", nonce_input)))
  if k0.is_zero() {
    return Err("nonce is zero; try different aux randomness")
  }
  let (rx, ry) = match jac_to_affine(jac_mul(secp_gx, secp_gy, k0)) {
    Some(pt) => pt
    None => return Err("nonce point at infinity")
  }
  let k = if (ry & 1N).to_int() == 0 { k0 } else { secp_n - k0 }
  let r_bytes = bigint_to_bytes32(rx)
  // e = tagged_hash("BIP0340/challenge", r || pk || msg) mod n
  let challenge : Array[Int] = []
  challenge.append(r_bytes)
  challenge.append(pk_bytes)
  challenge.append(msg)
  let e = modn(bytes_to_bigint(tagged_hash("BIP0340/challenge", challenge)))
  let s = modn(k + e * d)
  let sig : Array[Int] = []
  sig.append(r_bytes)
  sig.append(bigint_to_bytes32(s))
  let sig_hex = bytes_to_hex(sig)
  if schnorr_verify(bytes_to_hex(pk_bytes), msg, sig_hex) {
    Ok(sig_hex)
  } else {
    Err("generated signature failed self-verification")
  }
}
