///| Relay-to-client message construction (NIP-01)

///|
pub fn notice(msg : String) -> String {
  ([("NOTICE" : Json), msg.to_json()] : Array[Json]).to_json().stringify()
}

///|
pub fn ok_msg(event_id : String, success : Bool, msg : String) -> String {
  (
    [("OK" : Json), event_id.to_json(), success.to_json(), msg.to_json()] :
    Array[Json])
  .to_json()
  .stringify()
}

///|
pub fn eose(sub_id : String) -> String {
  ([("EOSE" : Json), sub_id.to_json()] : Array[Json]).to_json().stringify()
}

///|
pub fn closed(sub_id : String, msg : String) -> String {
  ([("CLOSED" : Json), sub_id.to_json(), msg.to_json()] : Array[Json])
  .to_json()
  .stringify()
}

///|
pub fn event_msg(sub_id : String, ev : @event.Event) -> String {
  ([("EVENT" : Json), sub_id.to_json(), ev.to_json()] : Array[Json])
  .to_json()
  .stringify()
}
