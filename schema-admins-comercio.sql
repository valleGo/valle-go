-- v217 (14 nov 2026): administradores de comercios y transportistas.
-- Además del dueño (comercios.dueno_id / servicios_perfiles.dueno_id), un comercio o transportista
-- puede tener otros administradores que atienden su panel (pedidos, citas, consultas, viajes).
-- Solo la administración de Valle GO los agrega o quita. Conectar Mercado Pago sigue siendo
-- solo del dueño y de Valle GO.

create table if not exists public.perfil_admins (
  perfil_id   uuid not null,                       -- id del comercio o del perfil de servicio
  user_id     uuid not null references auth.users(id) on delete cascade,
  agregado_por uuid references auth.users(id) on delete set null,
  creado      timestamptz not null default now(),
  primary key (perfil_id, user_id)
);
create index if not exists perfil_admins_user on public.perfil_admins(user_id);
alter table public.perfil_admins enable row level security;

drop policy if exists "leer perfil_admins" on public.perfil_admins;
create policy "leer perfil_admins" on public.perfil_admins for select
  using (user_id = (select auth.uid()) or (select es_admin()));
-- sin políticas de insert/update/delete: solo por las funciones de abajo (Valle GO)

-- Borrar el comercio o perfil borra sus administradores
create or replace function public.perfil_admins_limpiar() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin delete from public.perfil_admins where perfil_id = old.id; return old; end $$;
drop trigger if exists perfil_admins_limpiar on public.comercios;
create trigger perfil_admins_limpiar after delete on public.comercios for each row execute function public.perfil_admins_limpiar();
drop trigger if exists perfil_admins_limpiar on public.servicios_perfiles;
create trigger perfil_admins_limpiar after delete on public.servicios_perfiles for each row execute function public.perfil_admins_limpiar();

-- El dueño o un administrador del comercio/perfil
create or replace function public.es_dueno_perfil(pid uuid) returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from servicios_perfiles where id = pid and dueno_id = auth.uid())
      or exists (select 1 from comercios where id = pid and dueno_id = auth.uid())
      or exists (select 1 from perfil_admins where perfil_id = pid and user_id = auth.uid()) $$;

-- 5 dispositivos también para administradores de comercios
create or replace function public.limite_dispositivos() returns integer
language sql stable security definer set search_path to 'public' as $$
  select case when exists (select 1 from admins where user_id = auth.uid())
                or exists (select 1 from comercios where dueno_id = auth.uid())
                or exists (select 1 from servicios_perfiles where dueno_id = auth.uid())
                or exists (select 1 from perfil_admins where user_id = auth.uid())
              then 5 else 1 end $$;

-- Pedidos y lectura de perfiles: dueño o administrador del comercio
drop policy if exists "leer pedidos" on public.pedidos;
create policy "leer pedidos" on public.pedidos for select
  using ((select auth.uid()) = comprador_id or es_dueno_perfil(comercio_id) or (select es_admin()));
drop policy if exists "editar pedidos" on public.pedidos;
create policy "editar pedidos" on public.pedidos for update
  using (es_dueno_perfil(comercio_id) or (select es_admin()))
  with check (es_dueno_perfil(comercio_id) or (select es_admin()));
drop policy if exists "leer comercios" on public.comercios;
create policy "leer comercios" on public.comercios for select
  using (activo or dueno_id = (select auth.uid()) or es_dueno_perfil(id) or (select es_admin()));
drop policy if exists "leer servicios" on public.servicios_perfiles;
create policy "leer servicios" on public.servicios_perfiles for select
  using (activo or dueno_id = (select auth.uid()) or es_dueno_perfil(id) or (select es_admin()));
drop policy if exists "editar servicios" on public.servicios_perfiles;
create policy "editar servicios" on public.servicios_perfiles for update
  using (es_dueno_perfil(id) or (select es_admin()))
  with check (es_dueno_perfil(id) or (select es_admin()));

-- Perfiles que administra el usuario (además de los que son suyos)
create or replace function public.mis_perfiles_admin() returns setof uuid
language sql stable security definer set search_path to 'public' as $$
  select perfil_id from perfil_admins where user_id = auth.uid() $$;

-- Solo Valle GO: listar, agregar y quitar
create or replace function public.admin_lista_perfil_admins()
returns table(perfil_id uuid, perfil text, tipo text, user_id uuid, email text, dueno_email text)
language sql security definer set search_path to 'public','auth' as $$
  select pa.perfil_id, coalesce(c.nombre, s.nombre), case when c.id is not null then 'comercio' else 'servicio' end,
         pa.user_id, u.email::text, du.email::text
  from perfil_admins pa
  join auth.users u on u.id = pa.user_id
  left join comercios c on c.id = pa.perfil_id
  left join servicios_perfiles s on s.id = pa.perfil_id
  left join auth.users du on du.id = coalesce(c.dueno_id, s.dueno_id)
  where public.es_admin()
  order by 2, 5 $$;

create or replace function public.admin_agregar_perfil_admin(pid uuid, correo text) returns text
language plpgsql security definer set search_path to 'public','auth' as $$
declare uid uuid;
begin
  if not public.es_admin() then raise exception 'No autorizado'; end if;
  if not exists (select 1 from comercios where id = pid) and not exists (select 1 from servicios_perfiles where id = pid) then
    raise exception 'Ese comercio no existe.'; end if;
  select id into uid from auth.users where lower(email) = lower(trim(correo)) limit 1;
  if uid is null then raise exception 'Ese correo no está registrado en la app.'; end if;
  if exists (select 1 from comercios where id = pid and dueno_id = uid) or exists (select 1 from servicios_perfiles where id = pid and dueno_id = uid) then
    raise exception 'Ese usuario ya es el dueño de este comercio.'; end if;
  if exists (select 1 from perfil_admins where perfil_id = pid and user_id = uid) then
    raise exception 'Ese usuario ya administra este comercio.'; end if;
  insert into perfil_admins(perfil_id, user_id, agregado_por) values (pid, uid, auth.uid());
  return 'ok';
end $$;

create or replace function public.admin_quitar_perfil_admin(pid uuid, uid uuid) returns text
language plpgsql security definer set search_path to 'public','auth' as $$
begin
  if not public.es_admin() then raise exception 'No autorizado'; end if;
  delete from perfil_admins where perfil_id = pid and user_id = uid;
  return 'ok';
end $$;

revoke all on function public.admin_lista_perfil_admins() from public, anon;
revoke all on function public.admin_agregar_perfil_admin(uuid, text) from public, anon;
revoke all on function public.admin_quitar_perfil_admin(uuid, uuid) from public, anon;
revoke all on function public.mis_perfiles_admin() from public, anon;
grant execute on function public.admin_lista_perfil_admins(), public.admin_agregar_perfil_admin(uuid, text),
  public.admin_quitar_perfil_admin(uuid, uuid), public.mis_perfiles_admin() to authenticated;
