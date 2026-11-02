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
