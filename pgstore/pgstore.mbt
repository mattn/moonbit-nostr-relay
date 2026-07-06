///| PostgreSQL storage backend using mattn/postgres (libpq).

///|

///| Implements the @storage.Storage trait so the relay engine is unaware

///| of the backend.

///|

///| NOTE: parameter binding via Connection::execute is currently broken

///| with recent moonc value layouts (params arrive as NULL), so all values

///| are inlined as properly escaped SQL literals and sent via

///| Connection::query. quote_str doubles single quotes and strips NUL;

///| with standard_conforming_strings (PostgreSQL default) that is a

///| complete escape for string literals.

///|
pub struct PgStore {
  conn : @postgres.Connection
}

///|
let schema : Array[String] = [
  (
    #|CREATE TABLE IF NOT EXISTS events (
    #|  id TEXT PRIMARY KEY,
    #|  pubkey TEXT NOT NULL,
    #|  created_at BIGINT NOT NULL,
    #|  kind INTEGER NOT NULL,
    #|  tags JSONB NOT NULL,
    #|  content TEXT NOT NULL,
    #|  sig TEXT NOT NULL,
    #|  d_tag TEXT NOT NULL DEFAULT ''
    #|)
  ),
  "CREATE INDEX IF NOT EXISTS events_pubkey_idx ON events(pubkey)",
  "CREATE INDEX IF NOT EXISTS events_kind_idx ON events(kind)",
  "CREATE INDEX IF NOT EXISTS events_created_at_idx ON events(created_at DESC)",
  "CREATE INDEX IF NOT EXISTS events_replace_idx ON events(pubkey, kind, d_tag)",
  "CREATE INDEX IF NOT EXISTS events_tags_idx ON events USING GIN(tags)",
]

///|
/// Connect and initialize the schema. `conninfo` is a libpq connection
/// string or postgres:// URL.
pub fn PgStore::connect(conninfo : String) -> Result[PgStore, String] {
  match @postgres.connect(conninfo) {
    Ok(conn) => {
      for stmt in schema {
        match conn.query(stmt) {
          Ok(r) => r.free()
          Err(e) => return Err("schema init failed: " + e.to_string())
        }
      }
      Ok({ conn, })
    }
    Err(e) => Err(e.to_string())
  }
}

///|
fn PgStore::run(
  self : PgStore,
  sql : String,
) -> Result[@postgres.QueryResult, String] {
  match self.conn.query(sql) {
    Ok(r) => Ok(r)
    Err(e) => Err(e.to_string())
  }
}

///|
/// SQL string literal as an ASCII-only E'...' string.
///
/// The underlying libpq binding sends MoonBit strings without UTF-8
/// conversion, so any non-ASCII character would arrive corrupted. We
/// therefore emit pure ASCII and let PostgreSQL decode \uXXXX /
/// \UXXXXXXXX escapes itself.
fn quote_str(s : String) -> String {
  let sb = StringBuilder::new()
  sb.write_string("E'")
  for c in s {
    let u = c.to_int()
    match c {
      '\'' => sb.write_string("''")
      '\\' => sb.write_string("\\\\")
      '\u{00}' => ()
      _ =>
        if u >= 0x20 && u < 0x7F {
          sb.write_char(c)
        } else if u < 0x10000 {
          sb.write_string("\\u" + to_hex4(u))
        } else {
          sb.write_string("\\U" + to_hex8(u))
        }
    }
  }
  sb.write_string("'")
  sb.to_string()
}

///|
let hex_chars : Array[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
fn to_hex4(u : Int) -> String {
  let sb = StringBuilder::new()
  for shift = 12; shift >= 0; shift = shift - 4 {
    sb.write_char(hex_chars[(u >> shift) & 0xF])
  }
  sb.to_string()
}

///|
fn to_hex8(u : Int) -> String {
  let sb = StringBuilder::new()
  for shift = 28; shift >= 0; shift = shift - 4 {
    sb.write_char(hex_chars[(u >> shift) & 0xF])
  }
  sb.to_string()
}

///|
/// Repair strings read back through the libpq binding, which maps each
/// UTF-8 byte to one UTF-16 code unit. Reassemble the bytes and decode.
fn fix_utf8(s : String) -> String {
  let bytes : Array[Int] = []
  let mut needs_fix = false
  for c in s {
    let u = c.to_int()
    if u < 0x80 {
      bytes.push(u)
    } else if u <= 0xFF || (u >= 0xFF80 && u <= 0xFFFF) {
      // bytes >= 0x80 arrive sign-extended by the C stub (0xE6 -> 0xFFE6)
      bytes.push(u & 0xFF)
      needs_fix = true
    } else {
      // genuinely non-latin1 text; assume it is already correct
      return s
    }
  }
  if !needs_fix {
    return s
  }
  let sb = StringBuilder::new()
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let b0 = bytes[i]
    let (cp, size) = if b0 < 0x80 {
      (b0, 1)
    } else if (b0 & 0xE0) == 0xC0 && i + 1 < n {
      (((b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F), 2)
    } else if (b0 & 0xF0) == 0xE0 && i + 2 < n {
      (
        ((b0 & 0x0F) << 12) |
        ((bytes[i + 1] & 0x3F) << 6) |
        (bytes[i + 2] & 0x3F),
        3,
      )
    } else if (b0 & 0xF8) == 0xF0 && i + 3 < n {
      (
        ((b0 & 0x07) << 18) |
        ((bytes[i + 1] & 0x3F) << 12) |
        ((bytes[i + 2] & 0x3F) << 6) |
        (bytes[i + 3] & 0x3F),
        4,
      )
    } else {
      (0xFFFD, 1)
    }
    match cp.to_char() {
      Some(ch) => sb.write_char(ch)
      None => sb.write_char('\u{FFFD}')
    }
    i = i + size
  }
  sb.to_string()
}

///|
/// SQL literal for a text[] value
fn text_array(values : Array[String]) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{")
  for i, v in values {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string("\"")
    for c in v {
      match c {
        '"' => sb.write_string("\\\"")
        '\\' => sb.write_string("\\\\")
        '\u{00}' => ()
        _ => sb.write_char(c)
      }
    }
    sb.write_string("\"")
  }
  sb.write_string("}")
  quote_str(sb.to_string()) + "::text[]"
}

///|
fn int_array(values : Array[UInt]) -> String {
  let sb = StringBuilder::new()
  sb.write_string("'{")
  for i, v in values {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(v.to_string())
  }
  sb.write_string("}'::int[]")
  sb.to_string()
}

///|
fn row_to_event(row : Array[String]) -> Result[@event.Event, String] {
  if row.length() < 7 {
    return Err("unexpected row shape")
  }
  let created_at = @strconv.parse_uint64(row[2]) catch {
    _ => return Err("bad created_at in row")
  }
  let kind = @strconv.parse_uint(row[3]) catch {
    _ => return Err("bad kind in row")
  }
  let tags_json = @json.parse(fix_utf8(row[4])) catch {
    _ => return Err("bad tags json in row")
  }
  guard tags_json is Array(items) else { return Err("tags is not an array") }
  let tags : Array[Array[String]] = []
  for item in items {
    guard item is Array(vals) else { return Err("tag is not an array") }
    let tag : Array[String] = []
    for v in vals {
      guard v is String(s) else { return Err("tag item is not a string") }
      tag.push(s)
    }
    tags.push(tag)
  }
  Ok({
    id: row[0],
    pubkey: row[1],
    created_at,
    kind,
    tags,
    content: fix_utf8(row[5]),
    sig: row[6],
  })
}

///|
fn PgStore::insert(
  self : PgStore,
  ev : @event.Event,
  d_tag : String,
) -> Result[Unit, String] {
  let sql = "INSERT INTO events (id, pubkey, created_at, kind, tags, content, sig, d_tag) VALUES (" +
    quote_str(ev.id) +
    ", " +
    quote_str(ev.pubkey) +
    ", " +
    ev.created_at.to_string() +
    ", " +
    ev.kind.to_string() +
    ", " +
    quote_str(ev.tags.to_json().stringify()) +
    "::jsonb, " +
    quote_str(ev.content) +
    ", " +
    quote_str(ev.sig) +
    ", " +
    quote_str(d_tag) +
    ") ON CONFLICT (id) DO NOTHING"
  match self.run(sql) {
    Ok(r) => {
      r.free()
      Ok(())
    }
    Err(e) => Err(e)
  }
}

///|
pub impl @storage.Storage for PgStore with fn add(self, ev) {
  // Exact duplicate?
  match self.run("SELECT 1 FROM events WHERE id = " + quote_str(ev.id)) {
    Ok(r) => {
      let dup = r.rows().length() > 0
      r.free()
      if dup {
        return Duplicate
      }
    }
    Err(e) => return Failed(e)
  }
  let replaceable = @event.is_replaceable_kind(ev.kind)
  let addressable = @event.is_addressable_kind(ev.kind)
  let d_tag = if addressable { ev.d_tag() } else { "" }
  if replaceable || addressable {
    // Keep only the latest event per (pubkey, kind, d_tag)
    let key_cond = "pubkey = " +
      quote_str(ev.pubkey) +
      " AND kind = " +
      ev.kind.to_string() +
      " AND d_tag = " +
      quote_str(d_tag)
    match self.run("SELECT created_at, id FROM events WHERE " + key_cond) {
      Ok(r) => {
        let rows = r.rows()
        let mut stale = false
        for row in rows {
          let existing_created = @strconv.parse_uint64(row[0]) catch { _ => 0 }
          // On equal timestamps NIP-01 keeps the event with the lowest id
          if existing_created > ev.created_at ||
            (existing_created == ev.created_at && row[1] < ev.id) {
            stale = true
          }
        }
        r.free()
        if stale {
          return Stale
        }
        match self.run("DELETE FROM events WHERE " + key_cond) {
          Ok(r) => r.free()
          Err(e) => return Failed(e)
        }
      }
      Err(e) => return Failed(e)
    }
  }
  match self.insert(ev, d_tag) {
    Ok(_) => Added
    Err(e) => Failed(e)
  }
}

///|
pub impl @storage.Storage for PgStore with fn query(self, f) {
  let conds : Array[String] = []
  if f.ids.length() > 0 {
    conds.push("id = ANY(" + text_array(f.ids) + ")")
  }
  if f.authors.length() > 0 {
    conds.push("pubkey = ANY(" + text_array(f.authors) + ")")
  }
  if f.kinds.length() > 0 {
    conds.push("kind = ANY(" + int_array(f.kinds) + ")")
  }
  match f.since {
    Some(since) => conds.push("created_at >= " + since.to_string())
    None => ()
  }
  match f.until {
    Some(until) => conds.push("created_at <= " + until.to_string())
    None => ()
  }
  for tf in f.tags {
    if tf.values.length() == 0 {
      conds.push(
        "EXISTS (SELECT 1 FROM jsonb_array_elements(tags) t WHERE t->>0 = " +
        quote_str(tf.name) +
        ")",
      )
    } else {
      conds.push(
        "EXISTS (SELECT 1 FROM jsonb_array_elements(tags) t WHERE t->>0 = " +
        quote_str(tf.name) +
        " AND t->>1 = ANY(" +
        text_array(tf.values) +
        "))",
      )
    }
  }
  let sb = StringBuilder::new()
  sb.write_string(
    "SELECT id, pubkey, created_at, kind, tags::text, content, sig FROM events",
  )
  for i, cond in conds {
    sb.write_string(if i == 0 { " WHERE " } else { " AND " })
    sb.write_string(cond)
  }
  sb.write_string(" ORDER BY created_at DESC, id ASC")
  match f.limit {
    Some(limit) => {
      let n = if limit < 0 { 0 } else { limit }
      sb.write_string(" LIMIT \{n}")
    }
    None => ()
  }
  let result : Array[@event.Event] = []
  match self.run(sb.to_string()) {
    Ok(r) => {
      for row in r.rows() {
        match row_to_event(row) {
          Ok(ev) => result.push(ev)
          Err(_) => () // skip corrupt rows rather than failing the REQ
        }
      }
      r.free()
    }
    Err(_) => () // treat backend errors as empty result for queries
  }
  result
}

///|
pub impl @storage.Storage for PgStore with fn count(self) {
  match self.run("SELECT count(*) FROM events") {
    Ok(r) => {
      let rows = r.rows()
      let n = if rows.length() > 0 {
        @strconv.parse_int(rows[0][0]) catch {
          _ => 0
        }
      } else {
        0
      }
      r.free()
      n
    }
    Err(_) => 0
  }
}

///|
pub fn PgStore::close(self : PgStore) -> Unit {
  self.conn.close()
}
