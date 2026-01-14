///|
/// Handle client requests to the relay
pub struct RequestContext {
  client_id : String
  relay : RelayData
}

///|
pub fn new_context(client_id : String, relay : RelayData) -> RequestContext {
  { client_id, relay }
}

///|
/// Process incoming message from client
pub fn handle_request(
  ctx : RequestContext,
  _message_type : String,
  _data : String,
) -> Result[String, String] {
  // TODO: Parse message and dispatch to appropriate handler
  Err("Not implemented")
}

///|
/// Handle EVENT message - client sends event to relay
pub fn handle_event(
  _ctx : RequestContext,
  _event_json : String,
) -> Result[String, String] {
  // TODO: Parse event, validate, store, and notify subscribers
  Err("Not implemented")
}

///|
/// Handle REQ message - client requests events
pub fn handle_request_msg(
  _ctx : RequestContext,
  _sub_id : String,
  _filters_json : String,
) -> Result[Array[String], String] {
  // TODO: Parse filters, find matching events, return as array of JSON strings
  Err("Not implemented")
}

///|
/// Handle CLOSE message - client closes subscription
pub fn handle_close_msg(
  ctx : RequestContext,
  sub_id : String,
) -> RequestContext {
  let new_relay = remove_subscription(ctx.relay, sub_id)
  { client_id: ctx.client_id, relay: new_relay }
}

///|
/// Validate event before storing
pub fn validate_event(
  _event_id : String,
  _pubkey : String,
  _sig : String,
) -> Result[Unit, String] {
  // TODO: Validate signature
  Ok(())
}
