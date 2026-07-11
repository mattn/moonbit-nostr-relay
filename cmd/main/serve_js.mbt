///| WebSocket transport for the JS (Node) backend.

///|

///| A minimal RFC 6455 server is implemented inline with node:http and

///| node:crypto — no npm dependencies. The MoonBit relay engine drives all

///| protocol logic; this file only moves text frames in and out.

///|
extern "js" fn node_ws_serve(
  port : Int,
  host : String,
  on_open : (Int) -> Unit,
  on_message : (Int, String) -> Unit,
  on_close : (Int) -> Unit,
  nip11 : String,
) -> Unit =
  #|(port, host, onOpen, onMessage, onClose, nip11) => {
  #|  const http = process.getBuiltinModule('node:http');
  #|  const crypto = process.getBuiltinModule('node:crypto');
  #|  const MAX_FRAME = 1 << 20;
  #|  const conns = new Map();
  #|  let nextId = 1;
  #|  const sendFrame = (sock, op, payload) => {
  #|    const len = payload.length;
  #|    let header;
  #|    if (len < 126) {
  #|      header = Buffer.from([0x80 | op, len]);
  #|    } else if (len < 65536) {
  #|      header = Buffer.alloc(4);
  #|      header[0] = 0x80 | op;
  #|      header[1] = 126;
  #|      header.writeUInt16BE(len, 2);
  #|    } else {
  #|      header = Buffer.alloc(10);
  #|      header[0] = 0x80 | op;
  #|      header[1] = 127;
  #|      header.writeBigUInt64BE(BigInt(len), 2);
  #|    }
  #|    sock.write(Buffer.concat([header, payload]));
  #|  };
  #|  globalThis.__nostr_send = (id, msg) => {
  #|    const sock = conns.get(id);
  #|    if (sock) sendFrame(sock, 1, Buffer.from(msg, 'utf8'));
  #|  };
  #|  const server = http.createServer((req, res) => {
  #|    if ((req.headers['accept'] || '').includes('application/nostr+json')) {
  #|      res.writeHead(200, {
  #|        'content-type': 'application/nostr+json',
  #|        'access-control-allow-origin': '*',
  #|      });
  #|      res.end(nip11);
  #|      return;
  #|    }
  #|    res.writeHead(200, { 'content-type': 'text/plain' });
  #|    res.end('This is a Nostr relay. Connect via WebSocket.\n');
  #|  });
  #|  server.on('upgrade', (req, sock) => {
  #|    const key = req.headers['sec-websocket-key'];
  #|    if (!key || String(req.headers['upgrade'] || '').toLowerCase() !== 'websocket') {
  #|      sock.destroy();
  #|      return;
  #|    }
  #|    const accept = crypto
  #|      .createHash('sha1')
  #|      .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
  #|      .digest('base64');
  #|    sock.write(
  #|      'HTTP/1.1 101 Switching Protocols\r\n' +
  #|        'Upgrade: websocket\r\n' +
  #|        'Connection: Upgrade\r\n' +
  #|        'Sec-WebSocket-Accept: ' + accept + '\r\n\r\n'
  #|    );
  #|    const id = nextId++;
  #|    conns.set(id, sock);
  #|    sock.setNoDelay(true);
  #|    let buf = Buffer.alloc(0);
  #|    let frags = [];
  #|    let fragLen = 0;
  #|    let fragOp = 0;
  #|    let dead = false;
  #|    const shutdown = (code) => {
  #|      if (dead) return;
  #|      dead = true;
  #|      try {
  #|        const b = Buffer.alloc(2);
  #|        b.writeUInt16BE(code, 0);
  #|        sendFrame(sock, 8, b);
  #|      } catch (e) {}
  #|      sock.end();
  #|    };
  #|    sock.on('data', (chunk) => {
  #|      buf = Buffer.concat([buf, chunk]);
  #|      if (buf.length > MAX_FRAME * 4) { shutdown(1009); return; }
  #|      while (!dead) {
  #|        if (buf.length < 2) return;
  #|        const fin = (buf[0] & 0x80) !== 0;
  #|        const op = buf[0] & 0x0f;
  #|        const masked = (buf[1] & 0x80) !== 0;
  #|        let len = buf[1] & 0x7f;
  #|        let off = 2;
  #|        if (len === 126) {
  #|          if (buf.length < 4) return;
  #|          len = buf.readUInt16BE(2);
  #|          off = 4;
  #|        } else if (len === 127) {
  #|          if (buf.length < 10) return;
  #|          const big = buf.readBigUInt64BE(2);
  #|          if (big > BigInt(MAX_FRAME)) { shutdown(1009); return; }
  #|          len = Number(big);
  #|          off = 10;
  #|        }
  #|        if (len > MAX_FRAME) { shutdown(1009); return; }
  #|        if (!masked) { shutdown(1002); return; }
  #|        if (buf.length < off + 4 + len) return;
  #|        const mask = buf.subarray(off, off + 4);
  #|        const payload = Buffer.from(buf.subarray(off + 4, off + 4 + len));
  #|        for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
  #|        buf = buf.subarray(off + 4 + len);
  #|        if (op === 8) { shutdown(1000); return; }
  #|        if (op === 9) { sendFrame(sock, 10, payload); continue; }
  #|        if (op === 10) continue;
  #|        if (op === 1 || op === 2) {
  #|          frags = [payload];
  #|          fragLen = payload.length;
  #|          fragOp = op;
  #|        } else if (op === 0) {
  #|          if (fragOp === 0) { shutdown(1002); return; }
  #|          frags.push(payload);
  #|          fragLen += payload.length;
  #|        } else {
  #|          shutdown(1002);
  #|          return;
  #|        }
  #|        if (fragLen > MAX_FRAME) { shutdown(1009); return; }
  #|        if (fin) {
  #|          const full = Buffer.concat(frags);
  #|          frags = [];
  #|          fragLen = 0;
  #|          const deliverOp = fragOp;
  #|          fragOp = 0;
  #|          if (deliverOp === 1) onMessage(id, full.toString('utf8'));
  #|        }
  #|      }
  #|    });
  #|    sock.on('error', () => {});
  #|    sock.on('close', () => {
  #|      if (conns.delete(id)) onClose(id);
  #|    });
  #|    onOpen(id);
  #|  });
  #|  server.listen(port, host, () => {
  #|    console.log('listening on ws://' + host + ':' + port);
  #|  });
  #|}

///|
extern "js" fn node_ws_send(conn : Int, msg : String) -> Unit =
  #|(conn, msg) => globalThis.__nostr_send(conn, msg)

///|
pub fn serve(config : @server.Config) -> Unit {
  let relay = @server.Relay::new(config, @storage.new_store(config.max_events))
  let conns : Map[String, Int] = {}
  node_ws_serve(
    config.port,
    config.host,
    fn(conn) { conns.set(conn.to_string(), conn) },
    fn(conn, text) {
      for o in relay.handle_message(conn.to_string(), text) {
        match conns.get(o.client_id) {
          Some(c) => node_ws_send(c, o.message)
          None => ()
        }
      }
    },
    fn(conn) {
      let id = conn.to_string()
      conns.remove(id)
      relay.client_disconnected(id)
    },
    @server.nip11_doc(),
  )
}
