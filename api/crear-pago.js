// Función de Vercel: crea la página de pago de Mercado Pago (Checkout Pro) para un pedido.
// El total se toma de la base de datos (ya calculado con precios reales), nunca del celular.
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
const cab = KEY && KEY.startsWith("sb_") ? { apikey: KEY } : { apikey: KEY, Authorization: `Bearer ${KEY}` };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const { tokenComercio, comisionPlataforma } = require("./_mp");

async function sb(ruta, opciones = {}) {
  const r = await fetch(`${SB}/rest/v1/${ruta}`, { ...opciones, headers: { ...cab, ...(opciones.headers || {}) } });
  if (!r.ok) throw new Error(await r.text());
  return r.status === 204 ? null : r.json().catch(() => null);
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const APP = (process.env.APP_URL || "").replace(/\/$/, "");
    const MP = process.env.MP_ACCESS_TOKEN;
    if (!APP || !MP) throw new Error("Faltan variables APP_URL o MP_ACCESS_TOKEN");

    // 1. ¿Quién pide el pago? (se valida su sesión con Supabase)
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
    const lineas = items.map(i => {
      const m = menu.find(x => x.id === i.id);
      if (!m) throw new Error("Producto no encontrado");
      return { id: m.id, title: m.nombre, quantity: i.cant, unit_price: Number(m.precio), currency_id: "MXN" };
    });
    const envio = Number(ped.comercios.envio);
    if (ped.entrega === "domicilio" && envio > 0)
      lineas.push({ id: "envio", title: "Envío a domicilio", quantity: 1, unit_price: envio, currency_id: "MXN" });
    const suma = lineas.reduce((a, l) => a + Math.round(l.unit_price * 100) * l.quantity, 0);
    if (suma !== Math.round(Number(ped.total) * 100)) return res.status(409).json({ error: "El total del pedido no coincide." });

    // 4. Si el comercio conectó su cuenta de Mercado Pago, el dinero le llega directo a él
    //    y la comisión de Valle GO (marketplace_fee) se descuenta sola. Si no, se cobra como antes.
    const tokenVend = await tokenComercio(ped.comercio_id);
    // La comisión de Valle GO se calcula solo sobre los productos: el envío lo cobra el propio comercio.
    const productos = lineas.filter(l => l.id !== "envio").reduce((a, l) => a + Math.round(l.unit_price * 100) * l.quantity, 0) / 100;
    const comision = tokenVend ? comisionPlataforma(productos) : 0;

    // 5. Crear la preferencia de pago en Mercado Pago
    const r = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method: "POST",
      headers: { Authorization: `Bearer ${tokenVend || MP}`, "Content-Type": "application/json", "X-Idempotency-Key": ped.id + "-" + Date.now() },
      body: JSON.stringify({
        items: lineas,
        payer: { email: user.email },
        external_reference: ped.id,
        notification_url: `${APP}/api/mp-webhook${tokenVend ? "?c=" + ped.comercio_id : ""}`,
        ...(comision > 0 ? { marketplace_fee: comision } : {}),
        back_urls: { success: `${APP}/?pago=ok#/pedidos`, pending: `${APP}/?pago=ok#/pedidos`, failure: `${APP}/#/pedidos` },
        auto_return: "approved",
        statement_descriptor: "VALLE GO"
      })
    });
    const p = await r.json();
    if (!r.ok || !p.init_point) { console.error(JSON.stringify(p)); return res.status(502).json({ error: "No se pudo crear el pago. Intenta de nuevo." }); }

    await sb(`pedidos?id=eq.${ped.id}`, { method: "PATCH", headers: { "Content-Type": "application/json", Prefer: "return=minimal" }, body: JSON.stringify({ mp_preference_id: p.id }) });
    res.status(200).json({ url: p.init_point });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "No se pudo iniciar el pago." });
  }
};
