// Service worker de Valle GO: abre sin internet, siempre intenta traer la versión nueva y recibe notificaciones.
const CACHE = "valle-go-v182";
// Imágenes propias, librería de Supabase y fuente: se sirven al instante desde aquí y se actualizan en segundo plano.
// Este caché no cambia de nombre con cada versión, así no se vuelven a descargar en cada actualización.
const ESTATICO = "valle-go-estatico-v1";
const ARCHIVOS = ["./", "./index.html", "./config.js", "./manifest.json", "./icon-192.png"];
const EXTERNOS = ["cdn.jsdelivr.net", "fonts.googleapis.com", "fonts.gstatic.com"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARCHIVOS)));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE && k !== ESTATICO).map(k => caches.delete(k)))));
  self.clients.claim();
});

// Rápido: responde con lo guardado y actualiza en segundo plano (si no hay nada guardado, espera a la red).
function rapido(e) {
  const red = fetch(e.request).then(r => {
    if (r.ok || r.type === "opaque") { const copia = r.clone(); caches.open(ESTATICO).then(c => c.put(e.request, copia)); }
    return r;
  });
  e.waitUntil(red.then(() => {}, () => {}));
  return caches.match(e.request).then(g => g || red);
}
// Red primero (para recibir siempre la versión nueva). Si la red tarda más de 4 s al abrir la app, usa la copia guardada.
function redPrimero(e) {
  const req = e.request;
  const red = fetch(req).then(r => {
    if (r.ok) { const copia = r.clone(); caches.open(CACHE).then(c => c.put(req, copia)); }
    return r;
  });
  e.waitUntil(red.then(() => {}, () => {}));
  const respaldo = () => caches.match(req).then(r => r || caches.match("./index.html"));
  if (req.mode !== "navigate") return red.catch(respaldo);
  return new Promise(res => {
    let hecho = false;
    const fin = r => { if (!hecho && r) { hecho = true; res(r); } };
    const t = setTimeout(() => respaldo().then(fin), 4000);
    red.then(r => { clearTimeout(t); fin(r); },
             () => { clearTimeout(t); respaldo().then(r => { fin(r); if (!hecho) { hecho = true; res(Response.error()); } }); });
  });
}
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  const u = new URL(e.request.url);
  if (u.origin === location.origin) {
    if (u.pathname.startsWith("/api/")) return;                       // funciones del servidor: directo a la red
    if (/\.(png|svg|jpg|jpeg|webp|ico)$/i.test(u.pathname)) { e.respondWith(rapido(e)); return; }
    e.respondWith(redPrimero(e));
    return;
  }
  if (EXTERNOS.includes(u.hostname)) { e.respondWith(rapido(e)); return; }
  // Supabase y demás servicios externos: el navegador los maneja directo (sin pasar por aquí)
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
