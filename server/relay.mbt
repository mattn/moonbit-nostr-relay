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
}

///|
/// A message to deliver to a client connection
pub struct Outgoing {
  client_id : String
  message : String
}

///|
pub fn Relay::new(config : Config, store : &@storage.Storage) -> Relay {
  { config, store, subs: {} }
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
  if @event.is_ephemeral_kind(ev.kind) {
    let out = [{ client_id, message: ok_msg(ev.id, true, "") }]
    out.append(self.broadcast(ev))
    return out
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
  // Merge per-filter query results, deduplicated by id, newest first
  let seen : Map[String, Bool] = {}
  let merged : Array[@event.Event] = []
  for f in filters {
    for ev in self.store.query(f) {
      if !seen.contains(ev.id) {
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
/// Deliver a fresh event to every matching subscription of every client
fn Relay::broadcast(self : Relay, ev : @event.Event) -> Array[Outgoing] {
  let out : Array[Outgoing] = []
  for client_id, client_subs in self.subs {
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
}

///|
pub fn Relay::stats(self : Relay) -> String {
  let mut sub_count = 0
  for _, client_subs in self.subs {
    sub_count = sub_count + client_subs.length()
  }
  "events: \{self.store.count()}, clients: \{self.subs.length()}, subscriptions: \{sub_count}"
}
