-- v187 (13 nov 2026): candado de pedidos para el comerciante.
-- Una vez que el pedido queda PAGADO, el comerciante ya no puede cambiar el estado del pago.
-- Una vez que el pedido queda ENTREGADO, el comerciante ya no puede cambiar el estado del pedido.
-- (Si está pagado y entregado, el pedido queda cerrado para el comerciante.)
-- Administración y cliente quedan igual: el administrador puede corregir (es_admin), el cliente
-- confirma "recibido" con cliente_confirmar_recibido() y Mercado Pago (servicio, sin usuario) sigue
-- confirmando pagos en línea.

create or replace function public.limitar_cambios_pedido()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if auth.uid() is null or es_admin() or current_setting('valle.recibido', true) = '1' then return new; end if;
  if (to_jsonb(new) - 'estado' - 'estado_pago') is distinct from (to_jsonb(old) - 'estado' - 'estado_pago') then
    raise exception 'Solo puedes cambiar el estado del pedido';
  end if;
  if new.estado_pago is distinct from old.estado_pago and old.pago = 'en_linea' then
    raise exception 'El pago en línea lo confirma Mercado Pago automáticamente';
  end if;
  -- candado: lo pagado y lo entregado ya no lo cambia el comerciante
  if new.estado_pago is distinct from old.estado_pago and old.estado_pago = 'Pagado' then
    raise exception 'Este pedido ya está pagado: el pago ya no se puede cambiar. Si hay un error, pide ayuda a la administración de Valle GO.';
  end if;
  if new.estado is distinct from old.estado and old.estado = 'Entregado' then
    raise exception 'Este pedido ya fue entregado: su estado ya no se puede cambiar. Si hay un error, pide ayuda a la administración de Valle GO.';
  end if;
  return new;
end $function$;
