///|
/// Relay server configuration
pub(all) struct Config {
  host : String
  port : Int
  max_events : Int
  verify_sigs : Bool // verify event ids and Schnorr signatures
}

///|
pub fn default_config() -> Config {
  { host: "0.0.0.0", port: 8080, max_events: 100000, verify_sigs: true }
}
