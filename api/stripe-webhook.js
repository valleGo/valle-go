// Función de Vercel: Stripe la llama cuando cambia el estado de un pago.
// No se confía en lo que llega: se vuelve a consultar la sesión directamente a Stripe con tu llave secreta.
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;   // llave secreta nueva (sb_secret_...) o la anterior
const cab = KEY && KEY.startsWith("sb_") ? { apikey: KEY } : { apikey: KEY, Authorization: `Bearer ${KEY}` };  // llaves nuevas (sb_secret_...): solo "apikey"
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIPOS = ["checkout.session.completed", "checkout.session.async_payment_succeeded", "checkout.session.async_payment_failed", "checkout.session.expired"];

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const ev = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    if (!ev || !TIPOS.includes(ev.type)) return res.status(200).json({ ok: true, omitido: true });
    const sid = ev.data && ev.data.object && ev.data.object.id;
    if (!/^cs_[A-Za-z0-9_]+$/.test(sid || "")) return res.status(400).end();

    // La verdad viene de Stripe, no del mensaje recibido
    const rs = await fetch(`https://api.stripe.com/v1/checkout/sessions/${sid}`, { headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}` } });
    if (!rs.ok) throw new Error(await rs.text());
    const s = await rs.json();
    const id = s.client_reference_id;
    if (!UUID.test(id || "")) return res.status(200).json({ ok: true, sin_pedido: true });

    const rp = await fetch(`${SB}/rest/v1/pedidos?id=eq.${id}&select=total,stripe_session_id,estado_pago`, { headers: cab });
    const [ped] = await rp.json();
    if (!ped) return res.status(200).json({ ok: true, sin_pedido: true });

    let estado = null;
    if (s.payment_status === "paid") {
      // Solo se marca pagado si Stripe cobró exactamente el total del pedido, en pesos
      if (s.currency !== "mxn" || s.amount_total !== Math.round(Number(ped.total) * 100)) {
        console.error("Monto no coincide", id, s.amount_total, ped.total);
        return res.status(200).json({ ok: true, monto_distinto: true });
      }
      estado = "Pagado";
    } else if (ped.stripe_session_id === s.id) {          // solo la sesión más reciente puede fallar o vencer
      if (s.status === "expired") estado = "Expirado";
      else if (ev.type === "checkout.session.async_payment_failed") estado = "Fallido";
    }
    if (!estado) return res.status(200).json({ ok: true, pendiente: true });

    const filtro = estado === "Pagado" ? `id=eq.${id}&estado_pago=neq.Pagado` : `id=eq.${id}&estado_pago=eq.Pendiente`;
    const cambios = estado === "Pagado" ? { estado_pago: estado, pagado_en: new Date().toISOString() } : { estado_pago: estado };
    await fetch(`${SB}/rest/v1/pedidos?${filtro}`, {
      method: "PATCH", headers: { ...cab, "Content-Type": "application/json", Prefer: "return=minimal" }, body: JSON.stringify(cambios)
    });
    res.status(200).json({ ok: true, estado });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "fallo" });
  }
};
