-- v181 (13 nov 2026): activar notificaciones en un celular que antes usó otra cuenta.
-- Antes: upsert directo en push_suscripciones fallaba con
--   "new row violates row-level security policy" cuando el endpoint (el aparato)
--   ya estaba guardado a nombre de otra cuenta.
-- Ahora: la app llama a guardar_push(); el aparato queda ligado a quien tiene la
-- sesión abierta en él (la cuenta anterior deja de recibir avisos en ese aparato).
-- El endpoint solo lo conoce el navegador del propio aparato, así que nadie puede
-- "robar" avisos de otro dispositivo.

create or replace function public.guardar_push(p_endpoint text, p_p256dh text, p_auth text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión para activar las notificaciones';
  end if;
  if coalesce(p_endpoint,'') !~ '^https://' or coalesce(p_p256dh,'') = '' or coalesce(p_auth,'') = '' then
    raise exception 'Suscripción no válida';
  end if;
  insert into push_suscripciones (user_id, endpoint, p256dh, auth)
  values (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth;
end;
$$;

revoke all on function public.guardar_push(text,text,text) from public, anon;
grant execute on function public.guardar_push(text,text,text) to authenticated;
