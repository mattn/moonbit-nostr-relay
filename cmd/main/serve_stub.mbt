///|
/// Non-JS backends have no socket bindings yet; the WebSocket transport
/// lives in serve_js.mbt and runs on Node.
pub fn serve(config : @server.Config) -> Unit {
  println(
    "The WebSocket transport requires the JS backend. Run with:\n  moon run --target js cmd/main",
  )
  println("(configured for \{config.host}:\{config.port})")
}
