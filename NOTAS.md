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
- Transportistas: membresía Simple $360/mes + 7% del total de viajes completados (sin IVA), cobrado en un corte mensual. El descuento directo por Mercado Pago **aún no está construido**.
- Pendiente con el contador: tratamiento de IVA del 7% y del 1%.

## Archivos
| Archivo | Para qué sirve |
|---|---|
| `index.html` | Toda la app (SPA en JS puro, CSS y JS en línea). ~228 KB |
| `sw.js` | Service worker. Constante `CACHE` (sube con cada versión) y `ESTATICO` (fijo, ver Rendimiento) |
| `config.js` | Configuración pública del cliente (URL y llave pública de Supabase) |
| `manifest.json`, `icon-*.png`, `logo.png`, `marca.png`, `va-llego.png` | PWA e imágenes de marca |
| `api/notificar.js` | Push web: pedidos, citas, consultas de stock y viajes |
| `api/crear-pago.js`, `api/mp-conectar.js`, `api/mp-oauth.js`, `api/mp-webhook.js`, `api/_mp.js` | Mercado Pago |
| `schema*.sql`, `todo-en-uno.sql`, `datos-demo.sql`, `paso-administrador.sql` | Esquema inicial de la base y datos de prueba |
| `schema-vecinos.sql` | Función `contar_vecinos()` (ya aplicada en Supabase) |
| `schema-rendimiento.sql` | Índices de llaves foráneas y RLS optimizado (ya aplicado en Supabase) |
| `vercel.json` | Región de funciones `pdx1` (junto a Supabase us-west-2) y encabezados de caché |
| `terminos.html`, `privacidad.html` | Legales |
| `generar-llaves-vapid.html` | Herramienta para generar llaves VAPID |

## Regla de versiones (importante)
Cada cambio visible sube la versión en **dos lugares que deben coincidir**:
1. `BUILD` en `index.html` (ej. `valle-go-v145`)
2. `CACHE` en `sw.js`

Versión actual al escribir esto: **v152**.

## Arquitectura de la app
- Rutas por hash en `ruta()`: `#/t/<id>` tienda, `#/cuenta`, `#/panel`, `#/admin`, `#/pedidos`, `#/mis-servicios`, `#/panel-servicios`, y la home por defecto.
- Backend: Supabase (Auth, RLS, RPC, Realtime, Storage). Funciones serverless en Vercel (`api/*.js`).
- Roles: `esAdmin`, `misCom` (comercios del usuario), `misSrv` (servicios/transporte). `pintaHeader()` muestra u oculta los botones según el rol y pone las clases `sinPed` / `sinCarro` en `body`.
- Avisos: triggers de la base llaman a la función `avisar_pedido()` (SECURITY DEFINER) → `/api/notificar` → push web (VAPID).
- Conteo de vecinos: RPC pública `contar_vecinos()` (SECURITY DEFINER, solo devuelve un número) = usuarios de `auth.users` + comercios activos + `servicios_perfiles` activos (se cuentan por separado a propósito, decisión del dueño). Se carga en `cargarDatos()` en la variable `VECINOS`; si falla, la etiqueta muestra solo "Ameca, Jal.".
- Tablas relevantes: pedidos, citas, consultas_stock, `viajes` (tipos cotización/agenda; la comisión del 7% la calcula un trigger al pasar a Completada) y `cobros_transporte` (corte mensual).

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
- **Service worker:** HTML/JS/JSON propios = red primero (si al abrir la red tarda más de 4 s, usa la copia). Imágenes propias, librería de Supabase (jsdelivr) y fuente = copia al instante + actualización en segundo plano, en el caché fijo `ESTATICO` (`valle-go-estatico-v1`), que no se borra con cada versión. `/api/*` y Supabase no pasan por el service worker. Precarga solo lo mínimo (sin `icon-512`).
- **Fuente:** Montserrat se carga sin bloquear el primer pintado (`preload` + `onload`). Hay `preconnect` a Supabase.
- **Imágenes:** logo, marca e íconos reducidos a 256 colores (visualmente iguales, ~50–80 % más ligeros). Si se reemplaza una imagen, conservar el nombre o subir `ESTATICO`.
- **Base de datos:** índices en todas las llaves foráneas; en las reglas RLS `auth.uid()` y `es_admin()` van como `(select ...)` para evaluarse una vez por consulta. **Al crear reglas nuevas, escribirlas así.**
- **Vercel:** funciones en `pdx1`; imágenes con caché de 1 día + 7 días de revalidación.
- Medido con red simulada (400 ms por consulta): comercios visibles en ~0.5 s la 1a visita y ~0.1 s las siguientes (antes ~2.1 s siempre).

## Cómo probar
- Playwright local bloqueando hosts externos. Para probar el service worker y la carga de datos: servir con `python3 -m http.server` en 127.0.0.1 y simular `supabase-js` con un cliente falso con retraso.
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
- v146: título de inicio rediseñado. v147–v148: etiqueta "vecinos" con conteo general. v149: logo y eslogan suben la página. v150: botón flotante para subir. v151: el botón también funciona dentro del Directorio. v152: optimización de velocidad (arranque en paralelo, copia local, caché, imágenes, índices y RLS).

## Pendientes
- Compra real de prueba con Mercado Pago (la hace el dueño).
- Pasar Supabase a Pro antes de cobrar a clientes reales.
- Consultar al contador sobre el IVA.
- Seguridad sugerida (no urgente): activar "Leaked password protection" en Supabase Auth.
- Si crecen mucho los comercios: cargar los menús (`menu_items`) solo al abrir cada tienda, no todos al inicio.
- Opcionales: descuento directo del 7% por Mercado Pago a transportistas; integrar el corte de transporte en Monitoreo/Cobros/Membresías/PDF/IVA; ocultar el teléfono del cliente al transportista; lista fija de colonias de Ameca.
