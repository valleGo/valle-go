// Función de Vercel: crea la página de pago de Stripe (Checkout) para un pedido.
// El total se toma de la base de datos (ya calculado con precios reales), nunca del celular.
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const cab = { apikey: KEY, Authorization: `Bearer ${KEY}` };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function sb(ruta, opciones = {}) {
  const r = await fetch(`${SB}/rest/v1/${ruta}`, { ...opciones, headers: { ...cab, ...(opciones.headers || {}) } });
  if (!r.ok) throw new Error(await r.text());
  return r.status === 204 ? null : r.json().catch(() => null);
}
// Convierte {a:{b:1}} en "a[b]=1" (formato que pide Stripe)
function form(o, pre = "", out = []) {
  for (const [k, v] of Object.entries(o)) {
    const clave = pre ? `${pre}[${k}]` : k;
    if (v !== null && typeof v === "object") form(v, clave, out);
    else if (v !== undefined) out.push(encodeURIComponent(clave) + "=" + encodeURIComponent(v));
  }
  return out.join("&");
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const APP = (process.env.APP_URL || "").replace(/\/$/, "");
    if (!APP || !process.env.STRIPE_SECRET_KEY) throw new Error("Faltan variables APP_URL o STRIPE_SECRET_KEY");

    // 1. ¿Quién está pidiendo el pago? (se valida su sesión con Supabase)
    const token = (req.headers.authorization || "").replace(/^Bearer /, "");
    const u = token && await fetch(`${SB}/auth/v1/user`, { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
    if (!u || !u.ok) return res.status(401).json({ error: "Sesión no válida. Inicia sesión de nuevo." });
    const user = await u.json();

    // 2. El pedido debe ser suyo y estar pendiente de pago en línea
    const body = typeof req.body === "string" ? JSON.parse(req.body) : (req.body || {});
    if (!UUID.test(body.pedido_id || "")) return res.status(400).json({ error: "Pedido no válido." });
    const [ped] = await sb(`pedidos?id=eq.${body.pedido_id}&select=*,comercios(nombre,envio)`);
    if (!ped || ped.comprador_id !== user.id) return res.status(404).json({ error: "Pedido no encontrado." });
    if (ped.pago !== "en_linea" || ped.estado_pago !== "Pendiente")
      return res.status(409).json({ error: "Este pedido no tiene un pago pendiente." });

    // 3. Artículos con precios reales del menú
    const items = Array.isArray(ped.items) ? ped.items : [];
    const ids = items.map(i => i.id).filter(i => UUID.test(i));
    if (!ids.length) throw new Error("Pedido sin productos");
    const menu = await sb(`menu_items?id=in.(${ids.join(",")})&select=id,nombre,precio`);
    const line_items = items.map(i => {
      const m = menu.find(x => x.id === i.id);
      if (!m) throw new Error("Producto no encontrado");
      return { quantity: i.cant, price_data: { currency: "mxn", unit_amount: Math.round(Number(m.precio) * 100), product_data: { name: m.nombre } } };
    });
    const envio = Number(ped.comercios.envio);
    if (ped.entrega === "domicilio" && envio > 0)
      line_items.push({ quantity: 1, price_data: { currency: "mxn", unit_amount: Math.round(envio * 100), product_data: { name: "Envío a domicilio" } } });
    const suma = line_items.reduce((a, l) => a + l.price_data.unit_amount * l.quantity, 0);
    if (suma !== Math.round(Number(ped.total) * 100)) return res.status(409).json({ error: "El total del pedido no coincide." });

    // 4. Crear la sesión de pago en Stripe (los métodos de pago se activan en el panel de Stripe)
    const r = await fetch("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`, "Content-Type": "application/x-www-form-urlencoded" },
      body: form({
        mode: "payment", locale: "es-419", client_reference_id: ped.id, customer_email: user.email,
        success_url: `${APP}/?pago=ok#/pedidos`, cancel_url: `${APP}/#/pedidos`,
        metadata: { pedido_id: ped.id },
        payment_intent_data: { description: `Valle GO · ${ped.comercios.nombre}` },
        line_items
      })
    });
    const s = await r.json();
    if (!r.ok) { console.error(s); return res.status(502).json({ error: "No se pudo crear el pago. Intenta de nuevo." }); }

    await sb(`pedidos?id=eq.${ped.id}`, { method: "PATCH", headers: { "Content-Type": "application/json", Prefer: "return=minimal" }, body: JSON.stringify({ stripe_session_id: s.id }) });
    res.status(200).json({ url: s.url });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "No se pudo iniciar el pago." });
  }
};
