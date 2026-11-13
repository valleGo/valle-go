-- v182 (13 nov 2026): límite de dispositivos con sesión abierta al mismo tiempo.
--   Administradores y comerciantes (dueños de un comercio o de un perfil de servicio
--   o transporte): hasta 5 dispositivos.
--   Clientes: 1 dispositivo. Al iniciar sesión en uno nuevo, el anterior se cierra.
-- Al pasar el límite se cierra la sesión que tiene más tiempo sin usarse.
-- Se usa la sesión real de Supabase (auth.sessions): al borrarla, ese dispositivo ya
-- no puede renovar su acceso, y la app lo saca al revisar con sesion_vigente().
-- No se guarda ningún dato nuevo.

create or replace function public.limite_dispositivos()
returns int
language sql
stable
security definer
set search_path = public
as $$
  select case when exists (select 1 from admins where user_id = auth.uid())
                or exists (select 1 from comercios where dueno_id = auth.uid())
                or exists (select 1 from servicios_perfiles where dueno_id = auth.uid())
              then 5 else 1 end
$$;

create or replace function public.registrar_sesion()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_sid uuid := nullif(auth.jwt()->>'session_id','')::uuid;
  v_lim int;
  v_cerradas int := 0;
begin
  if v_uid is null or v_sid is null then
    return json_build_object('ok', false);
  end if;
  -- si esta sesión ya fue cerrada (por ejemplo, desde otro dispositivo), no puede sacar a las demás
  if not exists (select 1 from auth.sessions where id = v_sid and user_id = v_uid) then
    return json_build_object('ok', false);
  end if;
  v_lim := public.limite_dispositivos();
  with sobran as (
    select id from auth.sessions
    where user_id = v_uid and id <> v_sid
    order by coalesce(refreshed_at::timestamptz, updated_at, created_at) desc
    offset greatest(v_lim - 1, 0)
  )
  delete from auth.sessions s using sobran where s.id = sobran.id;
  get diagnostics v_cerradas = row_count;
  return json_build_object('ok', true, 'limite', v_lim, 'cerradas', v_cerradas);
end;
$$;

create or replace function public.sesion_vigente()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (select 1 from auth.sessions
                 where id = nullif(auth.jwt()->>'session_id','')::uuid
                   and user_id = auth.uid())
$$;

revoke all on function public.limite_dispositivos() from public, anon;
revoke all on function public.registrar_sesion()   from public, anon;
revoke all on function public.sesion_vigente()     from public, anon;
grant execute on function public.limite_dispositivos() to authenticated;
grant execute on function public.registrar_sesion()   to authenticated;
grant execute on function public.sesion_vigente()     to authenticated;
