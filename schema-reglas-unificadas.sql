-- Reglas RLS unificadas (v157). Ya aplicado en Supabase; se guarda aquí como respaldo.
-- Antes cada tabla tenía varias reglas que se sumaban (p. ej. "admin hace todo" + "todos ven lo activo").
-- Ahora hay UNA regla por acción (leer / crear / editar / borrar) que junta las mismas condiciones con OR.
-- Mismo acceso exacto para cada usuario; la base evalúa una sola regla por consulta.
-- auth.uid() y es_admin() van como (select ...) para evaluarse una vez por consulta.
-- Tablas que ya tenían una sola regla y no cambian: admins, cobros_pagos, gastos, push_suscripciones.

begin;

-- ===== anuncios =====
drop policy if exists "admin anuncios" on public.anuncios;
drop policy if exists "todos ven anuncios activos" on public.anuncios;
create policy "leer anuncios"   on public.anuncios for select to public        using (activo or (select es_admin()));
create policy "crear anuncios"  on public.anuncios for insert to authenticated with check ((select es_admin()));
create policy "editar anuncios" on public.anuncios for update to authenticated using ((select es_admin())) with check ((select es_admin()));
create policy "borrar anuncios" on public.anuncios for delete to authenticated using ((select es_admin()));

-- ===== categorias =====
drop policy if exists "admin categorias" on public.categorias;
drop policy if exists "todos ven categorias" on public.categorias;
create policy "leer categorias"   on public.categorias for select to public        using (true);
create policy "crear categorias"  on public.categorias for insert to authenticated with check ((select es_admin()));
create policy "editar categorias" on public.categorias for update to authenticated using ((select es_admin())) with check ((select es_admin()));
create policy "borrar categorias" on public.categorias for delete to authenticated using ((select es_admin()));

-- ===== comercios =====
drop policy if exists "admin comercios" on public.comercios;
drop policy if exists "todos ven comercios activos" on public.comercios;
create policy "leer comercios"   on public.comercios for select to public        using (activo or dueno_id = (select auth.uid()) or (select es_admin()));
create policy "crear comercios"  on public.comercios for insert to authenticated with check ((select es_admin()));
create policy "editar comercios" on public.comercios for update to authenticated using ((select es_admin())) with check ((select es_admin()));
create policy "borrar comercios" on public.comercios for delete to authenticated using ((select es_admin()));

-- ===== menu_items =====
drop policy if exists "admin menus" on public.menu_items;
drop policy if exists "todos ven menus" on public.menu_items;
create policy "leer menus"   on public.menu_items for select to public        using (true);
create policy "crear menus"  on public.menu_items for insert to authenticated with check ((select es_admin()));
create policy "editar menus" on public.menu_items for update to authenticated using ((select es_admin())) with check ((select es_admin()));
create policy "borrar menus" on public.menu_items for delete to authenticated using ((select es_admin()));

-- ===== pedidos =====
drop policy if exists "admin pedidos" on public.pedidos;
drop policy if exists "comprador crea pedidos" on public.pedidos;
drop policy if exists "comprador y dueño ven pedido" on public.pedidos;
drop policy if exists "dueño actualiza estado de sus pedidos" on public.pedidos;
create policy "leer pedidos" on public.pedidos for select to authenticated using (
  (select auth.uid()) = comprador_id
  or exists (select 1 from public.comercios c where c.id = pedidos.comercio_id and c.dueno_id = (select auth.uid()))
  or (select es_admin()));
create policy "crear pedidos" on public.pedidos for insert to authenticated with check (
  ((select auth.uid()) = comprador_id and estado = 'Enviado al comercio' and estado_pago = 'Pendiente')
  or (select es_admin()));
create policy "editar pedidos" on public.pedidos for update to authenticated
  using (exists (select 1 from public.comercios c where c.id = pedidos.comercio_id and c.dueno_id = (select auth.uid())) or (select es_admin()))
  with check (exists (select 1 from public.comercios c where c.id = pedidos.comercio_id and c.dueno_id = (select auth.uid())) or (select es_admin()));
create policy "borrar pedidos" on public.pedidos for delete to authenticated using ((select es_admin()));

-- ===== citas =====
drop policy if exists "admin citas" on public.citas;
drop policy if exists "cliente crea cita" on public.citas;
drop policy if exists "cliente y dueno ven citas" on public.citas;
drop policy if exists "cliente y dueno actualizan citas" on public.citas;
create policy "leer citas" on public.citas for select to authenticated using (
  (select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "crear citas" on public.citas for insert to authenticated with check (
  ((select auth.uid()) = cliente_id and estado = 'Solicitada'
    and exists (select 1 from public.comercios c where c.id = citas.perfil_id and c.activo and c.plan = 'basico' and c.ofrece_citas))
  or (select es_admin()));
create policy "editar citas" on public.citas for update to authenticated
  using ((select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()))
  with check ((select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "borrar citas" on public.citas for delete to authenticated using ((select es_admin()));

-- ===== consultas_stock =====
drop policy if exists "admin consultas" on public.consultas_stock;
drop policy if exists "cliente crea consulta" on public.consultas_stock;
drop policy if exists "cliente y dueno ven consultas" on public.consultas_stock;
drop policy if exists "dueno responde consultas" on public.consultas_stock;
create policy "leer consultas" on public.consultas_stock for select to authenticated using (
  (select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "crear consultas" on public.consultas_stock for insert to authenticated with check (
  ((select auth.uid()) = cliente_id and estado = 'Pendiente'
    and exists (select 1 from public.comercios c where c.id = consultas_stock.perfil_id and c.activo and c.plan = 'basico' and c.ofrece_consulta))
  or (select es_admin()));
create policy "editar consultas" on public.consultas_stock for update to authenticated
  using (es_dueno_perfil(perfil_id) or (select es_admin()))
  with check (es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "borrar consultas" on public.consultas_stock for delete to authenticated using ((select es_admin()));

-- ===== viajes =====
drop policy if exists "admin viajes" on public.viajes;
drop policy if exists "cliente crea viaje" on public.viajes;
drop policy if exists "cliente y transportista ven viajes" on public.viajes;
drop policy if exists "cliente y transportista actualizan viajes" on public.viajes;
create policy "leer viajes" on public.viajes for select to authenticated using (
  (select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "crear viajes" on public.viajes for insert to authenticated with check (
  ((select auth.uid()) = cliente_id and estado = 'Solicitada'
    and exists (select 1 from public.servicios_perfiles p where p.id = viajes.perfil_id and p.activo and p.tipo = 'transporte'))
  or (select es_admin()));
create policy "editar viajes" on public.viajes for update to authenticated
  using ((select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()))
  with check ((select auth.uid()) = cliente_id or es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "borrar viajes" on public.viajes for delete to authenticated using ((select es_admin()));

-- ===== cobros_transporte =====
drop policy if exists "admin cobros transporte" on public.cobros_transporte;
drop policy if exists "transportista ve sus cobros" on public.cobros_transporte;
create policy "leer cobros transporte"   on public.cobros_transporte for select to authenticated using (es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "crear cobros transporte"  on public.cobros_transporte for insert to authenticated with check ((select es_admin()));
create policy "editar cobros transporte" on public.cobros_transporte for update to authenticated using ((select es_admin())) with check ((select es_admin()));
create policy "borrar cobros transporte" on public.cobros_transporte for delete to authenticated using ((select es_admin()));

-- ===== servicios_perfiles =====
drop policy if exists "admin servicios" on public.servicios_perfiles;
drop policy if exists "todos ven servicios activos" on public.servicios_perfiles;
drop policy if exists "dueno edita su servicio" on public.servicios_perfiles;
create policy "leer servicios"   on public.servicios_perfiles for select to public        using (activo or dueno_id = (select auth.uid()) or (select es_admin()));
create policy "crear servicios"  on public.servicios_perfiles for insert to authenticated with check ((select es_admin()));
create policy "editar servicios" on public.servicios_perfiles for update to authenticated
  using (dueno_id = (select auth.uid()) or (select es_admin()))
  with check (dueno_id = (select auth.uid()) or (select es_admin()));
create policy "borrar servicios" on public.servicios_perfiles for delete to authenticated using ((select es_admin()));

-- ===== servicios_items =====
drop policy if exists "admin items servicios" on public.servicios_items;
drop policy if exists "dueno gestiona items" on public.servicios_items;
drop policy if exists "todos ven items" on public.servicios_items;
create policy "leer items servicios"   on public.servicios_items for select to public        using (activo or es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "crear items servicios"  on public.servicios_items for insert to authenticated with check (es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "editar items servicios" on public.servicios_items for update to authenticated
  using (es_dueno_perfil(perfil_id) or (select es_admin()))
  with check (es_dueno_perfil(perfil_id) or (select es_admin()));
create policy "borrar items servicios" on public.servicios_items for delete to authenticated using (es_dueno_perfil(perfil_id) or (select es_admin()));

commit;
