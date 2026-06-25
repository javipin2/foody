-- Foody — self-service: plan gratis, OAuth en usuarios, origen restaurante

-- Plan «gratis» en suscripciones
ALTER TABLE suscripciones_restaurante
  DROP CONSTRAINT IF EXISTS suscripciones_restaurante_plan_check;

ALTER TABLE suscripciones_restaurante
  ADD CONSTRAINT suscripciones_restaurante_plan_check
  CHECK (plan IN ('gratis', 'basico', 'pro', 'enterprise'));

-- Origen del alta (manual super-admin vs self-service)
ALTER TABLE restaurantes
  ADD COLUMN IF NOT EXISTS origen text NOT NULL DEFAULT 'manual'
  CHECK (origen IN ('manual', 'self_service'));

-- Identidad OAuth (Google vía Supabase Auth)
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS proveedor_auth text NOT NULL DEFAULT 'correo'
  CHECK (proveedor_auth IN ('correo', 'google'));

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS proveedor_id text;

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS email_verificado boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS usuarios_proveedor_id_uq
  ON usuarios (proveedor_auth, proveedor_id)
  WHERE proveedor_id IS NOT NULL;
