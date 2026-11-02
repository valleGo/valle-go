-- VALLE GO · Hacerte administrador
-- 1) Regístrate primero en la app con tu correo.
-- 2) Cambia el correo de abajo por el TUYO (el mismo del registro) y ejecuta.
insert into admins (user_id)
select id from auth.users where email = 'tu-correo@ejemplo.com'
on conflict do nothing;

-- Comprueba que funcionó (debe aparecer 1 fila con tu correo):
select u.email from admins a join auth.users u on u.id = a.user_id;
