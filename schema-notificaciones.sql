-- VALLE GO · Cobros (efectivo / transferencia / tarjeta) y notificaciones.
-- Ejecútalo DESPUÉS de schema.sql y schema-panel.sql.

-- 1. Estado del cobro en cada pedido y datos bancarios del comercio
alter table pedidos   add column if not exists estado_pago text default 'Pendiente';
alter table comercios add column if not exists banco text, add column if not exists titular text, add column if not exists clabe text;

-- 2. Seguridad: un comprador no puede crear un pedido ya marcado como "Pagado"
drop policy if exists "comprador crea pedidos" on pedidos;
create policy "comprador crea pedidos" on pedidos for insert
  with check (auth.uid() = comprador_id and estado = 'Enviado al comercio' and estado_pago = 'Pendiente');

-- 3. Dispositivos que reciben notificaciones
create table if not exists push_suscripciones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique, p256dh text not null, auth text not null,
  creado timestamptz default now());
alter table push_suscripciones enable row level security;
drop policy if exists "mis suscripciones" on push_suscripciones;
create policy "mis suscripciones" on push_suscripciones for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4. Avisos en vivo dentro de la app
do $$ begin
  alter publication supabase_realtime add table pedidos;
exception when duplicate_object then null; end $$;
