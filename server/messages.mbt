///| Relay-to-client message construction (NIP-01)

///|
pub fn notice(msg : String) -> String {
  Json::array([Json("NOTICE"), Json(msg)]).stringify()
}

///|
pub fn ok_msg(event_id : String, success : Bool, msg : String) -> String {
  Json::array([Json("OK"), Json(event_id), Json(success), Json(msg)]).stringify()
}

///|
pub fn eose(sub_id : String) -> String {
  Json::array([Json("EOSE"), Json(sub_id)]).stringify()
}

///|
pub fn closed(sub_id : String, msg : String) -> String {
  Json::array([Json("CLOSED"), Json(sub_id), Json(msg)]).stringify()
}

///|
pub fn count_msg(query_id : String, count : Int) -> String {
  Json::array([
    Json("COUNT"),
    Json(query_id),
    Json::object(Map::from_array([("count", Json(count))])),
  ]).stringify()
}

///|
pub fn event_msg(sub_id : String, ev : @event.Event) -> String {
  Json::array([Json("EVENT"), Json(sub_id), ev.to_json()]).stringify()
}

///|
pub fn auth_msg(challenge : String) -> String {
  Json::array([Json("AUTH"), Json(challenge)]).stringify()
}
