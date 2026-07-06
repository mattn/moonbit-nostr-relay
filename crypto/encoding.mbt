///|
/// UTF-8 encode a MoonBit string into bytes (each value 0..255).
///
/// MoonBit strings are UTF-16 internally; iterating a string yields full
/// Unicode code points, so code points above 0xFFFF (surrogate pairs) are
/// encoded as 4-byte UTF-8 sequences.
pub fn utf8_bytes(s : String) -> Array[Int] {
  let out : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      out.push(cp)
    } else if cp < 0x800 {
      out.push(0xC0 | (cp >> 6))
      out.push(0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      out.push(0xE0 | (cp >> 12))
      out.push(0x80 | ((cp >> 6) & 0x3F))
      out.push(0x80 | (cp & 0x3F))
    } else {
      out.push(0xF0 | (cp >> 18))
      out.push(0x80 | ((cp >> 12) & 0x3F))
      out.push(0x80 | ((cp >> 6) & 0x3F))
      out.push(0x80 | (cp & 0x3F))
    }
  }
  out
}

///|
fn hex_digit_char(v : Int) -> Char {
  if v < 10 {
    (48 + v).unsafe_to_char() // '0'..'9'
  } else {
    (87 + v).unsafe_to_char() // 'a'..'f'
  }
}

///|
/// Encode bytes as a lowercase hex string.
pub fn bytes_to_hex(b : Array[Int]) -> String {
  let sb = StringBuilder::new()
  for x in b {
    sb.write_char(hex_digit_char((x >> 4) & 0xF))
    sb.write_char(hex_digit_char(x & 0xF))
  }
  sb.to_string()
}

///|
/// Value of a single hex digit given its UTF-16 code unit, or -1 if invalid.
fn hex_digit_value(code : Int) -> Int {
  if code >= 48 && code <= 57 {
    code - 48 // '0'..'9'
  } else if code >= 97 && code <= 102 {
    code - 87 // 'a'..'f'
  } else if code >= 65 && code <= 70 {
    code - 55 // 'A'..'F'
  } else {
    -1
  }
}

///|
/// Decode a hex string (upper- or lowercase) into bytes.
///
/// Returns an error for odd-length input or non-hex characters.
pub fn hex_to_bytes(s : String) -> Result[Array[Int], String] {
  let len = s.length()
  if len % 2 != 0 {
    return Err("hex string has odd length")
  }
  let out : Array[Int] = []
  for i = 0; i < len; i = i + 2 {
    let hi = hex_digit_value(s[i].to_int())
    let lo = hex_digit_value(s[i + 1].to_int())
    if hi < 0 || lo < 0 {
      return Err("invalid hex character")
    }
    out.push((hi << 4) | lo)
  }
  Ok(out)
}
