///|
/// Main relay implementation integrating all components
pub struct RelayData {
  config : Config
  subscriptions : Array[Subscription]
}

///|
/// Create a new relay instance
pub fn new_relay(config : Config) -> RelayData {
  { config, subscriptions: [] }
}

///|
/// Create a subscription
pub fn create_subscription(
  relay : RelayData,
  sub_id : String,
  filters : Array[Filter],
) -> RelayData {
  let subscription = new_subscription(sub_id, filters)
  relay.subscriptions.push(subscription)
  relay
}

///|
/// Remove a subscription
pub fn remove_subscription(relay : RelayData, sub_id : String) -> RelayData {
  let new_subs = []
  for i = 0; i < relay.subscriptions.length(); i = i + 1 {
    if relay.subscriptions[i].id != sub_id {
      new_subs.push(relay.subscriptions[i])
    }
  }
  { config: relay.config, subscriptions: new_subs }
}

///|
/// Get relay statistics
pub fn get_stats(relay : RelayData) -> String {
  let sub_count = relay.subscriptions.length()
  "Subscriptions: \{sub_count}"
}
