# NOTAS DEL PROYECTO — Valle GO

Guía para retomar el proyecto en una conversación nueva. **Repo público: aquí nunca van contraseñas, llaves ni tokens.**


## ⚡ ORDEN 66 · Paso a Pro, app pública y pruebas reales (guardada el 13 nov 2026)

Cuando el dueño diga **"EJECUTA LA ORDEN 66"**, ya contrató las versiones Pro. Hacer en este orden y avisar el avance:

1. **Respaldo antes de empezar** (flujo "Respaldo Valle GO" en valleGo/valle-go-respaldos, por la API REST de GitHub).
2. **Confirmar los planes Pro** (Supabase y, si aplica, Vercel) con las herramientas de cada servicio.
3. **Supabase Pro:** guiar al dueño para activar la protección contra contraseñas filtradas (Authentication → contraseñas) y confirmar los respaldos diarios. Volver a correr los asesores de seguridad y rendimiento.
4. **Datos de ejemplo:** listar los comercios, menús y pedidos de prueba y **preguntar antes de borrar** cualquiera.
5. **App pública:** preguntar qué falta para "hacerla pública" (dominio propio, quitar protección de Vercel, publicar el enlace, etc.) y hacerlo.
6. **Pruebas reales con el dueño** (con cuentas reales; él hace los pagos, nunca se piden contraseñas ni tarjetas en el chat):
   - pedido en efectivo, por transferencia y una **compra real con Mercado Pago** (pago, aviso al comercio, estado del pedido);
   - **cita** en un comercio del plan SIMPLE: marcarla atendida con el total y revisar el 3%;
   - **consulta de stock → enlace de compra → pedido** (aviso "Ya puedes comprarlo");
   - **viaje** con transportista: cotización, completado y 5%;
   - **avisos al celular** en Android e iPhone;
   - asignar la **promoción de apertura** a un comercio y revisar Membresías (mes gratis y 20%), Cobros 3%, Monitoreo, informes corto y completo, y el corte de transporte.
7. **Repositorio privado:** hacer privado valleGo/valle-go (valle-go-respaldos ya lo es). **Antes**, confirmar que Vercel puede seguir desplegando desde un repositorio privado de la organización (en plan Hobby no se puede; con Vercel Pro sí) y que la app GitHub de Vercel tiene acceso. Después, probar un despliegue y que la app siga en línea. Revisar que el respaldo y la copia a Drive sigan funcionando.
8. **Revisión general** de seguridad (asesores de Supabase, reglas RLS, permisos de funciones, encabezados, secretos fuera del código), funcionamiento (todas las secciones y paneles con datos reales) y fluidez (velocidad de carga y respuesta en celular, tableta y PC).
9. Corregir lo que salga, subir versión, actualizar NOTAS, la ficha legal y los PDFs si cambia algo.
10. **Respaldo final.**

## Qué es
Valle GO ("¡Va, llegó!"): PWA marketplace de comercios locales de Ameca, Jalisco.
- Sitio: https://valle-go.vercel.app
- Repo: GitHub `valleGo/valle-go` (público hasta que el dueño pida lo contrario)
- Vercel: proyecto `prj_5Bah3budYIdeaYH2LVDQc6mId2qE` (equipo `team_2GHG9PQyulE3veCjQzS1vbEr`)
- Supabase: proyecto `mfvyhgyhhqoxfzjjlpvm`

## Modelo de negocio
- **Planes desde v171 (12 nov 2026):** los comercios se dividen en 2 categorías según su plan: **SERVICIOS = plan Simple $299/mes** (agenda y citas, tarjeta en el DIRECTORIO, reporte mensual corto; aquí están también los transportistas) y **PRODUCTOS = plan Básico $549/mes** (todo lo del Simple + página principal, menú, pedidos, consulta de stock, informe mensual completo). IVA incluido. Constantes en `index.html`: `MEM_IVA={simple:299,basico:549}`, `COM_PCT=0.03`, `PROMO_CUPO=20`.
- **Comisión 3%** (sin IVA) de pedidos y citas atendidas en los dos planes (trigger `cita_comision` 0.03; reportes con `COM_PCT`). Transportistas: 5% de viajes en lugar del 3%. Membresía al inicio del mes; comisiones al final. Contratos trimestrales; **si un comercio cancela no hay reembolso ni penalización** (decisión del 12 nov 2026). Nombres oficiales: **plan SIMPLE (servicios)** y **plan BÁSICO (productos)**. Antes de v171: Simple $360, Básico $720, comisión 1%, y el Simple no tenía citas.
- **Promoción de apertura (primeros 20 comercios y transportistas):** columna `promo_inicio` (AAAA-MM del mes gratis) en `comercios` y `servicios_perfiles`; mes gratis y 20% en los meses 2, 3 y 4 (`promoF`, `memMes` en `index.html`). El trigger `promo_cupo` no deja asignar más de 20 y solo el admin la asigna. Membresías, Monitoreo, corte de transporte e informes la aplican.
- **Subcategorías:** `categorias.grupo` = `servicios` o `productos`; el formulario de comercio no deja mezclar plan y subcategoría de otro grupo. El inicio filtra por subcategoría (solo PRODUCTOS). Reclasificados el 12 nov: Estudio de Tatuajes y Masajes El Oasis → Simple; Drink & Fly → Básico.
- **Informes por comercio** (Monitoreo → Compartir): SERVICIOS = reporte corto (6 números + 1 gráfica); PRODUCTOS = informe completo (8 números, 3 gráficas, lo más vendido, entregas, día con más pedidos, servicio más agendado; `datosInformeCom`).
- Transportistas (categoría SERVICIOS): membresía Simple $299/mes + comisión de viajes completados (sin IVA), en un corte mensual: **la membresía se paga al inicio del mes y la comisión al final** (v167). **5% desde el 11 nov (v164)**: trigger `viaje_comision` (`round(precio_num*0.05,2)`, respaldo en `schema-transporte.sql`), `COM_TR=0.05` y textos del corte en `index.html`. Viaje típico en Ameca: $30–$50 (promedio $40 → $2 de comisión). El descuento directo por Mercado Pago **aún no está construido**.
- **INFO_PLAN-Valle-GO.pdf** (12 nov, 3 págs., para comercios): versión resumida y sencilla solo con lo actual: qué es Valle GO, plan SIMPLE (servicios) $299 y plan BÁSICO (productos) $549, comparativa, el 3% (5% transporte), promoción de apertura, contrato trimestral y cancelación sin penalización ni reembolso. Sin segunda/tercera etapa ni planes PLUS/PRO (el dueño los agregará después). Generador en /tmp/pdfs/info_plan.py (no está en el repo).
- PDF comerciales (11 nov; **rehechos el 12 nov con v171: SERVICIOS $299 / PRODUCTOS $549, 3%, promoción de apertura y proyección con la promo**; no están en el repo porque el sitio es público): "COMERCIOS-propuesta-planes" (3 págs.: planes, secciones/directorios y transportistas 5%, cobros con énfasis en que 1% + Mercado Pago es barato vs. apps de reparto de 15–30%) y "ADMIN-cotizacion-y-proyeccion" (5 págs.: mantenimiento $65 USD ≈ $1,219/mes, resumen de planes y directorios, comisiones, proyección y riesgos). Se generan con HTML + Chrome (Inter, mismo diseño que los originales).
- **Pendiente legal:** agregar nombre completo/razón social y domicilio del responsable al Aviso de Privacidad; contratos de comercios y transportistas (se harán en el proyecto de Claude "LEGAL Y CONTRATOS VALLEGO", **ya creado el 12 nov 2026** con sus instrucciones, la ficha legal, el "Registro de documentos legales" y los PDF del Aviso y las Condiciones; siguiente: contrato para transportistas).
- **PDF del negocio (12 nov 2026):** COMERCIOS-propuesta-planes (3 págs., incluye obligaciones según las Condiciones) y ADMIN-cotizacion-y-proyeccion (5 págs., incluye estado legal). Se generan con HTML + Chrome y **no** se guardan en este repo público.
- Pendiente con el contador: tratamiento de IVA del 5% (transporte) y del 3%.

## Archivos
| Archivo | Para qué sirve |
|---|---|
| `index.html` | Toda la app (SPA en JS puro, CSS y JS en línea). ~228 KB |
| `va-check.png` | Palomita del carrito: la V de "Va, llegó" recortada del eslogan |
| `sw.js` | Service worker. Constante `CACHE` (sube con cada versión) y `ESTATICO` (fijo, ver Rendimiento) |
| `config.js` | Configuración pública del cliente (URL y llave pública de Supabase) |
| `manifest.json`, `icon-*.png`, `logo.png`, `marca.png`, `va-llego.png` | PWA e imágenes de marca |
| `api/notificar.js` | Push web: pedidos, citas, consultas de stock y viajes |
| `api/crear-pago.js`, `api/mp-conectar.js`, `api/mp-oauth.js`, `api/mp-webhook.js`, `api/_mp.js` | Mercado Pago |
| `schema*.sql`, `todo-en-uno.sql`, `datos-demo.sql`, `paso-administrador.sql` | Esquema inicial de la base y datos de prueba |
| `schema-transporte.sql` | Trigger `viaje_comision`: 5% de los viajes completados (ya aplicado) |
| `schema-citas-comision.sql` | Columnas `monto`, `comision`, `completado_en`, `mes` en `citas` + trigger `cita_comision` (1% de las citas atendidas) y `limitar_cambios_cita` actualizado (ya aplicado, v169) |
| `schema-planes-2026-11.sql` | v171: citas también en plan Simple (política `crear citas` y trigger `comercio_plan_simple_sin_servicios`), `cita_comision` al 3%, `promo_inicio` + trigger `promo_cupo` (máx. 20), `categorias.grupo`, reclasificación de comercios (ya aplicado) |
| `schema-consulta-compra.sql` | v176: enlace de compra desde consulta de stock: columnas `oferta_*` en `consultas_stock`, `calcular_pedido` acepta items `{cq,cant}`, trigger `oferta_consulta_pedido` (marca usado / libera al cancelar), aviso al cliente (ya aplicado) |
| `schema-seguridad-2026-11-13.sql` | v178: revisión de seguridad (permisos de funciones e índice) (ya aplicado) |
| `schema-vecinos.sql` | Función `contar_vecinos()` (ya aplicada en Supabase) |
| `schema-rendimiento.sql` | Índices de llaves foráneas y RLS optimizado (ya aplicado en Supabase) |
| `schema-rendimiento-2.sql` | Reglas de admin y de "mis datos" limitadas a `authenticated` (ya aplicado; luego reemplazado por el siguiente) |
| `schema-reglas-unificadas.sql` | **Reglas RLS actuales**: una por acción (leer/crear/editar/borrar) en cada tabla (ya aplicado) |
| `vercel.json` | Región de funciones `pdx1` (junto a Supabase us-west-2) y encabezados de caché |
| `privacidad.html` | **Aviso de Privacidad** (v165, 12 nov 2026): simplificado + integral conforme a la LFPDPPP del 20-mar-2025 (art. 15: responsable, datos, sensibles, finalidades con/sin consentimiento, limitar uso, ARCO 20+15 días hábiles, cambios; art. 35: transferencias a comercios/transportistas; proveedores en EE. UU.; respaldos hasta 60 días; almacenamiento local; autoridad: Secretaría Anticorrupción y Buen Gobierno). **Falta nombre y domicilio completo del responsable** (hoy dice "Valle GO, Ameca, Jalisco"). |
| `terminos.html` | **Condiciones del Servicio** (v172, 12 nov 2026: categorías SERVICIOS/PRODUCTOS, 3%, promoción; v167: membresía al inicio del mes, comisiones al final): qué es Valle GO (intermediario), cuenta, pedidos y pagos, **citas** (solicitada → confirmada/reprogramada/cancelada; el cliente acepta la nueva hora), **consultas de stock** (respuesta informativa), **viajes** (cotización o agendado; precio del transportista; responsabilidad del transportista; Valle GO no es empresa de transporte), obligaciones de **comercios y transportistas** (datos de clientes, 1% y 5%, suspensión), uso adecuado, quejas (Profeco), ley de México y tribunales de Jalisco. |
| `generar-llaves-vapid.html` | Herramienta para generar llaves VAPID |

## Regla de versiones (importante)
Cada cambio visible sube la versión en **dos lugares que deben coincidir**:
1. `BUILD` en `index.html` (ej. `valle-go-v145`)
2. `CACHE` en `sw.js`

Versión actual al escribir esto: **v178**.

## Arquitectura de la app
- Rutas por hash en `ruta()`: `#/t/<id>` tienda, `#/cuenta`, `#/panel`, `#/admin`, `#/pedidos`, `#/mis-servicios`, `#/panel-servicios`, y la home por defecto.
- Backend: Supabase (Auth, RLS, RPC, Realtime, Storage). Funciones serverless en Vercel (`api/*.js`).
- Roles: `esAdmin`, `misCom` (comercios del usuario), `misSrv` (servicios/transporte). `pintaHeader()` muestra u oculta los botones según el rol y pone las clases `sinPed` / `sinCarro` en `body`.
- Avisos: triggers de la base llaman a la función `avisar_pedido()` (SECURITY DEFINER) → `/api/notificar` → push web (VAPID).
- Conteo de vecinos: RPC pública `contar_vecinos()` (SECURITY DEFINER, solo devuelve un número) = usuarios de `auth.users` + comercios activos + `servicios_perfiles` activos (se cuentan por separado a propósito, decisión del dueño). Se carga en `cargarDatos()` en la variable `VECINOS`; si falla, la etiqueta muestra solo "Ameca, Jal.".
- Tablas relevantes: pedidos, citas, consultas_stock, `viajes` (tipos cotización/agenda; la comisión del 5% la calcula el trigger `viaje_comision` al pasar a Completada) y `cobros_transporte` (corte mensual).

## Barra superior (header)
- Cuadrícula de 3 áreas: izquierda, centro, derecha.
- Izquierda: botón naranja redondo `#bMenuL` con submenú `.pmenu#popL` (etiqueta "PERFIL:", `#bCuenta`, `#bCont` "REDES VALLE GO").
- Centro: logo + marca.
- Derecha: `#bPanel`, botón amarillo `#bMenuR` con insignia `#bBadge` (sincronizada con `#n`) y submenú `.pmenu#popR` (`#bPedidos`, `#bCarrito`).
- Un submenú abierto es `.hz.open`. Se cierra con clic fuera, al tocar una opción, con Escape y al tocar logo o marca.
- **No usar la clase `pop` para menús**: el JS la agrega al logo y a la marca para la animación de rebote. El submenú usa `.pmenu` (animación `pmIn`).

## Pantalla de inicio
- Título `.htit` en `vistaInicio()`: ícono SVG de valle, "Lugares del **Valle** Hoy" (Valle en verde con resaltado amarillo) y etiqueta `.hts` "● N VECINOS • AMECA, JAL.".
- Logo y eslogan de la barra superior: en el inicio suben la página hasta arriba (suave); en otras rutas llevan al inicio.
- Botón flotante `#bTop` abajo a la izquierda (con márgenes y zona segura): aparece al bajar más de 360 px; su única función es subir. `z-index:3`, queda debajo de los avisos inferiores (`#inst`, `#bnotif`).
  - Con el Directorio abierto (`#dirPanel`, caja con su propio scroll) el botón toma la clase `.dir` (`z-index:5`), aparece al bajar más de 240 px dentro del directorio y sube al principio del directorio sin cerrarlo. Los clics en `#bTop` están excluidos del "clic fuera cierra la capa".

## Rendimiento (v152)
- **Arranque:** `datosLocales()` pinta al instante la última copia guardada (`localStorage` `valle_datos_v1`); `cargarDatos()` corre en paralelo con la sesión y hace sus 4 consultas a la vez (`Promise.all`), luego guarda la copia. Con base de datos nunca se muestran los comercios de ejemplo; en la primera visita salen tarjetas de carga (`.card.skel`, variable `datosListos`). El carrito solo se vacía si los datos se confirmaron (`cargarDatos()` devuelve `true`).
- **Menús bajo demanda (v153):** `cargarDatos()` trae los comercios sin `menu_items`; cada menú se descarga con `cargarMenu(id)` solo al abrir la tienda (o al pintar el carrito de esa tienda) y se guarda en la copia local. `t.menu===null` = aún no cargado ("Cargando menú…"). Se refresca una vez por sesión por tienda (`menuFresco`; se limpia en cada `cargarDatos()`, p. ej. tras editar menús en el panel). Si falla, espera 10 s antes de reintentar (`reintento`, `t._mErr`). El carrito quita solo los platillos que ya no están disponibles.
- **Service worker:** HTML/JS/JSON propios = red primero (si al abrir la red tarda más de 4 s, usa la copia). Imágenes propias, librería de Supabase (jsdelivr) y fuente = copia al instante + actualización en segundo plano, en el caché fijo `ESTATICO` (`valle-go-estatico-v1`), que no se borra con cada versión. `/api/*` y Supabase no pasan por el service worker. Precarga solo lo mínimo (sin `icon-512`).
- **Fuente:** Montserrat se carga sin bloquear el primer pintado (`preload` + `onload`). Hay `preconnect` a Supabase.
- **Imágenes:** logo, marca e íconos reducidos a 256 colores (visualmente iguales, ~50–80 % más ligeros). Si se reemplaza una imagen, conservar el nombre o subir `ESTATICO`.
- **Reglas unificadas (11 nov):** cada tabla tiene UNA regla por acción: "leer X", "crear X", "editar X", "borrar X", que junta con OR las condiciones de antes (admin, dueño, cliente, público). Se verificó con una prueba de "huella" (qué ve/edita/borra cada usuario en cada tabla, con datos de prueba, antes vs. después): 0 diferencias. Excepciones con una sola regla de siempre: `admins`, `cobros_pagos`, `gastos`, `push_suscripciones`. **Al agregar permisos, editar la regla existente de esa acción (añadir `or ...`) en lugar de crear otra.** Las funciones `admin_*` y `usuario_por_correo` verifican `es_admin()` por dentro (los avisos de Supabase sobre ellas son esperados).
- **Base de datos:** índices en todas las llaves foráneas; en las reglas RLS `auth.uid()` y `es_admin()` van como `(select ...)` para evaluarse una vez por consulta. **Al crear reglas nuevas, escribirlas así**, y si solo aplican con sesión (admin, dueño, comprador), ponerles `to authenticated` para que no se evalúen en las consultas de visitantes.
- **Vercel:** funciones en `pdx1`; imágenes con caché de 1 día + 7 días de revalidación.
- Medido con red simulada (400 ms por consulta): comercios visibles en ~0.5 s la 1a visita y ~0.1 s las siguientes (antes ~2.1 s siempre).

## Respaldos (12 nov 2026)
- Repositorio **privado** `valleGo/valle-go-respaldos` con la tarea *Respaldo Valle GO (cada 15 días)* (`.github/workflows/respaldo.yml`): días 1 y 16 de cada mes, 3:23 a. m. (09:23 UTC), guarda en **Releases** código con historial (`git bundle`), base completa (`supabase db dump`: roles, estructura, datos; más `auth.users`/`auth.identities` aparte), resumen de filas y fotos del bucket `fotos`. **Solo conserva los 2 respaldos más recientes** (borra los viejos con `gh release delete --cleanup-tag`). Si falla, GitHub manda correo.
- Necesita el secreto `SUPABASE_DB_URL` (cadena **Session pooler** de Supabase con la contraseña de la base). Claude no puede ver secretos ni correr Actions desde la sesión (el proxy lo bloquea): el dueño lo corre en *Actions → Run workflow*.
- Copia a Google Drive: script `drive-sync.gs` (Apps Script en la cuenta de Google del dueño, disparador diario 5 a. m.) baja de *Releases* con un token de GitHub de solo lectura (propiedad `GITHUB_TOKEN`) y deja solo 2 en la carpeta "Respaldos Valle GO". No se usó rclone porque su acceso compartido a Drive se retira en 2026. **Activo desde el 12 nov 2026** (proyecto de Apps Script "drive-sync.gs" en la cuenta de Google del dueño; token fine-grained "Respaldos a Drive", Contents read-only, sin vencimiento). Primer respaldo verificado: código (213 versiones), 18 tablas, 48 reglas, 20 funciones, 3 usuarios, 40/40 fotos, 3.2 MB.
- Instrucciones de restauración en `RESTAURAR.md` de ese repo. Las claves de Vercel (MP, VAPID, Supabase service key) **no** se respaldan ahí: el dueño las guarda en un gestor de contraseñas.
- **Nunca** subir respaldos al repo `valle-go`: es **público**.
- Capas: GitHub (código e historial) + Vercel (cada despliegue, rollback) + respaldo privado cada 15 días (máx. 2) + Supabase Pro (respaldos diarios de 7 días al activarlo) + copia descargada por el dueño a su computadora/Drive.

## Cómo probar
- Playwright local bloqueando hosts externos. Para probar el service worker y la carga de datos: servir con `python3 -m http.server` en 127.0.0.1 y simular `supabase-js` con un cliente falso con retraso.
- El carrito está dentro del menú de la bolsa (`#bMenuR` abre `#popR`); a admin y comerciantes se les oculta (`body.sinCarro`).
- Esperar ~4.5 s tras cargar; luego `sesion={id:'u',nombre:'Ana',email:'a@x.com'}` (opcional `esAdmin=true`) y llamar `pintaHeader()`.
- Revisión de sintaxis: ejecutar `new Function(...)` sobre los scripts en línea.
- Probar en iPhone, Android, PC y tableta antes de dar algo por terminado.

## Cómo subir cambios
- `git push -q origin HEAD:main`; Vercel despliega solo.
- Cada commit termina con las líneas de coautoría y sesión que indique el sistema.

## Secretos (NO van en el repo)
Los captura el dueño directamente en Vercel o Supabase: Client Secret y Access Token de producción de Mercado Pago, `WEBHOOK_SECRET`, llave privada VAPID y el secreto Bearer de `avisar_pedido`. Nunca pegarlos en el chat ni en archivos.

## Reglas acordadas
- **Siempre actualizar todo** con cada cambio publicado: versión (`BUILD` y `CACHE`), este `NOTAS.md` (versión actual, secciones afectadas e historial) y los `.sql` del repo si se toca la base.
- Hablar siempre en español con el dueño.
- No dar permisos de administrador a cuentas sin confirmar. Admin: la cuenta del dueño.
- El repo sigue público hasta que el dueño pida privatizarlo.

## Historial reciente
- v146: título de inicio rediseñado. v147–v148: etiqueta "vecinos" con conteo general. v149: logo y eslogan suben la página. v150: botón flotante para subir. v151: el botón también funciona dentro del Directorio. v152: optimización de velocidad (arranque en paralelo, copia local, caché, imágenes, índices y RLS). v153: menús bajo demanda. v154: barra superior más transparente (degradado del `header` en la regla de "3 zonas": blanco .35 → verde claro 15 %). v155: aún más transparente (blanco .15 → verde claro 6 %). v156: desenfoque de la barra de 14 px a 7 px (el contenido se intuye debajo, sin verse nítido). Revisión general (11 nov): todas las pantallas sin errores en celular, tableta y PC; reglas de la base limitadas a usuarios con sesión (`schema-rendimiento-2.sql`) y luego unificadas, una por acción (`schema-reglas-unificadas.sql`). v157: carrito compacto (estilos `#cCarrito` al final del primer `<style>`): tarjeta flotante de 380 px en PC, hoja inferior con agarradera en celular (≤600 px), campos más compactos, Calle y Número en una fila, totales en recuadro y "Confirmar pedido" fijo abajo. Solo CSS. v158: el carrito se abre como ventana desplegable justo debajo del botón de la bolsa (`posCarrito()` mide `#bMenuR` y fija `--carT/--carR/--carF`; flechita con `#pCarrito::after`), alto máx. 600 px con desplazamiento interno, igual en celular y PC. Se cierra con clic fuera del recuadro (incluida la bolsa), la ✕, Esc o Atrás. v159: `reboteBolsa()` en `agregar()` hace rebotar `#bMenuR` y su numerito `#bBadge` (solo al agregar desde la tienda, no con +/− del carrito); ✕, + y − del carrito dibujados con CSS (`font-size:0` + `::before/::after`), + verde relleno y − en contorno dentro de una cápsula, con `aria-label`. v160: + y − ya no redibujan todo el carrito: `cambia()` → `actualizaLinea()` cambia solo el número, `#csub`, envío/total y quita la línea al llegar a 0 (redibuja completo solo si queda vacío o no encuentra la línea); los totales y "Confirmar" calculan `subtotal(t)` al momento. `touch-action:manipulation` en botones/enlaces para que los toques rápidos no se tomen como doble toque de zoom (iPhone). v161: en la lista del carrito el emoji se reemplazó por una palomita `.vchk` = la V del eslogan recortada de `marca.png` (solo el trazo conectado de la V, engrosado, verde de marca) en `va-check.png`, con efecto de trazo al abrir. v162: carrito vacío dice "agrega productos" (antes "platillos"). v163: "platillo(s)" → "producto(s)" en toda la app; trazo de la palomita más lento y orgánico (1.4 s, máscara con borde suave que avanza como pluma, 0.25 s de espera y 0.22 s entre cada producto vía `--i`). v164: comisión de transporte 5% (antes 7%) en la base y en la app. v166: Condiciones del Servicio con citas, consultas de stock, viajes y obligaciones de comercios y transportistas. v165: Aviso de Privacidad completo y actualizado (`privacidad.html`), aviso simplificado (`.avPriv`) en el registro con correo y con Google, enlaces renombrados a "Aviso de Privacidad". v167: Condiciones y textos del corte de transporte: membresía se paga al inicio del mes y comisiones al final. v168: Condiciones punto 7: "1% de pedidos y citas atendidas" . v169: el 1% ya incluye citas atendidas: al marcar una cita como Completada el comercio escribe el total cobrado (se sugiere el precio del servicio); trigger `cita_comision` calcula 1% y mes; Monitoreo, Cobros 1% (tabla, CSV, PDF), informe por comercio y texto del panel suman las citas. v170: Aviso de Privacidad, datos de citas incluye "el total cobrado". v171: planes SERVICIOS (Simple $299) y PRODUCTOS (Básico $549), 3% en ambos planes, promoción de apertura (20), subcategorías por grupo, Simple con citas y botón "Agendar cita" en los perfiles, informes corto/completo, formularios de admin actualizados. v172: Condiciones del Servicio con las dos categorías, el 3%, contratos trimestrales y la promoción. v173: nombres oficiales "plan SIMPLE (servicios)" y "plan BÁSICO (productos)" en la app y documentos; Condiciones: el comercio puede cancelar cuando quiera, sin penalización ni reembolso (las comisiones ya generadas se pagan). v174: Aviso de Privacidad, sección 4: comisiones "3% de los pedidos y de las citas atendidas, y 5% de los viajes completados" (antes decía 1%). v175: Condiciones sección 7: contratos trimestrales que solo se renuevan por 3 meses con membresía mensual, **3 días de tolerancia** para pagar membresía y comisiones (después se puede suspender el perfil), comisión sobre todos los pedidos y citas sin importar la forma de pago, cambios de precios por la administración; texto de la promoción ajustado. v176: **enlace de compra desde consulta de stock**: con la consulta en "Hay", el comercio crea un enlace (producto, precio por pieza, piezas) desde su panel; el cliente recibe aviso "🛒 Ya puedes comprarlo" y en Mis solicitudes tiene "Comprar ahora" (ruta `#/compra/<consulta>`), que abre el carrito con ese producto (`cq:<id>` en `carrito.ofertas`); el pedido es normal (3%, efectivo/transferencia/Mercado Pago). La BD pone el precio (`calcular_pedido` con items `{cq,cant}`), solo para el cliente de la consulta, un solo uso (`oferta_pedido_id`), se libera si el pedido se cancela. `api/crear-pago.js` y `api/notificar.js` actualizados. SQL: `schema-consulta-compra.sql`. También: Mis solicitudes muestra el nombre del comercio en citas y consultas (antes salía vacío). v177: Condiciones sección 5: "Si el comercio te envía un enlace de compra, ese precio es el que pagas y la compra se hace como un pedido normal." v178 (13 nov, revisión general): **corregido** "Mis solicitudes" del cliente: citas y consultas pedían `servicios_perfiles(...)` pero su relación es con `comercios` (la consulta fallaba y no mostraba nada); seguridad: sin `EXECUTE` a funciones de trigger y funciones de admin sin acceso anónimo (`schema-seguridad-2026-11-13.sql`), índice de `oferta_pedido_id`, encabezados de seguridad en `vercel.json` (nosniff, Referrer-Policy, no se puede incrustar en iframes, Permissions-Policy) y `/api` sin caché. Probado en celular chico (360), celular (390), tableta (820 y 1180) y PC (1440): sin errores ni desbordes; carga < 1 s.

## Pendientes
- **Siguiente paso del dueño (12 nov 2026):** cuando contrate las versiones Pro, hacer las pruebas reales. Lista: (1) Supabase Pro → activar contraseñas filtradas y confirmar respaldos diarios; (2) compra real con Mercado Pago (pago, aviso al comercio y estado del pedido); (3) un pedido, una cita, una consulta y un viaje de punta a punta con cuentas reales, incluidos los avisos al celular; (4) revisar que el corte del mes muestre la membresía al inicio y la comisión al final.
- Compra real de prueba con Mercado Pago (la hace el dueño).
- Pasar Supabase a Pro antes de cobrar a clientes reales (y entonces activar la protección de contraseñas filtradas).
- Consultar al contador sobre el IVA.
- Al pasar Supabase a Pro: activar "Prevent use of leaked passwords" (Authentication → contraseñas). Solo existe en Pro o superior; en el plan gratuito no se puede.
- Opcionales: descuento directo del 5% por Mercado Pago a transportistas; integrar el corte de transporte en Monitoreo/Cobros/Membresías/PDF/IVA; ocultar el teléfono del cliente al transportista; lista fija de colonias de Ameca.
