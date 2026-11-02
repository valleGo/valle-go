# Valle GO · Guía completa (GitHub + Vercel + Supabase)

## 1. Qué hace cada servicio
- **GitHub** guarda tu código. Cada cambio que hagas ahí se publica solo.
- **Vercel** publica la página (con HTTPS, necesario para instalarla como app) y ejecuta una pequeña función que envía las notificaciones.
- **Supabase** guarda las cuentas, comercios, menús, pedidos, publicidad y fotos.

## 2. Estructura del proyecto
```
valle-go/
├─ public/                      ← lo que ven los clientes (la app)
│  ├─ index.html                   toda la aplicación
│  ├─ config.js                    TUS llaves públicas (lo único que editas para conectar)
│  ├─ sw.js, manifest.json         instalación y notificaciones
│  └─ icon-*.png, icon.svg         íconos
├─ api/                         ← funciones de Vercel
│  ├─ notificar.js                 envía las notificaciones
│  ├─ crear-pago.js                abre la página de pago de Stripe
│  └─ stripe-webhook.js            Stripe avisa aquí que el pago se hizo
├─ supabase/                    ← la base de datos (se pega en Supabase, no se sube a ningún lado)
│  ├─ schema.sql, schema-panel.sql, schema-notificaciones.sql, schema-pagos.sql
├─ herramientas/generar-llaves-vapid.html   ← se abre en tu computadora (no se publica)
├─ package.json, vercel.json    ← configuración de Vercel
└─ .gitignore
```

## 3. Paso a paso

### Paso 1 · Supabase (base de datos)
1. En supabase.com crea una cuenta y un proyecto "valle-go". Anota la contraseña de la base de datos.
2. **SQL Editor → New query.** Pega y ejecuta (Run), uno por uno y en este orden: `supabase/schema.sql`, `supabase/schema-panel.sql` (sin ejecutar todavía su última línea, la de `admins`), `supabase/schema-notificaciones.sql` y `supabase/schema-pagos.sql`.
3. **Project Settings → API:** copia el **Project URL** y la llave **anon** (en el panel nuevo puede llamarse *publishable key*). Copia también la llave **service_role** (puede llamarse *secret key*): esa es SECRETA, solo irá en Vercel.
4. **Authentication → Providers → Email:** desactiva "Confirm email" mientras pruebas.

### Paso 2 · Llaves de notificaciones
Abre en tu computadora (doble clic, en Chrome) `herramientas/generar-llaves-vapid.html` y pulsa **Generar llaves**. Copia la pública y la privada a un bloc de notas. La privada no se comparte ni se sube a GitHub.
También inventa una **clave secreta larga** (por ejemplo 30 letras y números al azar): será el `WEBHOOK_SECRET`.

### Paso 3 · GitHub
1. Crea cuenta en github.com → **New repository** → nombre `valle-go` → créalo **Private** (privado).
2. Pulsa **uploading an existing file** y arrastra TODO el contenido de la carpeta (las carpetas `public`, `api`, `supabase`, `herramientas` y los archivos sueltos). Pulsa **Commit changes**.
3. Para ver `.gitignore`: si no se sube por ser archivo oculto, no pasa nada.

### Paso 4 · Conectar la app (config.js)
En GitHub abre `public/config.js` → lápiz (editar) → pega entre comillas el Project URL, la llave anon y la llave pública de notificaciones → **Commit changes**.

### Paso 5 · Vercel
1. En vercel.com crea cuenta con "Continue with GitHub".
2. **Add New → Project →** elige `valle-go` → **Import**. En *Framework Preset* deja "Other".
3. Abre **Environment Variables** y agrega estas ocho:

| Nombre | Valor |
|---|---|
| `SUPABASE_URL` | el Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | la llave service_role / secret |
| `VAPID_PUBLIC_KEY` | la llave pública generada |
| `VAPID_PRIVATE_KEY` | la llave privada generada |
| `VAPID_SUBJECT` | `mailto:tu-correo@ejemplo.com` |
| `WEBHOOK_SECRET` | la clave secreta que inventaste |
| `STRIPE_SECRET_KEY` | la llave secreta de Stripe (empieza con `sk_test_` o `sk_live_`) |
| `APP_URL` | la dirección de tu app, por ejemplo `https://valle-go.vercel.app` (sin diagonal al final) |

4. Pulsa **Deploy**. Al terminar tendrás una dirección tipo `valle-go.vercel.app`. Si cambias variables después, usa **Deployments → Redeploy**.

### Paso 6 · Avisar a Vercel cuando entra un pedido (Webhook de Supabase)
En Supabase abre **Database → Webhooks** (en versiones nuevas puede estar en *Integrations*) → **Create a new hook**:
- Name: `pedido-nuevo` · Table: `pedidos` · Events: **Insert** y **Update** (los dos)
- Type: **HTTP Request** · Method: **POST**
- URL: `https://TU-DIRECCION.vercel.app/api/notificar`
- HTTP Headers: agrega `Authorization` con el valor `Bearer TU_WEBHOOK_SECRET` (la palabra Bearer, un espacio y tu clave).
- Guarda.

### Paso 6b · Stripe (pagos en línea)
1. Confirma que tu cuenta de Stripe sea de **México** (moneda MXN) y completa la verificación de tu negocio; sin eso no podrás recibir pagos reales. Empieza siempre en **modo de prueba** (Test mode).
2. **Settings → Payment methods:** activa tarjetas, **OXXO** y transferencia bancaria (**SPEI**) si Stripe te la ofrece. La app no necesita cambios: Stripe muestra al cliente los métodos que tengas activos.
3. **Developers → API keys:** copia la **Secret key** (`sk_test_...`) y pégala en Vercel como `STRIPE_SECRET_KEY`. Nunca la pongas en GitHub ni en `config.js`. (Stripe no necesita conectarse a GitHub para funcionar; solo necesita esta llave en Vercel.)
4. **Developers → Webhooks → Add endpoint** (en el panel nuevo puede llamarse *Event destinations*):
   - URL: `https://TU-DIRECCION.vercel.app/api/stripe-webhook`
   - Eventos: `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed` y `checkout.session.expired`.
5. Haz **Redeploy** en Vercel para que lea las variables nuevas.
6. **Prueba:** pide algo con "Pago en línea" y paga con la tarjeta de prueba `4242 4242 4242 4242`, cualquier fecha futura y cualquier CVC. En segundos el pedido debe pasar a **Pagado** y el comerciante recibe su notificación.
7. **Salir a producción:** cambia `STRIPE_SECRET_KEY` por la llave `sk_live_...`, crea de nuevo el webhook en modo real y haz Redeploy.

### Paso 7 · Hazte administrador
Abre tu app, **Entrar → Crear cuenta** con tu correo. En Supabase SQL Editor ejecuta la última línea de `schema-panel.sql` cambiando `tu-correo@ejemplo.com` por el tuyo. Cierra sesión, vuelve a entrar y aparecerá **Panel**.

### Paso 8 · Dar de alta comercios
Panel → Comercios → **Nuevo comercio**. Llena sus datos, foto, WhatsApp y, si aceptará transferencias, banco, titular y CLABE. Para que el comerciante vea su panel, escribe su correo en "Correo del comerciante" (él debe haberse registrado antes en la app). Luego, en Menús, agrega sus platillos con foto.

### Paso 9 · Notificaciones
Cada comerciante (y tú) entra a su **Panel** desde su celular y pulsa **Activar notificaciones**, aceptando el permiso.
- **Android:** funciona en Chrome, instalada o no.
- **iPhone:** solo funciona con la app instalada (Safari → Compartir → Agregar a inicio) y abierta desde su ícono, con iOS 16.4 o superior.
- Con la app abierta, además suena un tono y aparece un aviso en pantalla.
- Se avisa al comerciante del pedido y también al administrador.

## 4. Cómo se manejan los cobros
El cliente elige al pedir: **efectivo al recibir, transferencia bancaria o pago en línea** (tarjeta, OXXO o SPEI mediante Stripe).
- **Efectivo y transferencia:** el cobro nace **Pendiente** y tú lo cambias a **Pagado** (Panel → Pedidos) cuando confirmes el dinero. En transferencia la app muestra el banco, titular y CLABE del comercio.
- **Pago en línea (automático):** la app guarda el pedido y abre la página segura de Stripe. Cuando Stripe confirma el cobro, el pedido pasa solo a **Pagado**, y **en ese momento** se notifica al comerciante, así nadie prepara un pedido sin cobrar. Si el cliente no paga, el pedido queda Pendiente y puede pulsar **Pagar ahora** en "Mis pedidos"; si la sesión vence queda como **Expirado**.
- **OXXO:** el cliente recibe una ficha y paga en tienda; la confirmación puede tardar hasta unos días, y la app la recibe sola.
- Los datos de tarjeta **nunca pasan por tu app ni por tu base de datos**: se capturan en la página de Stripe.

### Seguridad de los pagos
- El total de cada pedido lo **recalcula la base de datos** con los precios reales del menú; lo que mande el celular se ignora. Nadie puede pagar menos alterando su pedido.
- Solo se marca "Pagado" si Stripe confirma el cobro con el mismo monto en pesos. La app **consulta directamente a Stripe** cada aviso que recibe, por lo que un aviso falso no sirve.
- Un comprador no puede crear un pedido ya marcado como pagado.

### El dinero y los comerciantes
Con esta versión, **todo el dinero llega a tu cuenta de Stripe**, y tú liquidas a cada comerciante (menos tu comisión). Para repartir automáticamente entre comercios existe **Stripe Connect**, pero obliga a que cada comerciante abra su cuenta y tiene condiciones propias; es una fase posterior. Consulta con un contador cómo facturar y reportar el dinero que recibes por cuenta de terceros.

## 5. Cómo actualizar la app
Edita el archivo en GitHub (lápiz → Commit changes). Vercel lo publica solo en menos de un minuto. Los celulares reciben la versión nueva al abrir la app con internet.

## 6. Seguridad
- La llave **anon** es pública por diseño; la protección la dan las reglas (RLS) del SQL. La **service_role** vive solo en Vercel, nunca en GitHub ni en `config.js`.
- Solo el administrador puede editar comercios, menús, fotos, anuncios y estados. Los comerciantes solo consultan. Un comprador no puede marcar su propio pedido como pagado.
- Agrega un aviso de privacidad: guardas nombres, teléfonos y direcciones.

## 7. Costos de Vercel y otros (verifica los precios vigentes)
- **Hobby (gratis):** solo para uso personal **no comercial**. Una plataforma que cobra pedidos NO califica.
- **Pro:** unos **$20 USD por usuario al mes** (más consumo si te pasas de lo incluido). Permite uso comercial e incluye cerca de 1 TB de transferencia y 10 millones de solicitudes al mes, mucho más de lo que necesitarás al inicio. Con **un solo usuario (tú)** pagas esa cuota.
- **Enterprise:** precio a la medida; no lo necesitas.
- **Stripe:** no cobra mensualidad; cobra por cada pago. Fuentes de terceros reportan alrededor de 3.6 % + $3 MXN por tarjeta nacional más IVA; OXXO y SPEI tienen tarifas distintas. Confirma las tuyas en stripe.com/mx/pricing.
- **Supabase:** el plan gratuito sirve para empezar, pero puede pausar proyectos con poca actividad y para operar con clientes reales conviene su plan de pago. Revisa su página de precios.

## 8. Si algo no funciona
| Síntoma | Qué revisar |
|---|---|
| La app muestra datos de ejemplo | `config.js` tiene el URL y la llave anon entre comillas |
| No aparece el botón Panel | Cierra sesión y entra de nuevo; confirma que ejecutaste la línea de `admins` con tu correo |
| "Falta VAPID_PUBLIC" | Pega la llave pública en `config.js` |
| No llegan notificaciones | Webhook creado con el header correcto; variables de Vercel completas (haz Redeploy); el comerciante pulsó Activar; en iPhone, app instalada. Revisa Vercel → Logs → `api/notificar` |
| Error 401 en el webhook | El valor de `Authorization` debe ser `Bearer ` + exactamente tu `WEBHOOK_SECRET` |
| Error al pagar en línea | Variables `STRIPE_SECRET_KEY` y `APP_URL` en Vercel (y Redeploy); en Vercel → Logs revisa `api/crear-pago` |
| Pagué pero sigue Pendiente | Webhook de Stripe creado con los 4 eventos y la URL correcta; en Stripe → Webhooks revisa si el envío dio error |
| Error al subir fotos | Tu cuenta debe ser administrador y existir la carpeta `fotos` (la crea schema.sql) |
