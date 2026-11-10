// Función de Vercel: Mercado Pago la llama cuando cambia el estado de un pago.
// No se confía en lo que llega: se consulta el pago directamente a Mercado Pago con tu token.
const crypto = require("crypto");
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
const cab = KEY && KEY.startsWith("sb_") ? { apikey: KEY } : { apikey: KEY, Authorization: `Bearer ${KEY}` };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const { tokenComercio } = require("./_mp");

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const body = typeof req.body === "string" ? (JSON.parse(req.body || "{}")) : (req.body || {});
    const q = req.query || {};
    const tipo = q.type || q.topic || body.type || body.topic;
    if (tipo !== "payment") return res.status(200).json({ ok: true, omitido: true });
    const pid = String(q["data.id"] || q.id || (body.data && body.data.id) || "");
    if (!/^\d{1,20}$/.test(pid)) return res.status(400).end();

    // Firma opcional (si defines MP_WEBHOOK_SECRET en Vercel, se exige y se valida)
    const secreto = process.env.MP_WEBHOOK_SECRET;
    if (secreto) {
      const partes = Object.fromEntries(String(req.headers["x-signature"] || "").split(",").map(s => s.trim().split("=")));
      const manifiesto = `id:${pid};request-id:${req.headers["x-request-id"] || ""};ts:${partes.ts};`;
      const esperado = crypto.createHmac("sha256", secreto).update(manifiesto).digest("hex");
      if (!partes.v1 || partes.v1.length !== esperado.length || !crypto.timingSafeEqual(Buffer.from(partes.v1), Buffer.from(esperado)))
        return res.status(401).end();
    }

    // La verdad viene de Mercado Pago, no del mensaje recibido
    // Pagos de comercios con cuenta propia: se consultan con el token de ese comercio (?c=...)
    const comercioMP = UUID.test(q.c || "") ? q.c : null;
    const tokenConsulta = (comercioMP && await tokenComercio(comercioMP)) || process.env.MP_ACCESS_TOKEN;
    const rp = await fetch(`https://api.mercadopago.com/v1/payments/${pid}`, { headers: { Authorization: `Bearer ${tokenConsulta}` } });
    if (!rp.ok) throw new Error(await rp.text());
    const pago = await rp.json();
    const id = pago.external_reference;
    if (!UUID.test(id || "")) return res.status(200).json({ ok: true, sin_pedido: true });

    const rd = await fetch(`${SB}/rest/v1/pedidos?id=eq.${id}&select=total,estado_pago,pago,comercio_id`, { headers: cab });
    const [ped] = await rd.json();
    if (!ped || ped.pago !== "en_linea") return res.status(200).json({ ok: true, sin_pedido: true });
    // Un pago de la cuenta de un comercio solo puede liquidar pedidos de ESE comercio
    if (comercioMP && ped.comercio_id !== comercioMP) return res.status(200).json({ ok: true, otro_comercio: true });

    let estado = null;
    if (pago.status === "approved") {
      // Solo se marca pagado si Mercado Pago cobró exactamente el total del pedido, en pesos
      if (pago.currency_id !== "MXN" || Math.round(Number(pago.transaction_amount) * 100) !== Math.round(Number(ped.total) * 100)) {
        console.error("Monto no coincide", id, pago.transaction_amount, ped.total);
        return res.status(200).json({ ok: true, monto_distinto: true });
      }
      estado = "Pagado";
    } else if (pago.status === "rejected") estado = "Fallido";
    else if (pago.status === "cancelled") estado = "Expirado";
    if (!estado) return res.status(200).json({ ok: true, pendiente: true });

    const filtro = estado === "Pagado" ? `id=eq.${id}&estado_pago=neq.Pagado` : `id=eq.${id}&estado_pago=eq.Pendiente`;
    const cambios = estado === "Pagado" ? { estado_pago: estado, pagado_en: new Date().toISOString(), mp_payment_id: pid } : { estado_pago: estado, mp_payment_id: pid };
    await fetch(`${SB}/rest/v1/pedidos?${filtro}`, {
      method: "PATCH", headers: { ...cab, "Content-Type": "application/json", Prefer: "return=minimal" }, body: JSON.stringify(cambios)
    });
    res.status(200).json({ ok: true, estado });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "fallo" });
  }
};
