///| Relay engine: transport-agnostic Nostr message handling.

///|

///| The transport layer (WebSocket glue) feeds incoming text frames to

///| `Relay::handle_message` and delivers each returned `Outgoing` to the

///| named client connection.

///|
pub struct Relay {
  config : Config
  store : &@storage.Storage
  // client id -> subscription id -> filters
  subs : Map[String, Map[String, Array[@filter.Filter]]]
  auth : Map[String, ConnectionAuth]
}

///|
struct ConnectionAuth {
  challenge : String
  relay_url : String
  pubkeys : Map[String, Bool]
}

///|
/// A message to deliver to a client connection
pub struct Outgoing {
  client_id : String
  message : String
}

///|
pub fn Relay::new(config : Config, store : &@storage.Storage) -> Relay {
  { config, store, subs: {}, auth: {} }
}

///|
/// Register a connection and its NIP-42 challenge.
pub fn Relay::client_connected(
  self : Relay,
  client_id : String,
  challenge : String,
  relay_url : String,
) -> Unit {
  self.auth.set(client_id, { challenge, relay_url, pubkeys: {} })
}

///|
/// Handle one incoming message from a client. Returns the messages to
/// send out (to the sender and, for EVENT broadcasts, to subscribers).
pub fn Relay::handle_message(
  self : Relay,
  client_id : String,
  text : String,
) -> Array[Outgoing] {
  let j = @json.parse(text) catch {
    _ =>
      return [
        { client_id, message: notice("invalid: unable to parse message") },
      ]
  }
  match j {
    [String("EVENT"), ev_json] => self.handle_event(client_id, ev_json)
    [String("AUTH"), ev_json] => self.handle_auth(client_id, ev_json)
    [String("REQ"), String(sub_id), .. filters_json] => {
      let filters : Array[@filter.Filter] = []
      for fj in filters_json {
        match @filter.Filter::from_json(fj) {
          Ok(f) => filters.push(f)
          Err(e) =>
            return [{ client_id, message: closed(sub_id, "invalid: " + e) }]
        }
      }
      if filters.length() == 0 {
        filters.push(@filter.new())
      }
      self.handle_req(client_id, sub_id, filters)
    }
    [String("COUNT"), String(query_id), .. filters_json] => {
      if filters_json.length() == 0 {
        return [
          { client_id, message: closed(query_id, "invalid: missing filter") },
        ]
      }
      let filters : Array[@filter.Filter] = []
      for fj in filters_json {
        match @filter.Filter::from_json(fj) {
          Ok(f) => filters.push(f)
          Err(e) =>
            return [{ client_id, message: closed(query_id, "invalid: " + e) }]
        }
      }
      [
        {
          client_id,
          message: count_msg(query_id, self.count_visible(client_id, filters)),
        },
      ]
    }
    [String("CLOSE"), String(sub_id)] => {
      match self.subs.get(client_id) {
        Some(client_subs) => client_subs.remove(sub_id)
        None => ()
      }
      []
    }
    _ => [{ client_id, message: notice("invalid: unknown message type") }]
  }
}

///|
fn Relay::visible_to(
  self : Relay,
  client_id : String,
  ev : @event.Event,
) -> Bool {
  if ev.kind != 1059 {
    return true
  }
  match self.auth.get(client_id) {
    None => false
    Some(auth) =>
      ev.tags.any(fn(tag) {
        tag.length() >= 2 && tag[0] == "p" && auth.pubkeys.contains(tag[1])
      })
  }
}

///|
fn Relay::count_visible(
  self : Relay,
  client_id : String,
  filters : Array[@filter.Filter],
) -> Int {
  let seen : Map[String, Bool] = {}
  let now = (self.config.now)()
  for f in filters {
    for ev in self.store.query(f) {
      if !ev.is_expired(now) && self.visible_to(client_id, ev) {
        seen.set(ev.id, true)
      }
    }
  }
  seen.length()
}

///|
fn Relay::handle_auth(
  self : Relay,
  client_id : String,
  ev_json : Json,
) -> Array[Outgoing] {
  let ev = match @event.Event::from_json(ev_json) {
    Ok(ev) => ev
    Err(e) => return [{ client_id, message: notice("invalid: " + e) }]
  }
  let reject = fn(reason : String) {
    [{ client_id, message: ok_msg(ev.id, false, "invalid: " + reason) }]
  }
  guard self.auth.get(client_id) is Some(auth) else {
    return reject("connection has no authentication challenge")
  }
  if ev.kind != 22242 {
    return reject("authentication event must be kind 22242")
  }
  let now = (self.config.now)()
  if ev.created_at > now + 600 || ev.created_at + 600 < now {
    return reject("authentication event timestamp is out of range")
  }
  if !ev.tags.any(fn(tag) {
      tag.length() >= 2 && tag[0] == "challenge" && tag[1] == auth.challenge
    }) {
    return reject("authentication challenge does not match")
  }
  if !ev.tags.any(fn(tag) {
      tag.length() >= 2 &&
      tag[0] == "relay" &&
      (
        tag[1] == auth.relay_url ||
        tag[1] == auth.relay_url + "/" ||
        tag[1] + "/" == auth.relay_url
      )
    }) {
    return reject("authentication relay does not match")
  }
  match verify_event(ev, self.config.verify_sigs) {
    Err(reason) => return reject("authentication " + reason)
    Ok(_) => ()
  }
  auth.pubkeys.set(ev.pubkey, true)
  [{ client_id, message: ok_msg(ev.id, true, "") }]
}

///|
fn Relay::handle_event(
  self : Relay,
  client_id : String,
  ev_json : Json,
) -> Array[Outgoing] {
  let ev = match @event.Event::from_json(ev_json) {
    Ok(ev) => ev
    Err(e) => return [{ client_id, message: notice("invalid: " + e) }]
  }
  match verify_event(ev, self.config.verify_sigs) {
    Err(reason) =>
      return [
        { client_id, message: ok_msg(ev.id, false, "invalid: " + reason) },
      ]
    Ok(_) => ()
  }
  // NIP-22: reject events whose created_at is outside the accepted window
  if !created_at_in_limits(ev.created_at, (self.config.now)()) {
    return [
      {
        client_id,
        message: ok_msg(
          ev.id,
          false,
          "invalid: created_at is out of the acceptable range",
        ),
      },
    ]
  }
  // NIP-70: protected events may only be published by their authenticated author.
  let authenticated_author = match self.auth.get(client_id) {
    Some(auth) => auth.pubkeys.contains(ev.pubkey)
    None => false
  }
  if is_protected(ev) && !authenticated_author {
    return [
      {
        client_id,
        message: ok_msg(ev.id, false, "auth-required: need to authenticate"),
      },
    ]
  }
  if @event.is_ephemeral_kind(ev.kind) {
    let out = [{ client_id, message: ok_msg(ev.id, true, "") }]
    out.append(self.broadcast(ev))
    return out
  }
  // NIP-09: apply the deletions first, then store and broadcast the
  // kind-5 event itself like any other event so clients can see it.
  if ev.kind == @event.kind_event_deletion {
    match self.apply_deletion(ev) {
      Err(reason) =>
        return [{ client_id, message: ok_msg(ev.id, false, reason) }]
      Ok(_) => ()
    }
  }
  match self.store.add(ev) {
    Added => {
      let out = [{ client_id, message: ok_msg(ev.id, true, "") }]
      out.append(self.broadcast(ev))
      out
    }
    Duplicate =>
      [
        {
          client_id,
          message: ok_msg(ev.id, true, "duplicate: already have this event"),
        },
      ]
    Stale =>
      [
        {
          client_id,
          message: ok_msg(
            ev.id,
            false,
            "replaced: have a newer event for this key",
          ),
        },
      ]
    Failed(msg) =>
      [{ client_id, message: ok_msg(ev.id, false, "error: " + msg) }]
  }
}

///|
/// NIP-09: delete every event referenced by an "e" tag of a kind-5
/// deletion event. Only events authored by the deletion's own pubkey may
/// be deleted; a reference to another user's event is rejected, and a
/// reference to an unknown id is skipped.
fn Relay::apply_deletion(
  self : Relay,
  ev : @event.Event,
) -> Result[Unit, String] {
  for tag in ev.tags {
    if tag.length() >= 2 && tag[0] == "e" {
      match self.store.delete(tag[1], ev.pubkey) {
        Deleted | NotFound => ()
        NotAuthor =>
          match self.store.delete_gift_wrap(tag[1], ev.pubkey) {
            Deleted | NotFound => ()
            NotAuthor => return Err("insufficient permissions")
            DeleteFailed(msg) => return Err("error: " + msg)
          }
        DeleteFailed(msg) => return Err("error: " + msg)
      }
    }
  }
  Ok(())
}

///|
fn Relay::handle_req(
  self : Relay,
  client_id : String,
  sub_id : String,
  filters : Array[@filter.Filter],
) -> Array[Outgoing] {
  let client_subs = match self.subs.get(client_id) {
    Some(m) => m
    None => {
      let m : Map[String, Array[@filter.Filter]] = {}
      self.subs.set(client_id, m)
      m
    }
  }
  client_subs.set(sub_id, filters)
  // Merge per-filter query results, deduplicated by id, newest first.
  // NIP-40: expired events stay stored but are never served.
  let now = (self.config.now)()
  let seen : Map[String, Bool] = {}
  let merged : Array[@event.Event] = []
  for f in filters {
    for ev in self.store.query(f) {
      if ev.is_expired(now) {
        continue
      }
      if self.visible_to(client_id, ev) && !seen.contains(ev.id) {
        seen.set(ev.id, true)
        merged.push(ev)
      }
    }
  }
  merged.sort_by(fn(a, b) {
    if a.created_at > b.created_at {
      -1
    } else if a.created_at < b.created_at {
      1
    } else if a.id < b.id {
      -1
    } else if a.id > b.id {
      1
    } else {
      0
    }
  })
  let out : Array[Outgoing] = []
  for ev in merged {
    out.push({ client_id, message: event_msg(sub_id, ev) })
  }
  out.push({ client_id, message: eose(sub_id) })
  out
}

///|
/// Deliver a fresh event to every matching subscription of every client.
/// NIP-40: an already-expired event is accepted but never delivered.
fn Relay::broadcast(self : Relay, ev : @event.Event) -> Array[Outgoing] {
  let out : Array[Outgoing] = []
  if ev.is_expired((self.config.now)()) {
    return out
  }
  for client_id, client_subs in self.subs {
    if !self.visible_to(client_id, ev) {
      continue
    }
    for sub_id, filters in client_subs {
      let mut matched = false
      for f in filters {
        if f.matches(ev) {
          matched = true
          break
        }
      }
      if matched {
        out.push({ client_id, message: event_msg(sub_id, ev) })
      }
    }
  }
  out
}

///|
/// Drop all state for a disconnected client
pub fn Relay::client_disconnected(self : Relay, client_id : String) -> Unit {
  self.subs.remove(client_id)
  self.auth.remove(client_id)
}

///|
pub fn Relay::stats(self : Relay) -> String {
  let mut sub_count = 0
  for _, client_subs in self.subs {
    sub_count = sub_count + client_subs.length()
  }
  "events: \{self.store.count()}, clients: \{self.subs.length()}, subscriptions: \{sub_count}"
}
