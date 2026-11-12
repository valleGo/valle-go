-- Valle GO v169 · 1% de las citas atendidas (12 nov 2026)
-- Al marcar una cita como Completada, el comercio escribe el total cobrado (monto).
-- El trigger calcula el 1% (comision) y el mes del corte, igual que viaje_comision para viajes.
-- Se puede correr más de una vez.

alter table public.citas add column if not exists monto numeric(12,2);
alter table public.citas add column if not exists comision numeric(12,2);
alter table public.citas add column if not exists completado_en timestamptz;
alter table public.citas add column if not exists mes text;

create or replace function public.cita_comision()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.estado = 'Completada' and old.estado <> 'Completada' then
    if new.monto is null or new.monto <= 0 then raise exception 'Escribe el total cobrado por la cita'; end if;
    new.comision := round(new.monto * 0.01, 2);   -- 1% de uso de la app (Condiciones v168)
    new.completado_en := now();
    new.mes := to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM');
  elsif old.estado = 'Completada' and not es_admin() then
    -- una vez atendida, solo el administrador corrige el monto
    new.monto := old.monto; new.comision := old.comision;
    new.completado_en := old.completado_en; new.mes := old.mes;
  elsif new.estado <> 'Completada' then
    new.comision := null; new.completado_en := null; new.mes := null;
  end if;
  if es_admin() and new.estado = 'Completada' and new.monto is distinct from old.monto and new.monto > 0 then
    new.comision := round(new.monto * 0.01, 2);
  end if;
  return new;
end $$;

drop trigger if exists cita_comision on public.citas;
create trigger cita_comision before update on public.citas
  for each row execute function public.cita_comision();

-- El cliente no puede tocar el monto (se agrega a las reglas de limitar_cambios_cita)
create or replace function public.limitar_cambios_cita()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.cambio_por := auth.uid();
  if es_admin() then new.actualizado := now(); return new; end if;
  if new.perfil_id is distinct from old.perfil_id or new.cliente_id is distinct from old.cliente_id
     or new.servicio_id is distinct from old.servicio_id or new.servicio_nombre is distinct from old.servicio_nombre
     or new.cliente_nombre is distinct from old.cliente_nombre or new.cliente_tel is distinct from old.cliente_tel
     or new.creado is distinct from old.creado then
    raise exception 'Cambio no permitido';
  end if;
  if es_dueno_perfil(old.perfil_id) then
    if new.notas is distinct from old.notas then raise exception 'Cambio no permitido'; end if;
  else
    if not (new.estado = 'Cancelada' or (old.estado = 'Reprogramada' and new.estado = 'Confirmada'))
       or new.fecha is distinct from old.fecha or new.hora is distinct from old.hora
       or new.notas is distinct from old.notas or new.respuesta is distinct from old.respuesta
       or new.monto is distinct from old.monto then
      raise exception 'Solo puedes cancelar tu cita o aceptar la nueva hora';
    end if;
  end if;
  new.actualizado := now();
  return new;
end $$;

create index if not exists citas_mes_idx on public.citas (mes) where estado = 'Completada';
