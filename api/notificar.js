// Función de Vercel: Supabase la llama cuando hay un pedido nuevo o cambia uno, y envía la notificación al comerciante y al administrador.
// - Pedidos en efectivo o transferencia: se avisa al instante.
// - Pedidos de pago en línea: se avisa cuando Stripe confirma el pago (así nadie prepara un pedido sin cobrar).
const webpush = require("web-push");
const SB = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;   // llave secreta nueva (sb_secret_...) o la anterior
const cab = KEY && KEY.startsWith("sb_") ? { apikey: KEY } : { apikey: KEY, Authorization: `Bearer ${KEY}` };  // llaves nuevas (sb_secret_...): solo "apikey"

async function sb(ruta) {
  const r = await fetch(`${SB}/rest/v1/${ruta}`, { headers: cab });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}


// ---- SERVICIOS: avisos de citas y consultas de stock ----
async function enviar(ids, msgObj) {
  webpush.setVapidDetails(process.env.VAPID_SUBJECT, process.env.VAPID_PUBLIC_KEY, process.env.VAPID_PRIVATE_KEY);
  ids = [...new Set(ids.filter(Boolean))];
  if (!ids.length) return 0;
  const subs = await sb(`push_suscripciones?user_id=in.(${ids.join(",")})&select=endpoint,p256dh,auth`);
  const msg = JSON.stringify(msgObj);
  let enviados = 0;
  await Promise.all(subs.map(async s => {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, msg, { urgency: "high", TTL: 3600 });
      enviados++;
    } catch (e) {
      if (e.statusCode === 404 || e.statusCode === 410)
        await fetch(`${SB}/rest/v1/push_suscripciones?endpoint=eq.${encodeURIComponent(s.endpoint)}`, { method: "DELETE", headers: cab });
    }
  }));
  return enviados;
}
const fechaMX = f => { const [y, m, d] = String(f).split("-"); return `${d}/${m}/${y}`; };
async function servicios(p, res) {
  const r = p.record, old = p.old_record || {};
  const [per] = await sb(`${p.table === "viajes" ? "servicios_perfiles" : "comercios"}?id=eq.${encodeURIComponent(r.perfil_id)}&select=nombre,dueno_id`);   // citas y consultas son de comercios (planes Básico y Simple)
  if (!per) return res.status(200).json({ ok: true, omitido: true });
  const admins = (await sb("admins?select=user_id")).map(a => a.user_id);
  const dueño = per.dueno_id ? [per.dueno_id] : admins;   // si aún no tiene dueño asignado, avisa a los administradores
  let ids, titulo, cuerpo, url, tag = r.id + (p.type === "UPDATE" ? r.estado : "");
  if (p.table === "citas") {
    const cuando = `${fechaMX(r.fecha)} a las ${r.hora}`;
    if (p.type === "INSERT") { ids = dueño; titulo = `📅 Nueva solicitud de cita · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "Cliente"}${r.cliente_tel ? " · " + r.cliente_tel : ""}\n${r.servicio_nombre || "Servicio"} · ${cuando}${r.notas ? "\nNotas: " + r.notas : ""}\nToca para confirmarla o proponer otra hora.`; url = "./index.html#/panel-servicios"; }
    else if (r.cambio_por && r.cambio_por === r.cliente_id) {   // lo hizo el cliente: se avisa al prestador
      if (r.estado === "Cancelada" && old.estado !== "Cancelada") { ids = dueño; titulo = `❌ Cita cancelada · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "El cliente"} canceló su cita del ${cuando}.`; url = "./index.html#/panel-servicios"; }
      else if (r.estado === "Confirmada" && old.estado === "Reprogramada") { ids = dueño; titulo = `✅ Cliente aceptó la nueva hora · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "El cliente"} aceptó: ${cuando}.`; url = "./index.html#/panel-servicios"; }
      else return res.status(200).json({ ok: true, omitido: true });
    }
    else if (r.estado !== old.estado || r.respuesta !== old.respuesta || r.fecha !== old.fecha || r.hora !== old.hora) {
      const T = { Confirmada: ["✅ Cita confirmada", `${per.nombre} confirmó tu cita: ${r.servicio_nombre || "servicio"}, ${cuando}.`],
        Reprogramada: ["🔁 Nueva hora propuesta", `${per.nombre} propone: ${cuando}. Toca para aceptarla o cancelar.`],
        Cancelada: ["❌ Cita cancelada", `${per.nombre} canceló tu cita del ${cuando}.`],
        Completada: ["🎉 Cita completada", `Gracias por tu visita a ${per.nombre}.`] }[r.estado];
      if (!T) return res.status(200).json({ ok: true, omitido: true });
      ids = [r.cliente_id]; titulo = `${T[0]} · ${per.nombre}`; cuerpo = T[1] + (r.respuesta ? `\nMensaje: ${r.respuesta}` : ""); url = "./index.html#/mis-servicios";
    } else return res.status(200).json({ ok: true, omitido: true });
  } else if (p.table === "viajes") {
    const cuando = r.fecha ? ` · ${fechaMX(r.fecha)}${r.hora ? " " + r.hora : ""}` : "";
    const ruta = `${r.origen} → ${r.destino}${cuando}`;
    if (p.type === "INSERT") { ids = dueño; titulo = `🚕 Nueva solicitud de ${r.tipo === "agenda" ? "viaje" : "cotización"} · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "Cliente"}${r.cliente_tel ? " · " + r.cliente_tel : ""}\n${ruta}${r.detalle ? "\n" + String(r.detalle).slice(0, 120) : ""}\nToca para responder.`; url = "./index.html#/panel-servicios"; }
    else if (r.cambio_por && r.cambio_por === r.cliente_id) {
      if (r.estado === "Cancelada" && old.estado !== "Cancelada") { ids = dueño; titulo = `❌ Solicitud cancelada · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "El cliente"} canceló: ${ruta}.`; url = "./index.html#/panel-servicios"; }
      else if (r.estado === "Confirmada" && old.estado === "Cotizada") { ids = dueño; titulo = `✅ Cotización aceptada · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "El cliente"} aceptó${r.precio ? " " + r.precio : ""}: ${ruta}.`; url = "./index.html#/panel-servicios"; }
      else return res.status(200).json({ ok: true, omitido: true });
    }
    else if (r.estado !== old.estado || r.precio !== old.precio || r.respuesta !== old.respuesta) {
      const T = { Cotizada: ["💲 Cotización recibida", `${per.nombre} cotiza${r.precio ? ": " + r.precio : ""}. Toca para aceptarla o cancelar.`],
        Confirmada: ["✅ Viaje confirmado", `${per.nombre} confirmó: ${ruta}.`],
        Cancelada: ["❌ Solicitud cancelada", `${per.nombre} canceló: ${ruta}.`],
        Completada: ["🎉 Viaje completado", `Gracias por viajar con ${per.nombre}.`] }[r.estado];
      if (!T) return res.status(200).json({ ok: true, omitido: true });
      ids = [r.cliente_id]; titulo = `${T[0]} · ${per.nombre}`; cuerpo = T[1] + (r.respuesta ? `\nMensaje: ${r.respuesta}` : ""); url = "./index.html#/mis-servicios";
    } else return res.status(200).json({ ok: true, omitido: true });
  } else {
    if (p.type === "INSERT") { ids = dueño; titulo = `🔎 Nueva consulta de stock · ${per.nombre}`; cuerpo = `${r.cliente_nombre || "Cliente"}: ${String(r.texto || "").slice(0, 140)}${r.foto_url ? "\n📷 Con foto" : ""}\nToca para responder.`; url = "./index.html#/panel-servicios"; }
    else if (r.estado !== old.estado || r.respuesta !== old.respuesta) {
      if (r.estado === "Pendiente") return res.status(200).json({ ok: true, omitido: true });
      const E = { Hay: "✅ ¡Sí lo tienen!", "No hay": "😕 No lo tienen por ahora", Consultar: "ℹ️ Respuesta del comercio" }[r.estado];
      ids = [r.cliente_id]; titulo = `${E} · ${per.nombre}`; cuerpo = [r.precio ? `Precio: ${r.precio}` : null, r.respuesta || null, "Toca para ver la respuesta."].filter(Boolean).join("\n"); url = "./index.html#/mis-servicios";
    } else return res.status(200).json({ ok: true, omitido: true });
  }
  const enviados = await enviar(ids, { titulo, cuerpo, url, tag });
  return res.status(200).json({ ok: true, enviados });
}

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  if (req.headers["authorization"] !== `Bearer ${process.env.WEBHOOK_SECRET}`) return res.status(401).end();
  try {
    const p = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    const ped = p && p.record;
    if (!ped) return res.status(200).json({ ok: true, omitido: true });

    if (p.table === "citas" || p.table === "consultas_stock" || p.table === "viajes") return await servicios(p, res);   // citas y consultas de la sección SERVICIOS

    const old = p.old_record || {};
    let prefijo, ids, cuerpoX, urlX;
    const [com] = await sb(`comercios?id=eq.${encodeURIComponent(ped.comercio_id)}&select=nombre,dueno_id`);
    const admins = await sb("admins?select=user_id");
    const staff = [...new Set([com && com.dueno_id, ...admins.map(a => a.user_id)].filter(Boolean))];
    if (p.type === "INSERT") { prefijo = ped.pago === "en_linea" ? "🛎️ Nuevo pedido (en línea, pago pendiente)" : "🛎️ Nuevo pedido"; ids = staff; }
    else if (p.type === "UPDATE" && ped.pago === "en_linea" && ped.estado_pago === "Pagado" && old.estado_pago !== "Pagado") { prefijo = "💳 Pedido pagado"; ids = staff; }
    else if (p.type === "UPDATE" && ped.recibido_en && !old.recibido_en) { prefijo = "✅ Cliente confirmó recibido"; ids = staff; }
    else if (p.type === "UPDATE" && ped.estado !== old.estado && ped.comprador_id && !(ped.recibido_en && !old.recibido_en)) {
      const T = { "Preparando": ["👨‍🍳 Pedido confirmado", "El comercio confirmó tu pedido y ya lo está preparando. Te avisaremos cuando salga. Toca para ver el seguimiento."],
        "En camino": ["🛵 Tu pedido va en camino", "Tu pedido ya salió y va rumbo a ti. ¡Pronto llegará! Toca para ver el seguimiento."],
        "Entregado": ["📦 Pedido entregado", "Tu pedido fue marcado como entregado. Toca aquí y confirma que lo recibiste con el botón Va, llegó."],
        "Cancelado": ["❌ Pedido cancelado", "El comercio canceló tu pedido. Toca para ver los detalles o comunícate con el comercio."] }[ped.estado];
      if (!T) return res.status(200).json({ ok: true, omitido: true });
      prefijo = T[0]; cuerpoX = T[1]; ids = [ped.comprador_id]; urlX = "./index.html#/pedidos";
    } else return res.status(200).json({ ok: true, omitido: true });

    webpush.setVapidDetails(process.env.VAPID_SUBJECT, process.env.VAPID_PUBLIC_KEY, process.env.VAPID_PRIVATE_KEY);
    if (!ids.length) return res.status(200).json({ ok: true, destinos: 0 });

    const subs = await sb(`push_suscripciones?user_id=in.(${ids.join(",")})&select=endpoint,p256dh,auth`);
    const pago = { efectivo: "Efectivo", transferencia: "Transferencia", en_linea: "Pagado en línea", tarjeta: "Tarjeta" }[ped.pago] || ped.pago;
    const msg = JSON.stringify({
      titulo: `${prefijo} · ${com ? com.nombre : ""}`,
      cuerpo: cuerpoX || [
        `Cliente: ${ped.cliente_nombre || "—"}${ped.cliente_tel ? " · " + ped.cliente_tel : ""}`,
        ...(Array.isArray(ped.lineas) ? ped.lineas.slice(0, 6) : []),
        `Total: $${Number(ped.total).toFixed(2)} · ${pago}`,
        ped.entrega === "domicilio" ? `A domicilio: ${ped.direccion || ""}` : "Recoger en tienda",
        ped.notas ? `Notas: ${ped.notas}` : null,
        "Toca para abrir el pedido y confirmarlo."
      ].filter(Boolean).join("\n"),
      url: urlX || "./index.html#/panel", tag: ped.id + (cuerpoX ? ped.estado : "")
    });

    let enviados = 0;
    await Promise.all(subs.map(async s => {
      try {
        // urgency "high" + TTL: Android en reposo (Doze) entrega al instante y no retrasa el aviso
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, msg, { urgency: "high", TTL: 3600 });
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
