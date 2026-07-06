///|
/// Nostr relay server entry point
fn main {
  let config = @server.default_config()
  println("moonbit-nostr-relay v0.1.0")
  serve(config)
}
