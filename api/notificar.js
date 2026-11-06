// Función de Vercel: Supabase la llama cuando hay un pedido nuevo o cambia uno, y envía la notificación al comerciante y al administrador.
// - Pedidos en efectivo o transferencia: se avisa al instante.
// - Pedidos de pago en línea: se avisa cuando Stripe confirma el pago (así nadie prepara un pedido sin cobrar).
const webpush = require("web-push");
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const cab = { apikey: KEY, Authorization: `Bearer ${KEY}` };

async function sb(ruta) {
  const r = await fetch(`${SB}/rest/v1/${ruta}`, { headers: cab });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  if (req.headers["authorization"] !== `Bearer ${process.env.WEBHOOK_SECRET}`) return res.status(401).end();
  try {
    const p = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    const ped = p && p.record;
    if (!ped) return res.status(200).json({ ok: true, omitido: true });

    let prefijo;
    if (p.type === "INSERT" && ped.pago !== "en_linea") prefijo = "🛎️ Nuevo pedido";
    else if (p.type === "UPDATE" && ped.pago === "en_linea" && ped.estado_pago === "Pagado" && p.old_record && p.old_record.estado_pago !== "Pagado") prefijo = "💳 Pedido pagado";
    else return res.status(200).json({ ok: true, omitido: true });

    webpush.setVapidDetails(process.env.VAPID_SUBJECT, process.env.VAPID_PUBLIC_KEY, process.env.VAPID_PRIVATE_KEY);
    const [com] = await sb(`comercios?id=eq.${encodeURIComponent(ped.comercio_id)}&select=nombre,dueno_id`);
    const admins = await sb("admins?select=user_id");
    const ids = [...new Set([com && com.dueno_id, ...admins.map(a => a.user_id)].filter(Boolean))];
    if (!ids.length) return res.status(200).json({ ok: true, destinos: 0 });

    const subs = await sb(`push_suscripciones?user_id=in.(${ids.join(",")})&select=endpoint,p256dh,auth`);
    const pago = { efectivo: "Efectivo", transferencia: "Transferencia", en_linea: "Pagado en línea", tarjeta: "Tarjeta" }[ped.pago] || ped.pago;
    const msg = JSON.stringify({
      titulo: `${prefijo} · ${com ? com.nombre : ""}`,
      cuerpo: `$${Number(ped.total).toFixed(2)} · ${pago} · ${ped.entrega === "domicilio" ? "A domicilio" : "Recoger"}`,
      url: "./index.html#/panel", tag: ped.id
    });

    let enviados = 0;
    await Promise.all(subs.map(async s => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, msg);
        enviados++;
      } catch (e) {
        if (e.statusCode === 404 || e.statusCode === 410)
          await fetch(`${SB}/rest/v1/push_suscripciones?endpoint=eq.${encodeURIComponent(s.endpoint)}`, { method: "DELETE", headers: cab });
      }
    }));
    res.status(200).json({ ok: true, enviados });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "fallo" });
  }
};
