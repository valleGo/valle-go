-- VALLE GO · Datos de prueba (genéricos). Ejecútalo DESPUÉS de todo-en-uno.sql.
-- Los datos bancarios y WhatsApp son FALSOS: cámbialos desde el Panel de administración.

insert into comercios (id, nombre, giro, descripcion, horario, emoji, whatsapp, envio, minimo, banco, titular, clabe) values
 ('a0000000-0000-4000-8000-000000000001','Tacos de Prueba','Taquería','Tacos al pastor y de guisado hechos al momento.','1:00 pm - 10:00 pm','🌮','5210000000001',30,80,'Banco de Prueba','Comercio de Prueba','000000000000000001'),
 ('a0000000-0000-4000-8000-000000000002','Panadería de Prueba','Panadería','Pan dulce y de sal recién horneado todos los días.','7:00 am - 8:00 pm','🥐','5210000000002',25,60,'Banco de Prueba','Comercio de Prueba','000000000000000002'),
 ('a0000000-0000-4000-8000-000000000003','Café de Prueba','Cafetería','Café de la región, bebidas frías y postres.','8:00 am - 9:00 pm','☕','5210000000003',20,50,null,null,null)
on conflict (id) do nothing;

insert into menu_items (id, comercio_id, categoria, nombre, descripcion, precio, emoji) values
 ('b0000000-0000-4000-8000-000000000101','a0000000-0000-4000-8000-000000000001','Tacos','Taco al pastor','Con piña y cilantro',22,'🌮'),
 ('b0000000-0000-4000-8000-000000000102','a0000000-0000-4000-8000-000000000001','Tacos','Taco de bistec','Con cebolla asada',25,'🥩'),
 ('b0000000-0000-4000-8000-000000000103','a0000000-0000-4000-8000-000000000001','Antojitos','Gringa','Tortilla de harina, queso y pastor',55,'🧀'),
 ('b0000000-0000-4000-8000-000000000104','a0000000-0000-4000-8000-000000000001','Bebidas','Agua de horchata 1 L','Hecha en casa',40,'🥛'),
 ('b0000000-0000-4000-8000-000000000201','a0000000-0000-4000-8000-000000000002','Pan dulce','Concha','Vainilla o chocolate',12,'🥯'),
 ('b0000000-0000-4000-8000-000000000202','a0000000-0000-4000-8000-000000000002','Pan dulce','Caja de 12 piezas','Surtido del día',130,'🥐'),
 ('b0000000-0000-4000-8000-000000000203','a0000000-0000-4000-8000-000000000002','Pasteles','Rebanada de pastel tres leches','Porción individual',48,'🍰'),
 ('b0000000-0000-4000-8000-000000000301','a0000000-0000-4000-8000-000000000003','Café','Café americano','Grano de la región',35,'☕'),
 ('b0000000-0000-4000-8000-000000000302','a0000000-0000-4000-8000-000000000003','Café','Capuchino','Con espuma de leche',48,'☕'),
 ('b0000000-0000-4000-8000-000000000303','a0000000-0000-4000-8000-000000000003','Postres','Pay de limón','Rebanada',45,'🥧')
on conflict (id) do nothing;

-- Anuncios de ejemplo (imágenes simples incluidas en el propio dato; bórralos desde el Panel y sube los tuyos)
insert into anuncios (id, titulo, imagen_url, enlace, orden) values
 ('c0000000-0000-4000-8000-000000000001','Demo: Bienvenido a Valle GO','data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 500"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="%231f5f4a"/><stop offset="1" stop-color="%234fae8a"/></linearGradient></defs><rect width="1200" height="500" fill="url(%23g)"/><text x="600" y="235" font-family="Georgia,serif" font-size="84" fill="%23fbf7f0" text-anchor="middle">Valle GO</text><text x="600" y="320" font-family="Georgia,serif" font-size="40" fill="%23fbf7f0" text-anchor="middle">Pide a los comercios de tu valle</text></svg>',null,1),
 ('c0000000-0000-4000-8000-000000000002','Demo: Tacos de Prueba','data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 500"><rect width="1200" height="500" fill="%23e8a33d"/><text x="600" y="235" font-family="Georgia,serif" font-size="84" fill="%2322302b" text-anchor="middle">Taquería de Prueba</text><text x="600" y="320" font-family="Georgia,serif" font-size="40" fill="%2322302b" text-anchor="middle">Tacos al pastor desde $22</text></svg>','#/t/a0000000-0000-4000-8000-000000000001',2),
 ('c0000000-0000-4000-8000-000000000003','Demo: Anuncia aquí','data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 500"><rect width="1200" height="500" fill="%2322302b"/><text x="600" y="235" font-family="Georgia,serif" font-size="84" fill="%23fbf7f0" text-anchor="middle">Tu anuncio aquí</text><text x="600" y="320" font-family="Georgia,serif" font-size="40" fill="%23e8a33d" text-anchor="middle">Sube tu imagen desde el panel</text></svg>',null,3)
on conflict (id) do nothing;

-- Para BORRAR los datos de prueba cuando ya tengas los tuyos:
-- delete from comercios where id::text like 'a0000000-0000-4000-8000-%';
-- delete from anuncios where id::text like 'c0000000-0000-4000-8000-%';
