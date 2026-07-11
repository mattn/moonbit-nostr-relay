///| PostgreSQL storage backend using mattn/postgres (libpq).

///|

///| Schema and query semantics are compatible with

///| github.com/fiatjaf/eventstore/postgresql, so this relay can run on a

///| database created by khatru/eventstore-based relays and vice versa:

///| same `event` table, `tags_to_tagvalues` generated column, indexes,

///| `tagvalues && ARRAY[...]` tag matching and the default query limit

///| of 100.

///|

///| NOTE: parameter binding via Connection::execute is currently broken

///| with recent moonc value layouts (params arrive as NULL), so all values

///| are inlined as ASCII-only E'...' literals and sent via

///| Connection::query; see quote_str/fix_utf8 below.

///|
pub struct PgStore {
  conn : @postgres.Connection
}

///|
/// Matches eventstore/postgresql's default QueryLimit
let query_limit : Int = 100

///|
let schema : Array[String] = [
  (
    #|CREATE OR REPLACE FUNCTION tags_to_tagvalues(jsonb) RETURNS text[]
    #|    AS 'SELECT COALESCE(array_agg((t->>0) || '':'' || (t->>1)), ''{}''::text[]) FROM (SELECT jsonb_array_elements($1) AS t)s WHERE length(t->>0) = 1;'
    #|    LANGUAGE SQL
    #|    IMMUTABLE
    #|    RETURNS NULL ON NULL INPUT
  ),
  (
    #|CREATE TABLE IF NOT EXISTS event (
    #|  id text NOT NULL,
    #|  pubkey text NOT NULL,
    #|  created_at bigint NOT NULL,
    #|  kind integer NOT NULL,
    #|  tags jsonb NOT NULL,
    #|  content text NOT NULL,
    #|  sig text NOT NULL,
    #|
    #|  tagvalues text[] GENERATED ALWAYS AS (tags_to_tagvalues(tags)) STORED
    #|)
  ),
  "CREATE UNIQUE INDEX IF NOT EXISTS ididx ON event USING btree (id text_pattern_ops)",
  "CREATE INDEX IF NOT EXISTS pubkeyprefix ON event USING btree (pubkey text_pattern_ops)",
  "CREATE INDEX IF NOT EXISTS timeidx ON event (created_at DESC)",
  "CREATE INDEX IF NOT EXISTS kindidx ON event (kind)",
  "CREATE INDEX IF NOT EXISTS kindtimeidx ON event(kind,created_at DESC)",
  "CREATE INDEX IF NOT EXISTS arbitrarytagvalues ON event USING gin (tagvalues)",
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
/// UTF-8 byte to one UTF-16 code unit (sign-extended for bytes >= 0x80).
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
/// "a IN ('x','y')" style condition from string values
fn in_list(column : String, values : Array[String]) -> String {
  let sb = StringBuilder::new()
  sb.write_string(column)
  sb.write_string(" IN (")
  for i, v in values {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(quote_str(v))
  }
  sb.write_string(")")
  sb.to_string()
}

///|
/// tagvalues && ARRAY['name:v1','name:v2'] — the eventstore tag condition
fn tag_condition(name : String, values : Array[String]) -> String {
  let sb = StringBuilder::new()
  sb.write_string("tagvalues && ARRAY[")
  for i, v in values {
    if i > 0 {
      sb.write_string(",")
    }
    sb.write_string(quote_str(name + ":" + v))
  }
  sb.write_string("]")
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
/// Value of the first "d" tag in a jsonb `tags` column text, or "" if
/// absent. Mirrors @event.Event::d_tag so addressable-event replacement in
/// this backend keys on the same address as the in-memory store.
fn first_d_tag(tags_text : String) -> String {
  let j = @json.parse(fix_utf8(tags_text)) catch { _ => return "" }
  guard j is Array(items) else { return "" }
  for item in items {
    guard item is Array(vals) else { continue }
    guard vals.length() >= 2 else { continue }
    guard vals[0] is String(name) else { continue }
    guard vals[1] is String(v) else { continue }
    if name == "d" {
      return v
    }
  }
  ""
}

///|
/// INSERT ... ON CONFLICT (id) DO NOTHING; false means duplicate
fn PgStore::insert(self : PgStore, ev : @event.Event) -> Result[Bool, String] {
  let sql = "INSERT INTO event (id, pubkey, created_at, kind, tags, content, sig) VALUES (" +
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
    ") ON CONFLICT (id) DO NOTHING"
  match self.run(sql) {
    Ok(r) => {
      let stored = r.affected_rows() > 0
      r.free()
      Ok(stored)
    }
    Err(e) => Err(e)
  }
}

///|
pub impl @storage.Storage for PgStore with fn add(self, ev) {
  let replaceable = @event.is_replaceable_kind(ev.kind)
  let addressable = @event.is_addressable_kind(ev.kind)
  if replaceable || addressable {
    // Fetch the current events for this (pubkey, kind); for addressable
    // kinds the address also includes the first "d" tag, so we compare it
    // in code (the tagvalues column can't distinguish the first d tag from
    // later ones and never carries an entry for a missing d tag).
    let cond = "pubkey = " +
      quote_str(ev.pubkey) +
      " AND kind = " +
      ev.kind.to_string()
    match
      self.run(
        "SELECT id, created_at, tags::text FROM event WHERE " +
        cond +
        " ORDER BY created_at DESC, id",
      ) {
      Ok(r) => {
        let rows = r.rows()
        let mut stale = false
        let older_ids : Array[String] = []
        let d = ev.d_tag()
        for row in rows {
          if addressable && first_d_tag(row[2]) != d {
            continue
          }
          if row[0] == ev.id {
            r.free()
            return Duplicate
          }
          let existing_created = @strconv.parse_uint64(row[1]) catch { _ => 0 }
          // On equal timestamps NIP-01 keeps the event with the lowest id
          if existing_created > ev.created_at ||
            (existing_created == ev.created_at && row[0] < ev.id) {
            stale = true
          } else {
            older_ids.push(row[0])
          }
        }
        r.free()
        if stale {
          return Stale
        }
        // Store the new event before pruning the older ones, so a failed
        // insert (e.g. a created_at past the column range) can never leave
        // the key with its previous event deleted and nothing in its place.
        match self.insert(ev) {
          Ok(true) => ()
          Ok(false) => return Duplicate
          Err(e) => return Failed(e)
        }
        if older_ids.length() > 0 {
          match
            self.run("DELETE FROM event WHERE " + in_list("id", older_ids)) {
            Ok(r) => r.free()
            Err(e) => return Failed(e)
          }
        }
        return Added
      }
      Err(e) => return Failed(e)
    }
  }
  match self.insert(ev) {
    Ok(true) => Added
    Ok(false) => Duplicate
    Err(e) => Failed(e)
  }
}

///|
pub impl @storage.Storage for PgStore with fn query(self, f) {
  let conds : Array[String] = []
  if f.ids.length() > 0 {
    conds.push(in_list("id", f.ids))
  }
  if f.authors.length() > 0 {
    conds.push(in_list("pubkey", f.authors))
  }
  if f.kinds.length() > 0 {
    let sb = StringBuilder::new()
    sb.write_string("kind IN (")
    for i, k in f.kinds {
      if i > 0 {
        sb.write_string(",")
      }
      sb.write_string(k.to_string())
    }
    sb.write_string(")")
    conds.push(sb.to_string())
  }
  for tf in f.tags {
    if tf.values.length() == 0 {
      // eventstore rejects empty tag sets; match nothing
      conds.push("false")
    } else {
      conds.push(tag_condition(tf.name, tf.values))
    }
  }
  match f.since {
    Some(since) => conds.push("created_at >= " + since.to_string())
    None => ()
  }
  match f.until {
    Some(until) => conds.push("created_at <= " + until.to_string())
    None => ()
  }
  if conds.length() == 0 {
    conds.push("true")
  }
  // eventstore caps every query at QueryLimit (default 100); a limit of 0
  // is a valid NIP-01 request for no stored events, not an unset value.
  let limit = match f.limit {
    Some(l) => if l < 0 || l > query_limit { query_limit } else { l }
    None => query_limit
  }
  let sb = StringBuilder::new()
  sb.write_string(
    "SELECT id, pubkey, created_at, kind, tags::text, content, sig FROM event WHERE ",
  )
  for i, cond in conds {
    if i > 0 {
      sb.write_string(" AND ")
    }
    sb.write_string(cond)
  }
  sb.write_string(" ORDER BY created_at DESC, id LIMIT \{limit}")
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
  match self.run("SELECT count(*) FROM event") {
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
