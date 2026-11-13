-- Valle GO v176 · Enlace de compra desde una consulta de stock (12 nov 2026)
-- El comercio responde "Hay" y crea una oferta (producto, precio por pieza y piezas disponibles).
-- El cliente que hizo la consulta la compra desde la app como un pedido normal (3% de comisión, Mercado Pago, etc.).
-- El precio lo pone la base de datos (calcular_pedido), nunca el celular. Enlace de un solo uso, solo para ese cliente.
-- Se puede correr más de una vez.

alter table public.consultas_stock add column if not exists oferta_nombre text;
alter table public.consultas_stock add column if not exists oferta_precio numeric(12,2);
alter table public.consultas_stock add column if not exists oferta_max int;
alter table public.consultas_stock add column if not exists oferta_creada timestamptz;
alter table public.consultas_stock add column if not exists oferta_pedido_id uuid references public.pedidos(id) on delete set null;

-- Reglas de cambios en consultas (se agregan las de la oferta)
create or replace function public.limitar_cambios_consulta()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if current_setting('valle.oferta', true) = '1' then return new; end if;   -- lo usa el sistema al comprar o cancelar
  if es_admin() then return new; end if;
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
end $$;

-- El pedido calcula el precio de la oferta desde la consulta (no desde el celular)
create or replace function public.calcular_pedido()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  it jsonb; m record; q record; sub numeric := 0; env numeric := 0; ls text[] := '{}'; cant int;
begin
  if new.items is null or jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) = 0 then
    raise exception 'El pedido no tiene productos';
  end if;
  for it in select jsonb_array_elements(new.items) loop
    cant := (it->>'cant')::int;
    if cant < 1 or cant > 99 then raise exception 'Cantidad no válida'; end if;
    if it ? 'cq' then   -- producto de un enlace de compra (consulta de stock)
      select * into q from consultas_stock where id = (it->>'cq')::uuid and perfil_id = new.comercio_id
        and cliente_id = new.comprador_id and estado = 'Hay' and oferta_precio > 0 and oferta_pedido_id is null;
      if not found then raise exception 'Este enlace de compra ya no está disponible'; end if;
      if cant > coalesce(q.oferta_max, 1) then raise exception 'Solo hay % pieza(s) disponibles', coalesce(q.oferta_max, 1); end if;
      sub := sub + q.oferta_precio * cant;
      ls := ls || format('%s x %s - $%s', cant, q.oferta_nombre, to_char(q.oferta_precio * cant, 'FM999990.00'));
    else
      select * into m from menu_items where id = (it->>'id')::uuid and comercio_id = new.comercio_id and disponible;
      if not found then raise exception 'Un producto ya no está disponible'; end if;
      sub := sub + m.precio * cant;
      ls := ls || format('%s x %s - $%s', cant, m.nombre, to_char(m.precio * cant, 'FM999990.00'));
    end if;
  end loop;
  if new.entrega = 'domicilio' then select envio into env from comercios where id = new.comercio_id; end if;
  new.lineas := to_jsonb(ls);
  new.total  := sub + coalesce(env, 0);
  return new;
end $$;

-- Al guardar el pedido, el enlace queda usado; si el pedido se cancela, el enlace vuelve a estar disponible
create or replace function public.oferta_consulta_pedido()
returns trigger language plpgsql security definer set search_path = public as $$
declare it jsonb;
begin
  if tg_op = 'INSERT' then
    for it in select jsonb_array_elements(new.items) loop
      if it ? 'cq' then
        perform set_config('valle.oferta', '1', true);
        update consultas_stock set oferta_pedido_id = new.id where id = (it->>'cq')::uuid;
        perform set_config('valle.oferta', '', true);
      end if;
    end loop;
  elsif new.estado = 'Cancelado' and old.estado is distinct from 'Cancelado' then
    perform set_config('valle.oferta', '1', true);
    update consultas_stock set oferta_pedido_id = null where oferta_pedido_id = new.id;
    perform set_config('valle.oferta', '', true);
  end if;
  return new;
end $$;
revoke execute on function public.oferta_consulta_pedido() from public, anon, authenticated;
drop trigger if exists oferta_consulta_nuevo on public.pedidos;
create trigger oferta_consulta_nuevo after insert on public.pedidos
  for each row when (new.items::text like '%"cq"%') execute function public.oferta_consulta_pedido();
drop trigger if exists oferta_consulta_cancelado on public.pedidos;
create trigger oferta_consulta_cancelado after update of estado on public.pedidos
  for each row when (new.estado = 'Cancelado' and old.estado is distinct from 'Cancelado') execute function public.oferta_consulta_pedido();

-- Aviso al cliente cuando el comercio crea el enlace de compra
drop trigger if exists aviso_consulta_resp on public.consultas_stock;
create trigger aviso_consulta_resp after update of estado, respuesta, oferta_precio on public.consultas_stock
  for each row execute function public.avisar_pedido();
