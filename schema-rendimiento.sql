-- Ajustes de rendimiento de la base (v152). Ya aplicado en Supabase; se guarda aquí como respaldo.
-- No cambia quién puede ver o editar qué: solo hace las consultas más rápidas.

-- 1) Índices para las llaves foráneas (búsquedas por comercio, dueño, cliente, etc.)
create index if not exists comercios_categoria_idx        on public.comercios (categoria_id);
create index if not exists comercios_dueno_idx            on public.comercios (dueno_id);
create index if not exists menu_items_comercio_idx        on public.menu_items (comercio_id);
create index if not exists pedidos_comercio_idx           on public.pedidos (comercio_id);
create index if not exists pedidos_comprador_idx          on public.pedidos (comprador_id);
create index if not exists push_suscripciones_user_idx    on public.push_suscripciones (user_id);
create index if not exists mp_oauth_estado_comercio_idx   on public.mp_oauth_estado (comercio_id);
create index if not exists cobros_pagos_comercio_idx      on public.cobros_pagos (comercio_id);
create index if not exists servicios_perfiles_dueno_idx   on public.servicios_perfiles (dueno_id);
create index if not exists servicios_items_perfil_idx     on public.servicios_items (perfil_id);
create index if not exists citas_servicio_idx             on public.citas (servicio_id);
create index if not exists cobros_transporte_perfil_idx   on public.cobros_transporte (perfil_id);

-- 2) Reglas RLS: auth.uid() y es_admin() se evalúan una sola vez por consulta en lugar de una vez por fila.
--    Misma lógica exacta, solo envuelta en (select ...).
do $$
declare p record; q text; w text; s text;
begin
  for p in select tablename, policyname, qual, with_check from pg_policies where schemaname = 'public' loop
    q := p.qual; w := p.with_check;
    if q is not null then
      q := replace(replace(q, '(select auth.uid())', 'auth.uid()'), '(select es_admin())', 'es_admin()');
      q := replace(replace(q, 'auth.uid()', '(select auth.uid())'), 'es_admin()', '(select es_admin())');
    end if;
    if w is not null then
      w := replace(replace(w, '(select auth.uid())', 'auth.uid()'), '(select es_admin())', 'es_admin()');
      w := replace(replace(w, 'auth.uid()', '(select auth.uid())'), 'es_admin()', '(select es_admin())');
    end if;
    if q is distinct from p.qual or w is distinct from p.with_check then
      s := format('alter policy %I on public.%I', p.policyname, p.tablename);
      if q is not null then s := s || ' using (' || q || ')'; end if;
      if w is not null then s := s || ' with check (' || w || ')'; end if;
      execute s;
    end if;
  end loop;
end $$;
