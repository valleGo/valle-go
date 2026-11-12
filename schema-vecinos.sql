-- Conteo público para la etiqueta de inicio ("● N VECINOS • AMECA, JAL.").
-- Solo devuelve un número: usuarios registrados + comercios activos + servicios/transportistas activos.
create or replace function public.contar_vecinos()
returns bigint
language sql
stable
security definer
set search_path = public, auth
as $$
  select (select count(*) from auth.users)
       + (select count(*) from public.comercios where activo)
       + (select count(*) from public.servicios_perfiles where activo is not false);
$$;
revoke all on function public.contar_vecinos() from public;
grant execute on function public.contar_vecinos() to anon, authenticated;
