-- Comisión de transporte (v164). Ya aplicado en Supabase; se guarda aquí como respaldo.
-- Al pasar un viaje a "Completada" se guarda la comisión de uso de la app: 5% del total cobrado (antes 7%).
create or replace function public.viaje_comision()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.estado = 'Completada' and old.estado <> 'Completada' then
    if new.precio_num is null or new.precio_num <= 0 then raise exception 'Escribe el total cobrado del viaje'; end if;
    new.comision := round(new.precio_num * 0.05, 2);   -- 5% de uso de la app (acordado el 11 nov 2026)
    new.completado_en := now();
    new.mes := to_char(now() at time zone 'America/Mexico_City', 'YYYY-MM');
  end if;
  return new;
end $function$;
