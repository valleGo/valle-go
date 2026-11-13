-- Valle GO v171 · Planes nuevos (12 nov 2026)
--   SERVICIOS = plan Simple ($299/mes IVA incluido): agenda y citas, tarjeta en el DIRECTORIO, reporte mensual corto.
--   PRODUCTOS = plan Básico ($549/mes IVA incluido): todo lo del Simple + página principal, menú, pedidos, consulta de stock, informe completo.
--   Comisión de uso de la app: 3% de pedidos y citas atendidas (ambos planes). Transportistas (SERVICIOS): 5% de cada viaje completado.
--   Promoción de apertura (primeros 20): mes 1 gratis + 20% de descuento en los meses 2, 3 y 4.
-- Se puede correr más de una vez.

-- 1) Citas: ahora también para el plan Simple (SERVICIOS). La consulta de stock sigue siendo solo del Básico.
drop policy if exists "crear citas" on public.citas;
create policy "crear citas" on public.citas for insert with check (
  ((select auth.uid()) = cliente_id and estado = 'Solicitada'
    and exists (select 1 from public.comercios c where c.id = citas.perfil_id and c.activo and c.ofrece_citas))
  or (select es_admin()));

-- 1b) El trigger del plan Simple ya no apaga las citas (solo la consulta de stock)
create or replace function public.comercio_plan_simple_sin_servicios()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.plan = 'simple' then new.ofrece_consulta := false; end if;
  return new;
end $$;

-- 2) Comisión de citas: 3%
create or replace function public.cita_comision()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.estado = 'Completada' and old.estado <> 'Completada' then
    if new.monto is null or new.monto <= 0 then raise exception 'Escribe el total cobrado por la cita'; end if;
    new.comision := round(new.monto * 0.03, 2);   -- 3% de uso de la app (desde v171)
    new.completado_en := now();
    new.mes := to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM');
  elsif old.estado = 'Completada' and not es_admin() then
    new.monto := old.monto; new.comision := old.comision;
    new.completado_en := old.completado_en; new.mes := old.mes;
  elsif new.estado <> 'Completada' then
    new.comision := null; new.completado_en := null; new.mes := null;
  end if;
  if es_admin() and new.estado = 'Completada' and new.monto is distinct from old.monto and new.monto > 0 then
    new.comision := round(new.monto * 0.03, 2);
  end if;
  return new;
end $$;

-- 3) Promoción de apertura: mes en que empieza el mes gratis ('YYYY-MM'). Vacío = sin promoción.
alter table public.comercios add column if not exists promo_inicio text;
alter table public.servicios_perfiles add column if not exists promo_inicio text;

create or replace function public.promo_cupo()
returns trigger language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if new.promo_inicio is null or new.promo_inicio = '' then new.promo_inicio := null; return new; end if;
  if new.promo_inicio !~ '^\d{4}-(0[1-9]|1[0-2])$' then raise exception 'Mes de inicio de la promoción inválido (usa AAAA-MM)'; end if;
  if tg_op = 'UPDATE' and old.promo_inicio is not distinct from new.promo_inicio then return new; end if;
  if not es_admin() then raise exception 'Solo el administrador asigna la promoción'; end if;
  select (select count(*) from comercios where promo_inicio is not null and id <> new.id)
       + (select count(*) from servicios_perfiles where promo_inicio is not null and id <> new.id) into n;
  if n >= 20 then raise exception 'La promoción de apertura ya tiene sus 20 lugares ocupados'; end if;
  return new;
end $$;

drop trigger if exists promo_cupo on public.comercios;
create trigger promo_cupo before insert or update of promo_inicio on public.comercios
  for each row execute function public.promo_cupo();
drop trigger if exists promo_cupo on public.servicios_perfiles;
create trigger promo_cupo before insert or update of promo_inicio on public.servicios_perfiles
  for each row execute function public.promo_cupo();
revoke execute on function public.promo_cupo() from public, anon, authenticated;

-- 4) Subcategorías: cada una pertenece a SERVICIOS o PRODUCTOS
alter table public.categorias add column if not exists grupo text not null default 'productos';
alter table public.categorias drop constraint if exists categorias_grupo_chk;
alter table public.categorias add constraint categorias_grupo_chk check (grupo in ('servicios','productos'));
update public.categorias set grupo = 'servicios' where nombre ilike any (array['%tatu%','%spa%','%masaj%','%transport%','%doctor%','%m_dic%','%consult%','%est_tica%','%barber%','%sal_n%']);

-- 5) Reclasificación (12 nov 2026): servicios con citas → Simple; quien vende producto → Básico
update public.comercios set plan = 'simple', ofrece_citas = true, ofrece_consulta = false where nombre in ('Estudio de Tatuajes','Masajes El Oasis');
update public.comercios set plan = 'basico' where nombre = 'Drink & Fly';
