-- VALLE GO · Base de datos (Supabase). Pega TODO esto en SQL Editor y pulsa "Run".

create table comercios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null, giro text, descripcion text, horario text, emoji text,
  foto_url text, whatsapp text not null,
  envio numeric default 0, minimo numeric default 0,
  link_pago text, activo boolean default true,
  dueno_id uuid references auth.users(id),
  creado timestamptz default now()
);
create table menu_items (
  id uuid primary key default gen_random_uuid(),
  comercio_id uuid references comercios(id) on delete cascade,
  categoria text, nombre text not null, descripcion text,
  precio numeric not null, emoji text, foto_url text, disponible boolean default true
);
create table pedidos (
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

create policy "todos ven comercios activos" on comercios for select using (activo or dueno_id = auth.uid());
create policy "dueño edita su comercio"     on comercios for update using (dueno_id = auth.uid());
create policy "todos ven menus"             on menu_items for select using (true);
create policy "dueño gestiona su menu"      on menu_items for all
  using (exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()))
  with check (exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()));
create policy "comprador crea pedidos"      on pedidos for insert with check (auth.uid() = comprador_id);
create policy "comprador y dueño ven pedido" on pedidos for select using (
  auth.uid() = comprador_id or exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()));
create policy "dueño actualiza estado"      on pedidos for update using (
  exists (select 1 from comercios c where c.id = comercio_id and c.dueno_id = auth.uid()));

-- Carpeta pública de fotos
insert into storage.buckets (id, name, public) values ('fotos','fotos',true) on conflict do nothing;
create policy "usuarios suben fotos" on storage.objects for insert to authenticated with check (bucket_id = 'fotos');

-- Datos de ejemplo (bórralos cuando agregues los tuyos)
with t as (
  insert into comercios (nombre,giro,descripcion,horario,emoji,whatsapp,envio,minimo)
  values ('Tacos Doña Lupe','Taquería','Tacos al pastor y de guisado hechos al momento.','1:00 pm - 10:00 pm','🌮','5213300000001',30,80)
  returning id)
insert into menu_items (comercio_id,categoria,nombre,descripcion,precio,emoji)
select id,'Tacos','Taco al pastor','Con piña y cilantro',22,'🌮' from t
union all select id,'Tacos','Taco de bistec','Con cebolla asada',25,'🥩' from t
union all select id,'Bebidas','Agua de horchata 1L','Hecha en casa',40,'🥛' from t;
