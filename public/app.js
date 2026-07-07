globalThis.addEventListener('DOMContentLoaded', async () => {
  const u = new URL(location.href)
  const relayName = u.protocol.replace(/^http/, 'ws') + '//' + u.host + u.pathname.replace(/\/$/, '')
  document.querySelector('#relay-name').textContent = relayName
  try {
    const info = await (await fetch('/', { headers: { accept: 'application/nostr+json' } })).json()
    if (info.name) {
      document.title = info.name
      document.querySelector('#relay-title').textContent = info.name + ' the Nostr relay server'
    }
    if (info.description) document.querySelector('#relay-description').textContent = info.description
    if (info.icon) document.querySelector('#logo').src = info.icon
  } catch (e) {}
  const m = document.querySelector('#makibishi')
  m.setAttribute('data-content', '🤙')
  m.setAttribute('data-relays', 'wss://relay.nostr.band,wss://nos.lol,wss://relay.damus.io,wss://yabu.me,wss://cagliostr.compile-error.net,wss://nostr.compile-error.net')
  m.setAttribute('data-allow-anonymous-reaction', true)
  m.setAttribute('data-url', relayName)
  globalThis.makibishi.initTarget(m)
}, false)
