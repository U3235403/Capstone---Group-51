'use strict';
const VERSION = '__VERSION__';
const PREFIX = 'stage1-pwa-';
const CACHE = PREFIX + VERSION;
const FILES = __FILES__;
const BASE = new URL('./', self.location.href);
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    try {
      // Fetch all assets before this version can become active.
      await cache.addAll(FILES.map(file => new Request(new URL(file, BASE), {cache:'reload'})));
    } catch (error) {
      await caches.delete(CACHE);
      throw error;
    }
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith(PREFIX) && name !== CACHE) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});
self.addEventListener('message', event => {
  if (event.data?.type === 'ACTIVATE_UPDATE') self.skipWaiting();
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.pathname.startsWith(new URL('api/', BASE).pathname)) return;
  if (event.request.method !== 'GET' || url.origin !== BASE.origin || !url.pathname.startsWith(BASE.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const key = event.request.mode === 'navigate' ? new URL('index.html', BASE).href : url.origin + url.pathname;
    const saved = await cache.match(key);
    return saved || fetch(event.request);
  })());
});
