// Función de Vercel: el comerciante (o el administrador) conecta o desconecta la cuenta de Mercado Pago de un comercio.
// Devuelve la dirección de autorización de Mercado Pago; el comerciante inicia sesión AHÍ, Valle GO nunca ve su contraseña.
const crypto = require("crypto");
const { SB, KEY, UUID, sb } = require("./_mp");

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  try {
    const APP = (process.env.APP_URL || "").replace(/\/$/, "");
    const token = (req.headers.authorization || "").replace(/^Bearer /, "");
    const u = token && await fetch(`${SB}/auth/v1/user`, { headers: { apikey: KEY, Authorization: `Bearer ${token}` } });
    if (!u || !u.ok) return res.status(401).json({ error: "Sesión no válida. Inicia sesión de nuevo." });
    const user = await u.json();

    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : (req.body || {});
    if (!UUID.test(body.comercio_id || "")) return res.status(400).json({ error: "Comercio no válido." });
    const [com] = await sb(`comercios?id=eq.${body.comercio_id}&select=id,dueno_id`);
    const [adm] = await sb(`admins?user_id=eq.${user.id}&select=user_id`);
    if (!com || (com.dueno_id !== user.id && !adm)) return res.status(403).json({ error: "No tienes permiso sobre este comercio." });

    if (body.desconectar) {
      await sb(`comercio_mp?comercio_id=eq.${com.id}`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
      await sb(`comercios?id=eq.${com.id}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ mp_conectado: false }) });
      return res.status(200).json({ ok: true });
    }

    if (!process.env.MP_CLIENT_ID || !process.env.MP_CLIENT_SECRET || !APP)
      return res.status(501).json({ error: "El cobro directo aún no está habilitado. Avisa al administrador de Valle GO." });

    // Clave de un solo uso, ligada a este usuario y comercio, que vence en 15 minutos
    await sb(`mp_oauth_estado?creado=lt.${encodeURIComponent(new Date(Date.now() - 3600e3).toISOString())}`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
    const state = crypto.randomBytes(24).toString("hex");
    await sb("mp_oauth_estado", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ state, comercio_id: com.id, user_id: user.id }) });
    const url = `https://auth.mercadopago.com.mx/authorization?client_id=${encodeURIComponent(process.env.MP_CLIENT_ID)}&response_type=code&platform_id=mp&state=${state}&redirect_uri=${encodeURIComponent(APP + "/api/mp-oauth")}`;
    res.status(200).json({ url });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "No se pudo iniciar la conexión." });
  }
};
