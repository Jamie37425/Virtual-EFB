// Self-unregistering service worker: clears all old caches and unregisters itself
// so ServiceWorker interception never interferes with EFB iframes or live file updates.
self.addEventListener('install', (e) => {
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
      .then(() => self.registration.unregister())
      .then(() => self.clients.matchAll())
      .then((clients) => {
        clients.forEach((client) => {
          if (client.url && 'navigate' in client) client.navigate(client.url);
        });
      })
  );
});
