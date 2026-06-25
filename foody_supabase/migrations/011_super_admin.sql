-- Foody — suscripciones y configuración global
CREATE TABLE suscripciones_restaurante (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurante_id uuid REFERENCES restaurantes(id) UNIQUE,
  estado text NOT NULL DEFAULT 'prueba'
    CHECK (estado IN ('prueba', 'activa', 'vencida', 'bloqueada')),
  plan text NOT NULL DEFAULT 'basico'
    CHECK (plan IN ('basico', 'pro', 'enterprise')),
  fecha_inicio timestamptz NOT NULL DEFAULT now(),
  fecha_vencimiento timestamptz NOT NULL,
  bloqueado_por uuid REFERENCES usuarios(id),
  motivo_bloqueo text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE configuracion_global_foody (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clave text UNIQUE NOT NULL,
  valor text NOT NULL,
  descripcion text,
  editado_por uuid REFERENCES usuarios(id),
  updated_at timestamptz DEFAULT now()
);

INSERT INTO configuracion_global_foody (clave, valor, descripcion) VALUES
  ('comision_domiciliario_porcentaje', '15', '% que cobra Foody por entrega independiente'),
  ('tiempo_expiracion_oferta_seg', '60', 'Segundos antes de que expire una oferta de domicilio'),
  ('radio_inicial_busqueda_km', '3', 'Radio inicial para buscar domiciliarios'),
  ('ampliacion_radio_km', '2', 'Cuanto amplia el radio por intento fallido'),
  ('intentos_max_busqueda', '3', 'Intentos antes de alertar al restaurante'),
  ('umbral_alerta_descuento_pct', '30', '% de descuento que dispara alerta de riesgo'),
  ('umbral_alerta_cuadre_caja', '5000', 'Diferencia COP que dispara alerta de caja'),
  ('umbral_alerta_costo_sube_pct', '15', '% de subida de costo que dispara alerta'),
  ('umbral_alerta_margen_bajo_pct', '20', '% de margen minimo antes de alertar'),
  ('dias_datos_restaurante_bloqueado', '30', 'Dias que se guardan datos tras bloqueo'),
  ('tiempo_aprobacion_mesera_min', '3', 'Minutos para que mesera apruebe pedido QR'),
  ('umbral_reloj_pedido_rojo_min', '15', 'Minutos en estado antes de poner reloj en rojo');
