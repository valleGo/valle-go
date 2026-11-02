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
create policy "admin comercios" on comercios  for all using (es_admin()) with check (es_admin());
create policy "admin menus"     on menu_items for all using (es_admin()) with check (es_admin());
create policy "admin pedidos"   on pedidos    for all using (es_admin()) with check (es_admin());
drop policy if exists "admin sube fotos" on storage.objects;
drop policy if exists "admin cambia fotos" on storage.objects;
drop policy if exists "admin borra fotos" on storage.objects;
create policy "admin sube fotos"   on storage.objects for insert to authenticated with check (bucket_id = 'fotos' and es_admin());
create policy "admin cambia fotos" on storage.objects for update to authenticated using (bucket_id = 'fotos' and es_admin());
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
create policy "todos ven anuncios activos" on anuncios for select using (activo or es_admin());
create policy "admin anuncios" on anuncios for all using (es_admin()) with check (es_admin());
create or replace function limitar_anuncios() returns trigger language plpgsql as
$$ begin if (select count(*) from anuncios) >= 5 then raise exception 'Máximo 5 anuncios'; end if; return new; end $$;
drop trigger if exists max_anuncios on anuncios;
create trigger max_anuncios before insert on anuncios for each row execute function limitar_anuncios();

-- 6. Buscar el ID de un usuario por su correo (solo lo puede usar el administrador)
create or replace function usuario_por_correo(correo text) returns uuid language sql security definer set search_path = public, auth
as $$ select id from auth.users where lower(email) = lower(correo) and es_admin() limit 1 $$;

-- 7. HAZTE ADMINISTRADOR: primero regístrate en la app con tu correo, luego cambia el correo de abajo por el TUYO y ejecuta esta línea.
insert into admins (user_id) select id from auth.users where email = 'tu-correo@ejemplo.com' on conflict do nothing;
