// Ayudas compartidas para el cobro directo (cada comercio conecta su cuenta de Mercado Pago).
// El archivo empieza con "_" para que Vercel no lo publique como función.
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
const cab = KEY && KEY.startsWith("sb_") ? { apikey: KEY } : { apikey: KEY, Authorization: `Bearer ${KEY}` };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function sb(ruta, opciones = {}) {
  const r = await fetch(`${SB}/rest/v1/${ruta}`, { ...opciones, headers: { ...cab, "Content-Type": "application/json", ...(opciones.headers || {}) } });
  if (!r.ok) throw new Error(await r.text());
  return r.status === 204 ? null : r.json().catch(() => null);
}

// Token del comercio, renovado si está por vencer. Devuelve null si el comercio no conectó su cuenta.
async function tokenComercio(comercioId) {
  if (!UUID.test(comercioId || "")) return null;
  const [cm] = await sb(`comercio_mp?comercio_id=eq.${comercioId}&select=*`);
  if (!cm) return null;
  const vence = cm.expira_en ? new Date(cm.expira_en).getTime() : 0;
  if (vence - Date.now() > 10 * 60 * 1000 || !cm.refresh_token) return cm.access_token;
  const r = await fetch("https://api.mercadopago.com/oauth/token", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: process.env.MP_CLIENT_ID, client_secret: process.env.MP_CLIENT_SECRET, grant_type: "refresh_token", refresh_token: cm.refresh_token })
  });
  const t = await r.json();
  if (!r.ok || !t.access_token) { console.error("No se pudo renovar el token del comercio", comercioId, r.status); return cm.access_token; }
  await sb(`comercio_mp?comercio_id=eq.${comercioId}`, { method: "PATCH", headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ access_token: t.access_token, refresh_token: t.refresh_token || cm.refresh_token, expira_en: new Date(Date.now() + (t.expires_in || 15552000) * 1000).toISOString(), actualizado: new Date().toISOString() }) });
  return t.access_token;
}

// Comisión de Valle GO por pedido pagado en línea (se descuenta sola al comercio).
// MP_FEE_PCT = porcentaje sobre el total (ej. 3) y MP_FEE_FIJO = pesos fijos (ej. 5). Sin definir = 0.
function comisionPlataforma(total) {
  const pct = Number(process.env.MP_FEE_PCT || 0), fijo = Number(process.env.MP_FEE_FIJO || 0);
  const f = Math.round((total * pct / 100 + fijo) * 100) / 100;
  return Math.max(0, Math.min(f, Math.round(total * 50) / 100)); // nunca más del 50% del pedido
}

module.exports = { SB, KEY, cab, UUID, sb, tokenComercio, comisionPlataforma };
