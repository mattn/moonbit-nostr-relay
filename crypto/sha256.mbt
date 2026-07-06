///|
/// SHA-256 (FIPS 180-4), pure MoonBit implementation over byte arrays.
let sha256_k : Array[UInt] = [
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U, 0x923f82a4U,
  0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU,
  0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU,
  0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
  0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
  0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
  0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U,
  0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
  0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U, 0x90befffaU, 0xa4506cebU, 0xbef9a3f7U,
  0xc67178f2U,
]

///|
fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

///|
/// Compute the SHA-256 digest of `data` (bytes 0..255), returning 32 bytes.
pub fn sha256(data : Array[Int]) -> Array[Int] {
  // Padding: append 0x80, then zeros, then 64-bit big-endian bit length.
  let msg : Array[Int] = []
  for x in data {
    msg.push(x & 0xFF)
  }
  let bit_len_hi = data.length() >> 29
  let bit_len_lo = data.length() << 3
  msg.push(0x80)
  while msg.length() % 64 != 56 {
    msg.push(0)
  }
  msg.push((bit_len_hi >> 24) & 0xFF)
  msg.push((bit_len_hi >> 16) & 0xFF)
  msg.push((bit_len_hi >> 8) & 0xFF)
  msg.push(bit_len_hi & 0xFF)
  msg.push((bit_len_lo >> 24) & 0xFF)
  msg.push((bit_len_lo >> 16) & 0xFF)
  msg.push((bit_len_lo >> 8) & 0xFF)
  msg.push(bit_len_lo & 0xFF)

  // Initial hash values.
  let mut h0 = 0x6a09e667U
  let mut h1 = 0xbb67ae85U
  let mut h2 = 0x3c6ef372U
  let mut h3 = 0xa54ff53aU
  let mut h4 = 0x510e527fU
  let mut h5 = 0x9b05688cU
  let mut h6 = 0x1f83d9abU
  let mut h7 = 0x5be0cd19U
  let w : Array[UInt] = Array::make(64, 0U)
  for block = 0; block < msg.length(); block = block + 64 {
    for t = 0; t < 16; t = t + 1 {
      let i = block + t * 4
      w[t] = (msg[i].reinterpret_as_uint() << 24) |
        (msg[i + 1].reinterpret_as_uint() << 16) |
        (msg[i + 2].reinterpret_as_uint() << 8) |
        msg[i + 3].reinterpret_as_uint()
    }
    for t = 16; t < 64; t = t + 1 {
      let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
      let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
      w[t] = w[t - 16] + s0 + w[t - 7] + s1
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    for t = 0; t < 64; t = t + 1 {
      let big_s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ (e.lnot() & g)
      let temp1 = h + big_s1 + ch + sha256_k[t] + w[t]
      let big_s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = big_s0 + maj
      h = g
      g = f
      f = e
      e = d + temp1
      d = c
      c = b
      b = a
      a = temp1 + temp2
    }
    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e
    h5 = h5 + f
    h6 = h6 + g
    h7 = h7 + h
  }
  let out : Array[Int] = []
  for word in [h0, h1, h2, h3, h4, h5, h6, h7] {
    out.push(((word >> 24) & 0xFFU).reinterpret_as_int())
    out.push(((word >> 16) & 0xFFU).reinterpret_as_int())
    out.push(((word >> 8) & 0xFFU).reinterpret_as_int())
    out.push((word & 0xFFU).reinterpret_as_int())
  }
  out
}

///|
/// SHA-256 digest of `data` as a lowercase hex string.
pub fn sha256_hex(data : Array[Int]) -> String {
  bytes_to_hex(sha256(data))
}

///|
/// BIP-340 tagged hash: sha256(sha256(utf8(tag)) || sha256(utf8(tag)) || data).
pub fn tagged_hash(tag : String, data : Array[Int]) -> Array[Int] {
  let tag_hash = sha256(utf8_bytes(tag))
  let buf : Array[Int] = []
  buf.append(tag_hash)
  buf.append(tag_hash)
  buf.append(data)
  sha256(buf)
}
