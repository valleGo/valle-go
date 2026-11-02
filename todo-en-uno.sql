-- ============================================================
-- VALLE GO · BASE DE DATOS COMPLETA (todo en uno)
-- Pégalo completo en Supabase → SQL Editor → New query → Run.
-- Se puede ejecutar más de una vez sin problema.
-- Después ejecuta datos-demo.sql (opcional) y, al final, paso-administrador.sql
-- ============================================================

-- PARTE 1: tablas base
-- VALLE GO · Base de datos (Supabase). Pega TODO esto en SQL Editor y pulsa "Run".

create table if not exists comercios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null, giro text, descripcion text, horario text, emoji text,
  foto_url text, whatsapp text not null,
  envio numeric default 0, minimo numeric default 0,
  link_pago text, activo boolean default true,
  dueno_id uuid references auth.users(id),
  creado timestamptz default now()
);
create table if not exists menu_items (
  id uuid primary key default gen_random_uuid(),
  comercio_id uuid references comercios(id) on delete cascade,
  categoria text, nombre text not null, descripcion text,
  precio numeric not null, emoji text, foto_url text, disponible boolean default true
);
create table if not exists pedidos (
  id uuid primary key default gen_random_uuid(),
  comprador_id uuid references auth.users(id),
  comercio_id uuid references comercios(id),
  lineas jsonb not null, total numeric not null,
  entrega text, pago text, direccion text, notas text,
  estado text default 'Enviado al comercio',
  creado timestamptz default now()
);

-- Seguridad: cada quien solo ve y cambia lo que le corresponde
alter table comercios  enable row level security;
alter table menu_items enable row level security;
alter table pedidos    enable row level security;

drop policy if exists "todos ven comercios activos" on comercios;
create policy "todos ven comercios activos" on comercios for select using (activo or dueno_id = auth.uid());
drop policy if exists "dueño edita su comercio" on comercios;
create policy "dueño edita su comercio"     on comercios for update using (dueno_id = auth.uid());
drop policy if exists "todos ven menus" on menu_items;
create policy "todos ven menus"             on menu_items for select using (true);
drop policy if exists "dueño gestiona su menu" on menu_items;
create policy "dueño gestiona su menu"      on menu_items for all
  using (exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()))
  with check (exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()));
drop policy if exists "comprador crea pedidos" on pedidos;
create policy "comprador crea pedidos"      on pedidos for insert with check (auth.uid() = comprador_id);
drop policy if exists "comprador y dueño ven pedido" on pedidos;
create policy "comprador y dueño ven pedido" on pedidos for select using (
  auth.uid() = comprador_id or exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()));
drop policy if exists "dueño actualiza estado" on pedidos;
create policy "dueño actualiza estado"      on pedidos for update using (
  exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()));

-- Carpeta pública de fotos
insert into storage.buckets (id, name, public) values ('fotos','fotos',true) on conflict do nothing;
drop policy if exists "usuarios suben fotos" on storage.objects;
create policy "usuarios suben fotos" on storage.objects for insert to authenticated with check (bucket_id = 'fotos');


-- PARTE 2: paneles, administrador y publicidad
-- VALLE GO · Paneles, administrador y publicidad.
-- Ejecútalo DESPUÉS de schema.sql (SQL Editor → New query → pega todo → Run).

-- 1. Administradores
create table if not exists admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table admins enable row level security;
drop policy if exists "ver si soy admin" on admins;
create policy "ver si soy admin" on admins for select using (user_id = auth.uid());
create or replace function es_admin() returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from admins where user_id = auth.uid()) $$;

-- 2. Los comerciantes SOLO consultan: se quitan sus permisos de edición
drop policy if exists "dueño edita su comercio" on comercios;
drop policy if exists "dueño gestiona su menu" on menu_items;
drop policy if exists "dueño actualiza estado" on pedidos;
drop policy if exists "usuarios suben fotos" on storage.objects;

-- 3. Solo el administrador puede editar
drop policy if exists "admin comercios" on comercios;
drop policy if exists "admin menus" on menu_items;
drop policy if exists "admin pedidos" on pedidos;
drop policy if exists "admin comercios" on comercios;
create policy "admin comercios" on comercios  for all using (es_admin()) with check (es_admin());
drop policy if exists "admin menus" on menu_items;
create policy "admin menus"     on menu_items for all using (es_admin()) with check (es_admin());
drop policy if exists "admin pedidos" on pedidos;
create policy "admin pedidos"   on pedidos    for all using (es_admin()) with check (es_admin());
drop policy if exists "admin sube fotos" on storage.objects;
drop policy if exists "admin cambia fotos" on storage.objects;
drop policy if exists "admin borra fotos" on storage.objects;
drop policy if exists "admin sube fotos" on storage.objects;
create policy "admin sube fotos"   on storage.objects for insert to authenticated with check (bucket_id = 'fotos' and es_admin());
drop policy if exists "admin cambia fotos" on storage.objects;
create policy "admin cambia fotos" on storage.objects for update to authenticated using (bucket_id = 'fotos' and es_admin());
drop policy if exists "admin borra fotos" on storage.objects;
create policy "admin borra fotos"  on storage.objects for delete to authenticated using (bucket_id = 'fotos' and es_admin());

-- 4. Datos del cliente en cada pedido
alter table pedidos add column if not exists cliente_nombre text, add column if not exists cliente_tel text;

-- 5. Publicidad (máximo 5 anuncios)
create table if not exists anuncios (
  id uuid primary key default gen_random_uuid(),
  titulo text, imagen_url text not null, enlace text,
  orden int default 0, activo boolean default true, creado timestamptz default now());
alter table anuncios enable row level security;
drop policy if exists "todos ven anuncios activos" on anuncios;
drop policy if exists "admin anuncios" on anuncios;
drop policy if exists "todos ven anuncios activos" on anuncios;
create policy "todos ven anuncios activos" on anuncios for select using (activo or es_admin());
drop policy if exists "admin anuncios" on anuncios;
create policy "admin anuncios" on anuncios for all using (es_admin()) with check (es_admin());
create or replace function limitar_anuncios() returns trigger language plpgsql as
$$ begin if (select count(*) from anuncios) >= 5 then raise exception 'Máximo 5 anuncios'; end if; return new; end $$;
drop trigger if exists max_anuncios on anuncios;
create trigger max_anuncios before insert on anuncios for each row execute function limitar_anuncios();

-- 6. Buscar el ID de un usuario por su correo (solo lo puede usar el administrador)
create or replace function usuario_por_correo(correo text) returns uuid language sql security definer set search_path = public, auth
as $$ select id from auth.users where lower(email) = lower(correo) and es_admin() limit 1 $$;


-- PARTE 3: cobros y notificaciones
-- VALLE GO · Cobros (efectivo / transferencia / tarjeta) y notificaciones.
-- Ejecútalo DESPUÉS de schema.sql y schema-panel.sql.

-- 1. Estado del cobro en cada pedido y datos bancarios del comercio
alter table pedidos   add column if not exists estado_pago text default 'Pendiente';
alter table comercios add column if not exists banco text, add column if not exists titular text, add column if not exists clabe text;

-- 2. Seguridad: un comprador no puede crear un pedido ya marcado como "Pagado"
drop policy if exists "comprador crea pedidos" on pedidos;
create policy "comprador crea pedidos" on pedidos for insert
  with check (auth.uid() = comprador_id and estado = 'Enviado al comercio' and estado_pago = 'Pendiente');

-- 3. Dispositivos que reciben notificaciones
create table if not exists push_suscripciones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique, p256dh text not null, auth text not null,
  creado timestamptz default now());
alter table push_suscripciones enable row level security;
drop policy if exists "mis suscripciones" on push_suscripciones;
create policy "mis suscripciones" on push_suscripciones for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4. Avisos en vivo dentro de la app
do $$ begin
  alter publication supabase_realtime add table pedidos;
exception when duplicate_object then null; end $$;

-- PARTE 4: pagos con Stripe
-- VALLE GO · Pagos en línea con Stripe.
-- Ejecútalo DESPUÉS de schema.sql, schema-panel.sql y schema-notificaciones.sql.

alter table pedidos add column if not exists items jsonb;               -- [{"id": "...", "cant": 2}]
alter table pedidos add column if not exists stripe_session_id text;
alter table pedidos add column if not exists pagado_en timestamptz;

-- El total y el detalle del pedido los calcula LA BASE DE DATOS con los precios reales del menú.
-- Así nadie puede alterar su pedido para pagar menos, sin importar lo que envíe desde el celular.
create or replace function calcular_pedido() returns trigger language plpgsql security definer set search_path = public as $$
declare
  it jsonb; m record; sub numeric := 0; env numeric := 0; ls text[] := '{}'; cant int;
begin
  if new.items is null or jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) = 0 then
    raise exception 'El pedido no tiene productos';
  end if;
  for it in select jsonb_array_elements(new.items) loop
    cant := (it->>'cant')::int;
    if cant < 1 or cant > 99 then raise exception 'Cantidad no válida'; end if;
    select * into m from menu_items where id = (it->>'id')::uuid and comercio_id = new.comercio_id and disponible;
    if not found then raise exception 'Un producto ya no está disponible'; end if;
    sub := sub + m.precio * cant;
    ls := ls || format('%s x %s - $%s', cant, m.nombre, to_char(m.precio * cant, 'FM999990.00'));
  end loop;
  if new.entrega = 'domicilio' then select envio into env from comercios where id = new.comercio_id; end if;
  new.lineas := to_jsonb(ls);
  new.total  := sub + coalesce(env, 0);
  return new;
end $$;
drop trigger if exists calcular_pedido on pedidos;
create trigger calcular_pedido before insert on pedidos for each row execute function calcular_pedido();

-- PARTE 5: seguridad de funciones (recomendaciones del revisor de Supabase)
alter function public.limitar_anuncios() set search_path = public;
revoke execute on function public.calcular_pedido() from public, anon, authenticated;   -- solo lo usa el trigger
revoke execute on function public.usuario_por_correo(text) from public, anon;
grant  execute on function public.usuario_por_correo(text) to authenticated;            -- además exige ser administrador
-- es_admin() debe seguir ejecutable: las reglas de seguridad la usan.
