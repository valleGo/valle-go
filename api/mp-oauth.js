// Función de Vercel: Mercado Pago regresa aquí al comerciante después de autorizar. Guarda su conexión.
const { UUID, sb } = require("./_mp");

module.exports = async (req, res) => {
  const APP = (process.env.APP_URL || "").replace(/\/$/, "");
  const volver = ok => res.redirect(302, `${APP}/?mp=${ok ? "ok" : "error"}#/panel`);
  try {
    const { code, state } = req.query || {};
    if (!code || !/^[0-9a-f]{48}$/.test(state || "")) return volver(false);
    const [st] = await sb(`mp_oauth_estado?state=eq.${state}&select=*`);
    await sb(`mp_oauth_estado?state=eq.${state}`, { method: "DELETE", headers: { Prefer: "return=minimal" } }); // un solo uso
    if (!st || !UUID.test(st.comercio_id) || Date.now() - new Date(st.creado).getTime() > 15 * 60 * 1000) return volver(false);

    const r = await fetch("https://api.mercadopago.com/oauth/token", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ client_id: process.env.MP_CLIENT_ID, client_secret: process.env.MP_CLIENT_SECRET, grant_type: "authorization_code", code, redirect_uri: APP + "/api/mp-oauth" })
    });
    const t = await r.json();
    if (!r.ok || !t.access_token) { console.error("OAuth Mercado Pago falló", r.status, JSON.stringify({ error: t.error, message: t.message })); return volver(false); }

    await sb("comercio_mp?on_conflict=comercio_id", { method: "POST", headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify({ comercio_id: st.comercio_id, mp_user_id: String(t.user_id || ""), access_token: t.access_token, refresh_token: t.refresh_token || null,
        expira_en: new Date(Date.now() + (t.expires_in || 15552000) * 1000).toISOString(), actualizado: new Date().toISOString() }) });
    await sb(`comercios?id=eq.${st.comercio_id}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ mp_conectado: true }) });
    volver(true);
  } catch (e) {
    console.error(e);
    volver(false);
  }
};
