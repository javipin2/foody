-- Esquema único Supabase (paridad con colecciones Firestore del proyecto).
-- IDs tipo text = mismos IDs de documentos Firestore al importar datos.
-- RLS: por defecto DESACTIVADO: la app aún usa Firebase Auth + cliente anon.
-- Cuando migres login a Supabase Auth, activa RLS y políticas por rol.

-- ========== Geografía y establecimientos ==========
create table if not exists public.ciudades (
  id text primary key,
  nombre text not null,
  codigo text not null default '',
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_ciudades_activa_nombre on public.ciudades (activa, nombre);

create table if not exists public.lugares (
  id text primary key,
  ciudad_id text not null references public.ciudades (id) on delete restrict,
  nombre text not null,
  direccion text not null default '',
  telefono text not null default '',
  activo boolean not null default true,
  foto_url text,
  plan text,
  plan_inicio timestamptz,
  plan_valor_mensual numeric(12, 2),
  plan_ultimo_pago timestamptz,
  max_sedes int,
  max_canchas int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_lugares_ciudad_activo on public.lugares (ciudad_id, activo);

create table if not exists public.sedes (
  id text primary key,
  lugar_id text not null references public.lugares (id) on delete cascade,
  nombre text not null,
  imagen text,
  descripcion text,
  ubicacion text,
  latitud double precision,
  longitud double precision,
  activa boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_sedes_lugar_activa on public.sedes (lugar_id, activa);

-- ========== Staff (mismo id que Firebase Auth UID y doc usuarios) ==========
create table if not exists public.staff_profiles (
  id text primary key,
  email text not null,
  nombre text,
  rol text not null default 'usuario',
  lugar_id text references public.lugares (id),
  ciudad_id text references public.ciudades (id),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_staff_lugar on public.staff_profiles (lugar_id);

-- ========== Menú (restaurante) ==========
create table if not exists public.menu_categorias (
  id uuid primary key default gen_random_uuid(),
  sede_id text not null references public.sedes (id) on delete cascade,
  nombre text not null,
  orden int not null default 0,
  activa boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.menu_productos (
  id uuid primary key default gen_random_uuid(),
  sede_id text not null references public.sedes (id) on delete cascade,
  categoria_id uuid references public.menu_categorias (id) on delete set null,
  nombre text not null,
  descripcion text,
  precio numeric(12, 2) not null check (precio >= 0),
  imagen_url text,
  activo boolean not null default true,
  orden int not null default 0,
  created_at timestamptz not null default now()
);

-- Tablas creadas antes con sede_firestore_id: añadir sede_id y copiar (el índice va después).
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'menu_categorias'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_categorias' and column_name = 'sede_id'
  ) then
    alter table public.menu_categorias add column sede_id text;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'menu_categorias' and column_name = 'sede_firestore_id'
    ) then
      update public.menu_categorias c set sede_id = c.sede_firestore_id where c.sede_id is null;
      alter table public.menu_categorias drop column sede_firestore_id;
    end if;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'menu_productos'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_productos' and column_name = 'sede_id'
  ) then
    alter table public.menu_productos add column sede_id text;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'menu_productos' and column_name = 'sede_firestore_id'
    ) then
      update public.menu_productos p set sede_id = p.sede_firestore_id where p.sede_id is null;
      alter table public.menu_productos drop column sede_firestore_id;
    end if;
  end if;
end $$;

create index if not exists idx_menu_cat_sede on public.menu_categorias (sede_id);
create index if not exists idx_menu_prod_sede on public.menu_productos (sede_id);

-- ========== Pedidos (restaurante) ==========
create table if not exists public.pedidos (
  id uuid primary key default gen_random_uuid(),
  lugar_id text not null references public.lugares (id) on delete cascade,
  sede_id text not null references public.sedes (id) on delete cascade,
  estado text not null default 'nuevo',
  origen text not null default 'app',
  observaciones text,
  total numeric(12, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_pedidos_sede_estado
  on public.pedidos (sede_id, estado, created_at desc);

create table if not exists public.pedido_items (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  producto_id uuid references public.menu_productos (id) on delete set null,
  producto_nombre text not null,
  precio_unitario numeric(12, 2) not null,
  cantidad int not null check (cantidad > 0),
  subtotal numeric(12, 2) not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_pedido_items_pedido on public.pedido_items (pedido_id);

-- ========== Canchas (legado reservas) ==========
create table if not exists public.canchas (
  id text primary key,
  lugar_id text references public.lugares (id),
  sede_id text not null references public.sedes (id) on delete cascade,
  nombre text not null,
  descripcion text not null default '',
  imagen text,
  techada boolean not null default false,
  ubicacion text not null default '',
  precio numeric(12, 2) not null default 0,
  precios_por_horario jsonb not null default '{}'::jsonb,
  disponible boolean not null default true,
  motivo_no_disponible text
);
create index if not exists idx_canchas_sede on public.canchas (sede_id);

-- ========== Clientes ==========
create table if not exists public.clientes (
  id text primary key,
  lugar_id text references public.lugares (id),
  nombre text not null,
  telefono text not null,
  created_at timestamptz default now()
);

-- ========== Reservas ==========
create table if not exists public.reservas (
  id text primary key,
  lugar_id text references public.lugares (id),
  sede_id text references public.sedes (id),
  cancha_id text references public.canchas (id),
  fecha date not null,
  horario text not null,
  sede_nombre text,
  tipo_abono text,
  monto_total numeric(12, 2) not null default 0,
  monto_pagado numeric(12, 2) not null default 0,
  nombre text,
  telefono text,
  confirmada boolean not null default false,
  grupo_reserva_id text,
  total_horas_grupo int,
  precio_personalizado boolean not null default false,
  precio_original numeric(12, 2),
  descuento_aplicado numeric(12, 2),
  horarios jsonb,
  reserva_recurrente_id text,
  es_reserva_recurrente boolean not null default false,
  abono_entregado boolean,
  promocion_id text,
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_reservas_sede_fecha on public.reservas (sede_id, fecha);
create index if not exists idx_reservas_lugar on public.reservas (lugar_id);

create table if not exists public.reservas_recurrentes (
  id text primary key,
  lugar_id text references public.lugares (id),
  cliente_id text,
  cliente_nombre text,
  cliente_telefono text,
  cancha_id text references public.canchas (id),
  sede_id text references public.sedes (id),
  sede_nombre text,
  horario text not null,
  dias_semana jsonb not null default '[]'::jsonb,
  tipo_recurrencia text not null,
  estado text not null,
  fecha_inicio date not null,
  fecha_fin date,
  monto_total numeric(12, 2) not null default 0,
  monto_pagado numeric(12, 2) not null default 0,
  dias_excluidos jsonb not null default '[]'::jsonb,
  notas text,
  precio_personalizado boolean not null default false,
  precio_original numeric(12, 2),
  descuento_aplicado numeric(12, 2),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.reservas_temporales (
  id text primary key,
  payload jsonb not null,
  lugar_id text,
  sede_id text,
  expires_at timestamptz,
  created_at timestamptz default now()
);

-- ========== Promociones ==========
create table if not exists public.promociones (
  id text primary key,
  lugar_id text references public.lugares (id),
  data jsonb not null default '{}'::jsonb,
  activa boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ========== Auditoría y alertas ==========
create table if not exists public.auditoria (
  id uuid primary key default gen_random_uuid(),
  accion text not null,
  entidad text not null,
  entidad_id text not null,
  usuario_id text not null,
  usuario_nombre text,
  usuario_rol text,
  timestamp timestamptz not null default now(),
  lugar_id text references public.lugares (id),
  datos_antiguos jsonb not null default '{}'::jsonb,
  datos_nuevos jsonb not null default '{}'::jsonb,
  metadatos jsonb not null default '{}'::jsonb,
  descripcion text,
  nivel_riesgo text,
  alertas jsonb not null default '[]'::jsonb,
  cambios_detectados jsonb not null default '[]'::jsonb,
  puntuacion_riesgo int not null default 0,
  ip_address text,
  user_agent text,
  dispositivo_info jsonb
);
create index if not exists idx_auditoria_lugar_ts on public.auditoria (lugar_id, timestamp desc);

create table if not exists public.alertas_criticas (
  id uuid primary key default gen_random_uuid(),
  audit_entry_id uuid references public.auditoria (id) on delete set null,
  titulo text not null,
  descripcion text,
  usuario text,
  usuario_id text,
  accion text,
  entidad text,
  entidad_id text,
  timestamp timestamptz not null default now(),
  alertas jsonb,
  puntuacion_riesgo int,
  metadatos jsonb,
  leida boolean not null default false,
  nivel text,
  prioridad int,
  requiere_accion boolean not null default true,
  fecha_expiracion timestamptz
);

-- ========== Tokens FCM (reemplazo colección fcm_tokens) ==========
create table if not exists public.fcm_tokens (
  id text primary key,
  token text not null,
  ciudad_id text,
  lugar_id text,
  platform text,
  staff_pending_push boolean not null default false,
  updated_at timestamptz not null default now(),
  extra jsonb not null default '{}'::jsonb
);
create index if not exists idx_fcm_ciudad on public.fcm_tokens (ciudad_id);
create index if not exists idx_fcm_lugar on public.fcm_tokens (lugar_id);

-- ========== Configuración app / versión / enlaces ==========
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_download_links (
  id text primary key default 'descarga',
  apk_url text,
  active boolean not null default true,
  updated_at timestamptz,
  deactivated_at timestamptz,
  extra jsonb not null default '{}'::jsonb
);

-- ========== Varios ==========
create table if not exists public.peticiones (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.cleanup_logs (
  id uuid primary key default gen_random_uuid(),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.alertas_sistema (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz default now()
);

-- ========== Notas de migración desde Firestore ==========
-- 1) Exporta cada colección e importa filas conservando el mismo `id` (text) en ciudades, lugares, sedes, etc.
-- 2) staff_profiles: una fila por usuario admin/encargado; `id` = UID de Firebase Auth (Authentication → Users).
--    Ejemplo (ajusta IDs reales):
--    insert into staff_profiles (id, email, nombre, rol, lugar_id, activo)
--    values (
--      'UID_FIREBASE',
--      'correo@ejemplo.com',
--      'Nombre',
--      'admin',
--      'ID_LUGAR_EN_TABLA_lugares',
--      true
--    );
-- 3) Menú: menu_categorias / menu_productos usan sede_id = id de la tabla sedes (no híbrido con Firestore).
-- 4) app_config: clave 'version_control', value = JSON con las mismas claves que AppVersion.toRemoteJson().
-- 5) Enlace APK: fila en app_download_links con id 'descarga' (upsert desde la app admin).
