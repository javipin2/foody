-- Datos de demostración: 3 ciudades (Bogotá, Medellín, Cali), 3 restaurantes,
-- 2 sedes por restaurante (Norte/Sur + nombre), menú de 5 productos por sede.
-- Ejecutar DESPUÉS de supabase/sql/000_schema_completo.sql

-- ========== Ciudades ==========
insert into public.ciudades (id, nombre, codigo, activa, created_at, updated_at)
values
  ('ciu-bog', 'Bogotá', 'BOG', true, now(), now()),
  ('ciu-med', 'Medellín', 'MED', true, now(), now()),
  ('ciu-cal', 'Cali', 'CAL', true, now(), now())
on conflict (id) do update set
  nombre = excluded.nombre,
  codigo = excluded.codigo,
  activa = excluded.activa,
  updated_at = now();

-- ========== Lugares (un restaurante por ciudad) ==========
insert into public.lugares (
  id, ciudad_id, nombre, direccion, telefono, activo, foto_url,
  plan, plan_inicio, plan_ultimo_pago, plan_valor_mensual, updated_at
)
values
  (
    'lug-tremendo-pollo',
    'ciu-bog',
    'Tremendo Pollo',
    'Av. Caracas # 45-12',
    '6015550101',
    true,
    'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=1200',
    'pro',
    now(),
    now(),
    199000,
    now()
  ),
  (
    'lug-comida-china',
    'ciu-med',
    'Comida China',
    'Cra 43A # 10-20',
    '6044440202',
    true,
    'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=1200',
    'pro',
    now(),
    now(),
    189000,
    now()
  ),
  (
    'lug-carne-asada',
    'ciu-cal',
    'Carne Asada',
    'Calle 9 # 40-15',
    '6023330303',
    true,
    'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200',
    'premium',
    now(),
    now(),
    249000,
    now()
  )
on conflict (id) do update set
  ciudad_id = excluded.ciudad_id,
  nombre = excluded.nombre,
  direccion = excluded.direccion,
  telefono = excluded.telefono,
  activo = excluded.activo,
  foto_url = excluded.foto_url,
  plan = excluded.plan,
  updated_at = now();

-- ========== Sedes (Norte / Sur + nombre del restaurante) ==========
insert into public.sedes (
  id, lugar_id, nombre, descripcion, imagen, ubicacion, latitud, longitud, activa, created_at
)
values
  (
    'sed-tp-norte',
    'lug-tremendo-pollo',
    'Sede Norte — Tremendo Pollo',
    'Pollo a la brasa y combos familiares',
    'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=1200',
    'Zona Norte',
    4.710989,
    -74.072092,
    true,
    now()
  ),
  (
    'sed-tp-sur',
    'lug-tremendo-pollo',
    'Sede Sur — Tremendo Pollo',
    'Pollo a la brasa y combos familiares',
    'https://images.unsplash.com/photo-1608039829572-19624f79cfcb?w=1200',
    'Zona Sur',
    4.579653,
    -74.153481,
    true,
    now()
  ),
  (
    'sed-cc-norte',
    'lug-comida-china',
    'Sede Norte — Comida China',
    'Cocina china y combos al wok',
    'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=1200',
    'Zona Norte',
    6.247638,
    -75.565815,
    true,
    now()
  ),
  (
    'sed-cc-sur',
    'lug-comida-china',
    'Sede Sur — Comida China',
    'Cocina china y combos al wok',
    'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=1200',
    'Zona Sur',
    6.155065,
    -75.635193,
    true,
    now()
  ),
  (
    'sed-ca-norte',
    'lug-carne-asada',
    'Sede Norte — Carne Asada',
    'Parrilla y cortes premium',
    'https://images.unsplash.com/photo-1558030006-450675393462?w=1200',
    'Zona Norte',
    3.451792,
    -76.532494,
    true,
    now()
  ),
  (
    'sed-ca-sur',
    'lug-carne-asada',
    'Sede Sur — Carne Asada',
    'Parrilla y cortes premium',
    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=1200',
    'Zona Sur',
    3.395233,
    -76.523842,
    true,
    now()
  )
on conflict (id) do update set
  lugar_id = excluded.lugar_id,
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  imagen = excluded.imagen,
  ubicacion = excluded.ubicacion,
  latitud = excluded.latitud,
  longitud = excluded.longitud,
  activa = excluded.activa;

-- ========== Config app ==========
insert into public.app_config (key, value, updated_at)
values (
  'version_control',
  '{
    "current_version": "1.3.0",
    "minimum_required_version": "1.3.0",
    "force_update": false,
    "update_message": "Nueva version disponible con mejoras importantes",
    "download_url": "https://tu-servidor.com/app-release.apk",
    "is_play_store_available": false,
    "play_store_url": "https://play.google.com/store/apps/details?id=com.tuempresa.reserva_canchas",
    "last_updated": "2026-02-21T11:31:40.000Z",
    "new_features": ["Mejoras en la interfaz de usuario", "Correccion de errores menores", "Optimizacion de rendimiento"],
    "maintenance_mode": false,
    "maintenance_message": "La aplicacion esta temporalmente en mantenimiento. Intenta mas tarde."
  }'::jsonb,
  now()
)
on conflict (key) do update set
  value = excluded.value,
  updated_at = excluded.updated_at;

-- ========== Staff demo (ajusta id a tu UID de Firebase Auth si usas admin) ==========
insert into public.staff_profiles (id, email, nombre, rol, lugar_id, ciudad_id, activo, updated_at)
values
  ('demo-admin-uid', 'admin@demo.com', 'Admin Demo', 'admin', 'lug-tremendo-pollo', 'ciu-bog', true, now()),
  ('demo-caja-uid', 'caja@demo.com', 'Caja Demo', 'encargado', 'lug-tremendo-pollo', 'ciu-bog', true, now()),
  ('demo-cocina-uid', 'cocina@demo.com', 'Cocina Demo', 'admin', 'lug-tremendo-pollo', 'ciu-bog', true, now())
on conflict (id) do update set
  email = excluded.email,
  nombre = excluded.nombre,
  rol = excluded.rol,
  lugar_id = excluded.lugar_id,
  ciudad_id = excluded.ciudad_id,
  activo = excluded.activo,
  updated_at = now();

-- ========== Categorías de menú (una por sede) ==========
insert into public.menu_categorias (id, sede_id, nombre, orden, activa)
values
  ('a1000000-0000-4000-8000-000000000001', 'sed-tp-norte', 'Menú Tremendo Pollo', 1, true),
  ('a1000000-0000-4000-8000-000000000002', 'sed-tp-sur', 'Menú Tremendo Pollo', 1, true),
  ('a1000000-0000-4000-8000-000000000003', 'sed-cc-norte', 'Menú Comida China', 1, true),
  ('a1000000-0000-4000-8000-000000000004', 'sed-cc-sur', 'Menú Comida China', 1, true),
  ('a1000000-0000-4000-8000-000000000005', 'sed-ca-norte', 'Menú Carne Asada', 1, true),
  ('a1000000-0000-4000-8000-000000000006', 'sed-ca-sur', 'Menú Carne Asada', 1, true)
on conflict (id) do update set
  sede_id = excluded.sede_id,
  nombre = excluded.nombre,
  orden = excluded.orden,
  activa = excluded.activa;

-- ========== Productos (5 por sede) ==========
insert into public.menu_productos (id, sede_id, categoria_id, nombre, descripcion, precio, imagen_url, activo, orden)
values
  -- Tremendo Pollo — Norte
  ('b1000000-0000-4000-8000-000000000001', 'sed-tp-norte', 'a1000000-0000-4000-8000-000000000001', 'Combo familiar pollo asado', 'Pollo entero + papas + ensalada + gaseosas', 89900, 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=800', true, 1),
  ('b1000000-0000-4000-8000-000000000002', 'sed-tp-norte', 'a1000000-0000-4000-8000-000000000001', 'Pechuga a la plancha', 'Con arroz y ensalada', 32900, 'https://images.unsplash.com/photo-1608039829572-19624f79cfcb?w=800', true, 2),
  ('b1000000-0000-4000-8000-000000000003', 'sed-tp-norte', 'a1000000-0000-4000-8000-000000000001', 'Alitas BBQ x12', 'Salsa BBQ de la casa', 38900, 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=800', true, 3),
  ('b1000000-0000-4000-8000-000000000004', 'sed-tp-norte', 'a1000000-0000-4000-8000-000000000001', 'Papas supremas', 'Queso, tocineta y pico de gallo', 21900, 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800', true, 4),
  ('b1000000-0000-4000-8000-000000000005', 'sed-tp-norte', 'a1000000-0000-4000-8000-000000000001', 'Gaseosa 400 ml', 'Bebida fría', 5000, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=800', true, 5),
  -- Tremendo Pollo — Sur
  ('b1000000-0000-4000-8000-000000000011', 'sed-tp-sur', 'a1000000-0000-4000-8000-000000000002', 'Combo familiar pollo asado', 'Pollo entero + papas + ensalada + gaseosas', 89900, 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=800', true, 1),
  ('b1000000-0000-4000-8000-000000000012', 'sed-tp-sur', 'a1000000-0000-4000-8000-000000000002', 'Pechuga a la plancha', 'Con arroz y ensalada', 32900, 'https://images.unsplash.com/photo-1608039829572-19624f79cfcb?w=800', true, 2),
  ('b1000000-0000-4000-8000-000000000013', 'sed-tp-sur', 'a1000000-0000-4000-8000-000000000002', 'Alitas BBQ x12', 'Salsa BBQ de la casa', 38900, 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=800', true, 3),
  ('b1000000-0000-4000-8000-000000000014', 'sed-tp-sur', 'a1000000-0000-4000-8000-000000000002', 'Papas supremas', 'Queso, tocineta y pico de gallo', 21900, 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800', true, 4),
  ('b1000000-0000-4000-8000-000000000015', 'sed-tp-sur', 'a1000000-0000-4000-8000-000000000002', 'Gaseosa 400 ml', 'Bebida fría', 5000, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=800', true, 5),
  -- Comida China — Norte
  ('b1000000-0000-4000-8000-000000000021', 'sed-cc-norte', 'a1000000-0000-4000-8000-000000000003', 'Arroz chaufa especial', 'Pollo, cerdo y camarón', 36900, 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800', true, 1),
  ('b1000000-0000-4000-8000-000000000022', 'sed-cc-norte', 'a1000000-0000-4000-8000-000000000003', 'Chop suey mixto', 'Verduras salteadas y carnes', 34900, 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800', true, 2),
  ('b1000000-0000-4000-8000-000000000023', 'sed-cc-norte', 'a1000000-0000-4000-8000-000000000003', 'Wantán frito x8', 'Acompañado de salsa agridulce', 18900, 'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=800', true, 3),
  ('b1000000-0000-4000-8000-000000000024', 'sed-cc-norte', 'a1000000-0000-4000-8000-000000000003', 'Tallarines saltados', 'Estilo chifa con verduras', 31900, 'https://images.unsplash.com/photo-1617093727343-374948b05b83?w=800', true, 4),
  ('b1000000-0000-4000-8000-000000000025', 'sed-cc-norte', 'a1000000-0000-4000-8000-000000000003', 'Té helado', 'Té negro con limón', 6000, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=800', true, 5),
  -- Comida China — Sur
  ('b1000000-0000-4000-8000-000000000031', 'sed-cc-sur', 'a1000000-0000-4000-8000-000000000004', 'Arroz chaufa especial', 'Pollo, cerdo y camarón', 36900, 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800', true, 1),
  ('b1000000-0000-4000-8000-000000000032', 'sed-cc-sur', 'a1000000-0000-4000-8000-000000000004', 'Chop suey mixto', 'Verduras salteadas y carnes', 34900, 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800', true, 2),
  ('b1000000-0000-4000-8000-000000000033', 'sed-cc-sur', 'a1000000-0000-4000-8000-000000000004', 'Wantán frito x8', 'Acompañado de salsa agridulce', 18900, 'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=800', true, 3),
  ('b1000000-0000-4000-8000-000000000034', 'sed-cc-sur', 'a1000000-0000-4000-8000-000000000004', 'Tallarines saltados', 'Estilo chifa con verduras', 31900, 'https://images.unsplash.com/photo-1617093727343-374948b05b83?w=800', true, 4),
  ('b1000000-0000-4000-8000-000000000035', 'sed-cc-sur', 'a1000000-0000-4000-8000-000000000004', 'Té helado', 'Té negro con limón', 6000, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=800', true, 5),
  -- Carne Asada — Norte
  ('b1000000-0000-4000-8000-000000000041', 'sed-ca-norte', 'a1000000-0000-4000-8000-000000000005', 'Picada tres carnes', 'Para compartir: chicharrón, chorizo y carne', 129900, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800', true, 1),
  ('b1000000-0000-4000-8000-000000000042', 'sed-ca-norte', 'a1000000-0000-4000-8000-000000000005', 'Churrasco argentino', 'Con chimichurri y papas', 67900, 'https://images.unsplash.com/photo-1558030006-450675393462?w=800', true, 2),
  ('b1000000-0000-4000-8000-000000000043', 'sed-ca-norte', 'a1000000-0000-4000-8000-000000000005', 'Costillas BBQ', 'Media bandeja glaseada', 58900, 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800', true, 3),
  ('b1000000-0000-4000-8000-000000000044', 'sed-ca-norte', 'a1000000-0000-4000-8000-000000000005', 'Morcilla artesanal', 'Porción para compartir', 24900, 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=800', true, 4),
  ('b1000000-0000-4000-8000-000000000045', 'sed-ca-norte', 'a1000000-0000-4000-8000-000000000005', 'Limonada de panela', 'Jarra 1 L', 12000, 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=800', true, 5),
  -- Carne Asada — Sur
  ('b1000000-0000-4000-8000-000000000051', 'sed-ca-sur', 'a1000000-0000-4000-8000-000000000006', 'Picada tres carnes', 'Para compartir: chicharrón, chorizo y carne', 129900, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800', true, 1),
  ('b1000000-0000-4000-8000-000000000052', 'sed-ca-sur', 'a1000000-0000-4000-8000-000000000006', 'Churrasco argentino', 'Con chimichurri y papas', 67900, 'https://images.unsplash.com/photo-1558030006-450675393462?w=800', true, 2),
  ('b1000000-0000-4000-8000-000000000053', 'sed-ca-sur', 'a1000000-0000-4000-8000-000000000006', 'Costillas BBQ', 'Media bandeja glaseada', 58900, 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800', true, 3),
  ('b1000000-0000-4000-8000-000000000054', 'sed-ca-sur', 'a1000000-0000-4000-8000-000000000006', 'Morcilla artesanal', 'Porción para compartir', 24900, 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=800', true, 4),
  ('b1000000-0000-4000-8000-000000000055', 'sed-ca-sur', 'a1000000-0000-4000-8000-000000000006', 'Limonada de panela', 'Jarra 1 L', 12000, 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=800', true, 5)
on conflict (id) do update set
  sede_id = excluded.sede_id,
  categoria_id = excluded.categoria_id,
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  precio = excluded.precio,
  imagen_url = excluded.imagen_url,
  activo = excluded.activo,
  orden = excluded.orden;

-- ========== Pedido demo (cocina / pruebas) ==========
insert into public.pedidos (id, lugar_id, sede_id, estado, origen, observaciones, total, created_at, updated_at)
values
  (
    'c0000000-0000-4000-8000-000000000099',
    'lug-tremendo-pollo',
    'sed-tp-norte',
    'nuevo',
    'demo_seed',
    'Sin cebolla, por favor',
    121800,
    now() - interval '12 minutes',
    now()
  )
on conflict (id) do update set
  lugar_id = excluded.lugar_id,
  sede_id = excluded.sede_id,
  estado = excluded.estado,
  total = excluded.total,
  updated_at = now();

insert into public.pedido_items (id, pedido_id, producto_id, producto_nombre, precio_unitario, cantidad, subtotal)
values
  (
    'd0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000099',
    'b1000000-0000-4000-8000-000000000001',
    'Combo familiar pollo asado',
    89900,
    1,
    89900
  ),
  (
    'd0000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000099',
    'b1000000-0000-4000-8000-000000000003',
    'Alitas BBQ x12',
    38900,
    1,
    38900
  )
on conflict (id) do update set
  pedido_id = excluded.pedido_id,
  producto_id = excluded.producto_id,
  producto_nombre = excluded.producto_nombre,
  precio_unitario = excluded.precio_unitario,
  cantidad = excluded.cantidad,
  subtotal = excluded.subtotal;
