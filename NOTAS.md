# NOTAS DEL PROYECTO — Valle GO

Guía para retomar el proyecto en una conversación nueva. **Repo público: aquí nunca van contraseñas, llaves ni tokens.**

## Qué es
Valle GO ("¡Va, llegó!"): PWA marketplace de comercios locales de Ameca, Jalisco.
- Sitio: https://valle-go.vercel.app
- Repo: GitHub `valleGo/valle-go` (público hasta que el dueño pida lo contrario)
- Vercel: proyecto `prj_5Bah3budYIdeaYH2LVDQc6mId2qE` (equipo `team_2GHG9PQyulE3veCjQzS1vbEr`)
- Supabase: proyecto `mfvyhgyhhqoxfzjjlpvm`

## Modelo de negocio
- Comisión del 1% por pedido (sin IVA).
- Membresías: Simple $12/día = $360/mes; Básico $24/día = $720/mes (IVA incluido). Los precios no cambian.
- Transportistas: membresía Simple $360/mes + comisión de viajes completados (sin IVA), cobrada en un corte mensual. **5% desde el 11 nov (v164)**: trigger `viaje_comision` (`round(precio_num*0.05,2)`, respaldo en `schema-transporte.sql`), `COM_TR=0.05` y textos del corte en `index.html`. Viaje típico en Ameca: $30–$50 (promedio $40 → $2 de comisión). El descuento directo por Mercado Pago **aún no está construido**.
- PDF comerciales (11 nov, no están en el repo porque el sitio es público): "COMERCIOS-propuesta-planes" (3 págs.: planes, secciones/directorios y transportistas 5%, cobros con énfasis en que 1% + Mercado Pago es barato vs. apps de reparto de 15–30%) y "ADMIN-cotizacion-y-proyeccion" (5 págs.: mantenimiento $65 USD ≈ $1,219/mes, resumen de planes y directorios, comisiones, proyección y riesgos). Se generan con HTML + Chrome (Inter, mismo diseño que los originales).
- **Pendiente legal:** agregar nombre completo/razón social y domicilio del responsable al Aviso de Privacidad; actualizar `terminos.html`; contratos de comercios y transportistas (se harán en el proyecto de Claude "LEGAL Y CONTRATOS VALLEGO", con la ficha `legal/Ficha-Valle-GO-para-documentos-legales.md`).
- Pendiente con el contador: tratamiento de IVA del 5% (transporte) y del 1%.

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
| `schema-vecinos.sql` | Función `contar_vecinos()` (ya aplicada en Supabase) |
| `schema-rendimiento.sql` | Índices de llaves foráneas y RLS optimizado (ya aplicado en Supabase) |
| `schema-rendimiento-2.sql` | Reglas de admin y de "mis datos" limitadas a `authenticated` (ya aplicado; luego reemplazado por el siguiente) |
| `schema-reglas-unificadas.sql` | **Reglas RLS actuales**: una por acción (leer/crear/editar/borrar) en cada tabla (ya aplicado) |
| `vercel.json` | Región de funciones `pdx1` (junto a Supabase us-west-2) y encabezados de caché |
| `privacidad.html` | **Aviso de Privacidad** (v165, 12 nov 2026): simplificado + integral conforme a la LFPDPPP del 20-mar-2025 (art. 15: responsable, datos, sensibles, finalidades con/sin consentimiento, limitar uso, ARCO 20+15 días hábiles, cambios; art. 35: transferencias a comercios/transportistas; proveedores en EE. UU.; respaldos hasta 60 días; almacenamiento local; autoridad: Secretaría Anticorrupción y Buen Gobierno). **Falta nombre y domicilio completo del responsable** (hoy dice "Valle GO, Ameca, Jalisco"). |
| `terminos.html` | Condiciones del Servicio (9 nov 2026; pendiente actualizar con citas, consultas, viajes y transportistas) |
| `generar-llaves-vapid.html` | Herramienta para generar llaves VAPID |

## Regla de versiones (importante)
Cada cambio visible sube la versión en **dos lugares que deben coincidir**:
1. `BUILD` en `index.html` (ej. `valle-go-v145`)
2. `CACHE` en `sw.js`

Versión actual al escribir esto: **v165**.

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
- v146: título de inicio rediseñado. v147–v148: etiqueta "vecinos" con conteo general. v149: logo y eslogan suben la página. v150: botón flotante para subir. v151: el botón también funciona dentro del Directorio. v152: optimización de velocidad (arranque en paralelo, copia local, caché, imágenes, índices y RLS). v153: menús bajo demanda. v154: barra superior más transparente (degradado del `header` en la regla de "3 zonas": blanco .35 → verde claro 15 %). v155: aún más transparente (blanco .15 → verde claro 6 %). v156: desenfoque de la barra de 14 px a 7 px (el contenido se intuye debajo, sin verse nítido). Revisión general (11 nov): todas las pantallas sin errores en celular, tableta y PC; reglas de la base limitadas a usuarios con sesión (`schema-rendimiento-2.sql`) y luego unificadas, una por acción (`schema-reglas-unificadas.sql`). v157: carrito compacto (estilos `#cCarrito` al final del primer `<style>`): tarjeta flotante de 380 px en PC, hoja inferior con agarradera en celular (≤600 px), campos más compactos, Calle y Número en una fila, totales en recuadro y "Confirmar pedido" fijo abajo. Solo CSS. v158: el carrito se abre como ventana desplegable justo debajo del botón de la bolsa (`posCarrito()` mide `#bMenuR` y fija `--carT/--carR/--carF`; flechita con `#pCarrito::after`), alto máx. 600 px con desplazamiento interno, igual en celular y PC. Se cierra con clic fuera del recuadro (incluida la bolsa), la ✕, Esc o Atrás. v159: `reboteBolsa()` en `agregar()` hace rebotar `#bMenuR` y su numerito `#bBadge` (solo al agregar desde la tienda, no con +/− del carrito); ✕, + y − del carrito dibujados con CSS (`font-size:0` + `::before/::after`), + verde relleno y − en contorno dentro de una cápsula, con `aria-label`. v160: + y − ya no redibujan todo el carrito: `cambia()` → `actualizaLinea()` cambia solo el número, `#csub`, envío/total y quita la línea al llegar a 0 (redibuja completo solo si queda vacío o no encuentra la línea); los totales y "Confirmar" calculan `subtotal(t)` al momento. `touch-action:manipulation` en botones/enlaces para que los toques rápidos no se tomen como doble toque de zoom (iPhone). v161: en la lista del carrito el emoji se reemplazó por una palomita `.vchk` = la V del eslogan recortada de `marca.png` (solo el trazo conectado de la V, engrosado, verde de marca) en `va-check.png`, con efecto de trazo al abrir. v162: carrito vacío dice "agrega productos" (antes "platillos"). v163: "platillo(s)" → "producto(s)" en toda la app; trazo de la palomita más lento y orgánico (1.4 s, máscara con borde suave que avanza como pluma, 0.25 s de espera y 0.22 s entre cada producto vía `--i`). v164: comisión de transporte 5% (antes 7%) en la base y en la app. v165: Aviso de Privacidad completo y actualizado (`privacidad.html`), aviso simplificado (`.avPriv`) en el registro con correo y con Google, enlaces renombrados a "Aviso de Privacidad".

## Pendientes
- Compra real de prueba con Mercado Pago (la hace el dueño).
- Pasar Supabase a Pro antes de cobrar a clientes reales (y entonces activar la protección de contraseñas filtradas).
- Consultar al contador sobre el IVA.
- Al pasar Supabase a Pro: activar "Prevent use of leaked passwords" (Authentication → contraseñas). Solo existe en Pro o superior; en el plan gratuito no se puede.
- Opcionales: descuento directo del 5% por Mercado Pago a transportistas; integrar el corte de transporte en Monitoreo/Cobros/Membresías/PDF/IVA; ocultar el teléfono del cliente al transportista; lista fija de colonias de Ameca.
