///|
/// Manage connected clients and their subscriptions
pub struct Client {
  id : String
  subscriptions : Array[Subscription]
}

///|
pub struct ClientManager {
  clients : Array[Client]
}

///|
pub fn new_manager() -> ClientManager {
  { clients: [] }
}

///|
/// Register a new client
pub fn add_client(manager : ClientManager, client_id : String) -> ClientManager {
  let client = { id: client_id, subscriptions: [] }
  manager.clients.push(client)
  manager
}

///|
/// Remove a client and all its subscriptions
pub fn remove_client(
  manager : ClientManager,
  client_id : String,
) -> ClientManager {
  let new_clients = []
  for i = 0; i < manager.clients.length(); i = i + 1 {
    if manager.clients[i].id != client_id {
      new_clients.push(manager.clients[i])
    }
  }
  { clients: new_clients }
}

///|
/// Get client by ID
pub fn get_client(manager : ClientManager, client_id : String) -> Client? {
  for i = 0; i < manager.clients.length(); i = i + 1 {
    if manager.clients[i].id == client_id {
      return Some(manager.clients[i])
    }
  }
  None
}

///|
/// Add subscription to client
pub fn add_subscription(
  manager : ClientManager,
  client_id : String,
  sub : Subscription,
) -> ClientManager {
  let new_clients = []
  for i = 0; i < manager.clients.length(); i = i + 1 {
    if manager.clients[i].id == client_id {
      let client = manager.clients[i]
      client.subscriptions.push(sub)
      new_clients.push(client)
    } else {
      new_clients.push(manager.clients[i])
    }
  }
  { clients: new_clients }
}

///|
/// Remove subscription from specific client
pub fn remove_client_subscription(
  manager : ClientManager,
  client_id : String,
  sub_id : String,
) -> ClientManager {
  let new_clients = []
  for i = 0; i < manager.clients.length(); i = i + 1 {
    if manager.clients[i].id == client_id {
      let client = manager.clients[i]
      let new_subs = []
      for j = 0; j < client.subscriptions.length(); j = j + 1 {
        if client.subscriptions[j].id != sub_id {
          new_subs.push(client.subscriptions[j])
        }
      }
      let updated_client = { id: client.id, subscriptions: new_subs }
      new_clients.push(updated_client)
    } else {
      new_clients.push(manager.clients[i])
    }
  }
  { clients: new_clients }
}

///|
/// Get client count
pub fn client_count(manager : ClientManager) -> Int {
  manager.clients.length()
}

///|
/// Get total subscription count across all clients
pub fn subscription_count(manager : ClientManager) -> Int {
  let mut total = 0
  for i = 0; i < manager.clients.length(); i = i + 1 {
    total = total + manager.clients[i].subscriptions.length()
  }
  total
}
