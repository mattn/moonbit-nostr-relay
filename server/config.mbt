///|
/// Relay server configuration
pub(all) struct Config {
  host : String
  port : Int
  max_events : Int
  verify_sigs : Bool // verify event ids and Schnorr signatures
  now : () -> UInt64 // wall clock in unix seconds (injectable for tests)
}

///|
/// Wall clock in unix seconds (`@env.now()` is milliseconds since the epoch)
pub fn unix_now() -> UInt64 {
  @env.now() / 1000
}

///|
pub fn default_config() -> Config {
  {
    host: "0.0.0.0",
    port: 8080,
    max_events: 100000,
    verify_sigs: true,
    now: unix_now,
  }
}
