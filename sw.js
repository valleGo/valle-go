// Service worker de Valle GO: abre sin internet, siempre intenta traer la versión nueva y recibe notificaciones.
const CACHE = "valle-go-v116";
const ARCHIVOS = ["./", "./index.html", "./config.js", "./manifest.json", "./icon-192.png", "./icon-512.png", "./icon-180.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARCHIVOS)));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  const mismo = new URL(e.request.url).origin === location.origin;
  e.respondWith(
    fetch(e.request).then(r => {
      if (mismo && r.ok) { const copia = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copia)); }
      return r;
    }).catch(() => caches.match(e.request).then(r => r || caches.match("./index.html")))
  );
});

// Notificaciones de pedidos nuevos
self.addEventListener("push", e => {
  let d = {};
  try { d = e.data.json(); } catch (x) { try { d = { cuerpo: e.data.text() }; } catch (y) {} }
  const tag = d.tag || ("vg" + Date.now());
  const opc = {
    body: d.cuerpo || "", icon: "icon-192.png", badge: "icon-192.png",
    tag, renotify: true, requireInteraction: true, silent: false,
    vibrate: [500, 200, 500, 200, 500, 200, 900, 300, 900], timestamp: Date.now(), data: { url: d.url || "./index.html#/panel" }
  };
  // si el navegador rechaza alguna opción, se muestra igual con lo básico (nunca se pierde el aviso)
  e.waitUntil(self.registration.showNotification(d.titulo || "Valle GO", opc).catch(() =>
    self.registration.showNotification(d.titulo || "Valle GO", { body: d.cuerpo || "", icon: "icon-192.png", data: opc.data })));
});
self.addEventListener("pushsubscriptionchange", e => {
  e.waitUntil(clients.matchAll({ includeUncontrolled: true }).then(l => l.forEach(c => c.postMessage({ tipo: "renovarPush" }))));
});
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = e.notification.data.url;
  e.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then(l => {
    for (const c of l) { if ("focus" in c) { c.navigate(url); return c.focus(); } }
    return clients.openWindow(url);
  }));
});
