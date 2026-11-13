-- Valle GO v178 · Revisión de seguridad (13 nov 2026). Ya aplicado. Se puede correr más de una vez.
-- Funciones de trigger: nadie debe poder llamarlas por la API
revoke execute on function public.cita_comision() from public, anon, authenticated;
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
-- Funciones que exigen sesión (todas revisan es_admin() o al dueño): sin acceso para visitantes sin cuenta
revoke execute on function public.admin_agregar_admin(text) from public, anon;
revoke execute on function public.admin_eliminar_usuario(uuid) from public, anon;
revoke execute on function public.admin_lista_admins() from public, anon;
revoke execute on function public.admin_quitar_admin(uuid) from public, anon;
revoke execute on function public.admin_usuarios() from public, anon;
revoke execute on function public.usuario_por_correo(text) from public, anon;
revoke execute on function public.cliente_confirmar_recibido(uuid) from public, anon;
grant execute on function public.admin_agregar_admin(text), public.admin_eliminar_usuario(uuid), public.admin_lista_admins(),
  public.admin_quitar_admin(uuid), public.admin_usuarios(), public.usuario_por_correo(text), public.cliente_confirmar_recibido(uuid) to authenticated;
-- Índice para el enlace de compra de consultas
create index if not exists consultas_stock_oferta_pedido_idx on public.consultas_stock (oferta_pedido_id) where oferta_pedido_id is not null;
-- Avisos que quedan a propósito: es_admin, es_dueno_perfil y contar_vecinos los usan las reglas RLS y la página de inicio;
-- pg_net en el esquema public (moverlo puede romper los avisos); contraseñas filtradas (requiere Supabase Pro).
