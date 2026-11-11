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
| `sw.js` | Service worker, red primero. Constante `CACHE` |
| `config.js` | Configuración pública del cliente (URL y llave pública de Supabase) |
| `manifest.json`, `icon-*.png`, `logo.png`, `marca.png`, `va-llego.png` | PWA e imágenes de marca |
| `api/notificar.js` | Push web: pedidos, citas, consultas de stock y viajes |
| `api/crear-pago.js`, `api/mp-conectar.js`, `api/mp-oauth.js`, `api/mp-webhook.js`, `api/_mp.js` | Mercado Pago |
| `schema*.sql`, `todo-en-uno.sql`, `datos-demo.sql`, `paso-administrador.sql` | Esquema inicial de la base y datos de prueba |
| `terminos.html`, `privacidad.html` | Legales |
| `generar-llaves-vapid.html` | Herramienta para generar llaves VAPID |

## Regla de versiones (importante)
Cada cambio visible sube la versión en **dos lugares que deben coincidir**:
1. `BUILD` en `index.html` (ej. `valle-go-v145`)
2. `CACHE` en `sw.js`

Versión actual al escribir esto: **v145**.

## Arquitectura de la app
- Rutas por hash en `ruta()`: `#/t/<id>` tienda, `#/cuenta`, `#/panel`, `#/admin`, `#/pedidos`, `#/mis-servicios`, `#/panel-servicios`, y la home por defecto.
- Backend: Supabase (Auth, RLS, RPC, Realtime, Storage). Funciones serverless en Vercel (`api/*.js`).
- Roles: `esAdmin`, `misCom` (comercios del usuario), `misSrv` (servicios/transporte). `pintaHeader()` muestra u oculta los botones según el rol y pone las clases `sinPed` / `sinCarro` en `body`.
- Avisos: triggers de la base llaman a la función `avisar_pedido()` (SECURITY DEFINER) → `/api/notificar` → push web (VAPID).
- Tablas relevantes: pedidos, citas, consultas_stock, `viajes` (tipos cotización/agenda; la comisión del 7% la calcula un trigger al pasar a Completada) y `cobros_transporte` (corte mensual).

## Barra superior (header)
- Cuadrícula de 3 áreas: izquierda, centro, derecha.
- Izquierda: botón naranja redondo `#bMenuL` con submenú `.pmenu#popL` (etiqueta "PERFIL:", `#bCuenta`, `#bCont` "REDES VALLE GO").
- Centro: logo + marca.
- Derecha: `#bPanel`, botón amarillo `#bMenuR` con insignia `#bBadge` (sincronizada con `#n`) y submenú `.pmenu#popR` (`#bPedidos`, `#bCarrito`).
- Un submenú abierto es `.hz.open`. Se cierra con clic fuera, al tocar una opción, con Escape y al tocar logo o marca.
- **No usar la clase `pop` para menús**: el JS la agrega al logo y a la marca para la animación de rebote. El submenú usa `.pmenu` (animación `pmIn`).

## Cómo probar
- Playwright local bloqueando hosts externos. Esperar ~4.5 s tras cargar; luego `sesion={id:'u',nombre:'Ana',email:'a@x.com'}` (opcional `esAdmin=true`) y llamar `pintaHeader()`.
- Revisión de sintaxis: ejecutar `new Function(...)` sobre los scripts en línea.
- Probar en iPhone, Android, PC y tableta antes de dar algo por terminado.

## Cómo subir cambios
- `git push -q origin HEAD:main`; Vercel despliega solo.
- Cada commit termina con las líneas de coautoría y sesión que indique el sistema.

## Secretos (NO van en el repo)
Los captura el dueño directamente en Vercel o Supabase: Client Secret y Access Token de producción de Mercado Pago, `WEBHOOK_SECRET`, llave privada VAPID y el secreto Bearer de `avisar_pedido`. Nunca pegarlos en el chat ni en archivos.

## Reglas acordadas
- No dar permisos de administrador a cuentas sin confirmar. Admin: la cuenta del dueño.
- El repo sigue público hasta que el dueño pida privatizarlo.

## Pendientes
- Compra real de prueba con Mercado Pago (la hace el dueño).
- Pasar Supabase a Pro antes de cobrar a clientes reales.
- Consultar al contador sobre el IVA.
- Opcionales: descuento directo del 7% por Mercado Pago a transportistas; integrar el corte de transporte en Monitoreo/Cobros/Membresías/PDF/IVA; ocultar el teléfono del cliente al transportista; lista fija de colonias de Ameca.
