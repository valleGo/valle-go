-- v212 (13 nov 2026): las consultas de stock se cierran solas y pasan al historial.
-- Una consulta queda CERRADA cuando:
--   comprada       → el cliente compró con el enlace de compra
--   enlace         → el comercio ya envió el enlace de compra (el cliente aún puede comprarlo)
--   no_hay         → el comercio respondió "No hay"
--   respondida     → respondió "Hay" y pasaron 24 h sin crear enlace de compra
--   sin_respuesta  → quedó "Pendiente" o "Consultar" más de 48 h (cierre automático)
-- Mientras está abierta, el comercio la responde en "Mi panel". Ya cerrada, el comercio solo la ve
-- (historial); cualquier corrección la hace la administración de Valle GO.
-- No cambia precios ni cobros.

create or replace function public.consulta_cierre(c public.consultas_stock)
returns text
language sql
stable
set search_path = public
as $$
  select case
    when c.oferta_pedido_id is not null then 'comprada'
    when c.oferta_precio is not null then 'enlace'
    when c.estado = 'No hay' then 'no_hay'
    when c.estado = 'Hay' and coalesce(c.respondida_en, c.creado) < now() - interval '24 hours' then 'respondida'
    when c.estado in ('Pendiente','Consultar') and c.creado < now() - interval '48 hours' then 'sin_respuesta'
    else null
  end
$$;
grant execute on function public.consulta_cierre(public.consultas_stock) to authenticated;

create or replace function public.limitar_cambios_consulta()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if current_setting('valle.oferta', true) = '1' then return new; end if;
  if es_admin() then return new; end if;
  -- ya cerrada: solo lectura para el comercio y el cliente
  if public.consulta_cierre(old) is not null then
    raise exception 'Esta consulta ya está cerrada. Para cualquier aclaración, contacta a la administración de Valle GO.';
  end if;
  if new.perfil_id is distinct from old.perfil_id or new.cliente_id is distinct from old.cliente_id
     or new.cliente_nombre is distinct from old.cliente_nombre or new.cliente_tel is distinct from old.cliente_tel
     or new.texto is distinct from old.texto or new.foto_url is distinct from old.foto_url or new.creado is distinct from old.creado
     or new.oferta_pedido_id is distinct from old.oferta_pedido_id then
    raise exception 'Cambio no permitido';
  end if;
  if (new.oferta_nombre, new.oferta_precio, new.oferta_max) is distinct from (old.oferta_nombre, old.oferta_precio, old.oferta_max) then
    if old.oferta_pedido_id is not null then raise exception 'Este enlace de compra ya se usó en un pedido'; end if;
    if new.oferta_precio is not null then
      if new.estado <> 'Hay' then raise exception 'Primero responde que sí hay el producto'; end if;
      if new.oferta_precio <= 0 or new.oferta_precio > 100000 then raise exception 'Escribe un precio válido'; end if;
      if coalesce(trim(new.oferta_nombre), '') = '' then raise exception 'Escribe el nombre del producto'; end if;
      new.oferta_nombre := left(trim(new.oferta_nombre), 120);
      new.oferta_max := least(greatest(coalesce(new.oferta_max, 1), 1), 99);
      new.oferta_creada := now();
    else
      new.oferta_nombre := null; new.oferta_max := null; new.oferta_creada := null;
    end if;
  end if;
  if new.estado is distinct from old.estado or new.respuesta is distinct from old.respuesta then new.respondida_en := now(); end if;
  return new;
end $function$;
