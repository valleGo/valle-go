-- Ajuste de rendimiento 2 (v157). Ya aplicado en Supabase; se guarda aquí como respaldo.
-- Las reglas que solo pueden cumplirse con sesión iniciada (admin o dueño del dato) se limitan al rol
-- "authenticated". Para un visitante sin sesión ya daban siempre "no", así que no cambia quién ve qué;
-- solo evita que se evalúen en cada consulta pública (comercios, menús, anuncios, categorías).
alter policy "admin anuncios"           on public.anuncios           to authenticated;
alter policy "admin categorias"         on public.categorias         to authenticated;
alter policy "admin citas"              on public.citas              to authenticated;
alter policy "admin cobros transporte"  on public.cobros_transporte  to authenticated;
alter policy "admin comercios"          on public.comercios          to authenticated;
alter policy "admin consultas"          on public.consultas_stock    to authenticated;
alter policy "admin menus"              on public.menu_items         to authenticated;
alter policy "admin pedidos"            on public.pedidos            to authenticated;
alter policy "admin items servicios"    on public.servicios_items    to authenticated;
alter policy "admin servicios"          on public.servicios_perfiles to authenticated;
alter policy "admin viajes"             on public.viajes             to authenticated;
alter policy "comprador crea pedidos"        on public.pedidos            to authenticated;
alter policy "comprador y dueño ven pedido"  on public.pedidos            to authenticated;
alter policy "mis suscripciones"             on public.push_suscripciones to authenticated;
alter policy "ver si soy admin"              on public.admins             to authenticated;
