///| Native (libpq + moonbitlang/async) entry point.

///|

///| Storage backend is selected at startup:

///|   DATABASE_URL set   -> PostgreSQL via mattn/postgres

///|   DATABASE_URL unset -> in-memory store

///| PORT / HOST override the listen address (defaults 8080 / 0.0.0.0).

///|
async fn main {
  let host = @env.get_env_var("HOST").unwrap_or("0.0.0.0")
  let port = match @env.get_env_var("PORT") {
    Some(p) =>
      @strconv.parse_int(p) catch {
        _ => {
          println("invalid PORT: \{p}")
          return
        }
      }
    None => 8080
  }
  let config : @server.Config = {
    host,
    port,
    max_events: 100000,
    verify_sigs: true,
    now: @server.unix_now,
  }
  let store : &@storage.Storage = match @env.get_env_var("DATABASE_URL") {
    Some(url) =>
      match @pgstore.PgStore::connect(url) {
        Ok(pg) => {
          println("storage: PostgreSQL")
          pg as &@storage.Storage
        }
        Err(e) => {
          println("failed to connect to PostgreSQL: \{e}")
          return
        }
      }
    None => {
      println("storage: in-memory (set DATABASE_URL to use PostgreSQL)")
      @storage.new_store(config.max_events) as &@storage.Storage
    }
  }
  let web_root = @env.get_env_var("WEB_ROOT").unwrap_or("public")
  let nip11 = @server.nip11_doc(
    name?=@env.get_env_var("RELAY_NAME"),
    description?=@env.get_env_var("RELAY_DESCRIPTION"),
    pubkey?=@env.get_env_var("RELAY_PUBKEY"),
    contact?=@env.get_env_var("RELAY_CONTACT"),
    icon?=@env.get_env_var("RELAY_ICON"),
  )
  let relay = @server.Relay::new(config, store)
  // client id -> outgoing message queue, drained by a per-client writer task
  let outboxes : Map[String, @aqueue.Queue[String]] = {}
  let mut next_id = 0
  let server = @http.Server(
    @socket.Addr::parse("\{config.host}:\{config.port}"),
    reuse_addr=true,
  )
  println("listening on ws://\{config.host}:\{config.port}")
  server.run_forever(allow_failure=true, (request, _body, conn) => {
    let upgrade = request.headers.get("upgrade").unwrap_or("").to_lower()
    if upgrade != "websocket" {
      let accept = request.headers.get("accept").unwrap_or("")
      if accept.contains("application/nostr+json") {
        let headers : Map[String, String] = {
          "Content-Type": "application/nostr+json",
          "Access-Control-Allow-Origin": "*",
        }
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write_string(nip11)
        conn.end_response()
      } else {
        serve_static(conn, request.path, web_root)
      }
      return
    }
    let ws = @websocket.from_http_server(request, conn)
    next_id = next_id + 1
    let client_id = next_id.to_string()
    let outbox : @aqueue.Queue[String] = @aqueue.Queue(kind=Unbounded)
    outboxes.set(client_id, outbox)
    defer {
      outboxes.remove(client_id)
      relay.client_disconnected(client_id)
      ws.close()
    }
    @async.with_task_group(g => {
      g.spawn_bg(no_wait=true, () => {
        for ;; {
          let msg = outbox.get()
          ws.send_text(msg)
        }
      })
      for ;; {
        let msg = ws.recv()
        match msg.kind {
          Text => {
            let text = msg.read_all().text()
            for o in relay.handle_message(client_id, text) {
              match outboxes.get(o.client_id) {
                Some(q) => q.put(o.message)
                None => ()
              }
            }
          }
          Binary => {
            let _ = msg.read_all()
          }
        }
      }
    }) catch {
      @websocket.WebSocketError::ConnectionClosed(_, _) => ()
      _ => ()
    }
  })
}

///|
fn strip_query(p : String) -> String {
  let sb = StringBuilder::new()
  for c in p {
    if c == '?' || c == '#' {
      break
    }
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn content_type(path : String) -> String {
  if path.has_suffix(".html") || path.has_suffix(".htm") {
    "text/html; charset=utf-8"
  } else if path.has_suffix(".js") || path.has_suffix(".mjs") {
    "text/javascript; charset=utf-8"
  } else if path.has_suffix(".css") {
    "text/css; charset=utf-8"
  } else if path.has_suffix(".json") {
    "application/json"
  } else if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
    "image/jpeg"
  } else if path.has_suffix(".gif") {
    "image/gif"
  } else if path.has_suffix(".svg") {
    "image/svg+xml"
  } else if path.has_suffix(".ico") {
    "image/x-icon"
  } else if path.has_suffix(".webp") {
    "image/webp"
  } else if path.has_suffix(".woff2") {
    "font/woff2"
  } else if path.has_suffix(".txt") {
    "text/plain; charset=utf-8"
  } else {
    "application/octet-stream"
  }
}

///|
/// Serve a file from web_root ("/" maps to index.html). Falls back to a
/// plain-text banner for "/" when no site is installed, 404 otherwise.
async fn serve_static(
  conn : @http.ServerConnection,
  raw_path : String,
  web_root : String,
) -> Unit {
  let mut path = strip_query(raw_path)
  if path == "" || path == "/" {
    path = "/index.html"
  }
  if path.contains("..") || path.contains("\\") {
    conn.send_response(404, "Not Found")
    conn.write_string("not found\n")
    conn.end_response()
    return
  }
  let data = @fs.read_file(web_root + path) catch {
    _ => {
      if path == "/index.html" {
        conn.send_response(200, "OK")
        conn.write_string("This is a Nostr relay. Connect via WebSocket.\n")
      } else {
        conn.send_response(404, "Not Found")
        conn.write_string("not found\n")
      }
      conn.end_response()
      return
    }
  }
  let headers : Map[String, String] = {
    "Content-Type": content_type(path),
    "Cache-Control": "public, max-age=300",
  }
  conn.send_response(200, "OK", extra_headers=headers)
  conn.write(data)
  conn.end_response()
}
