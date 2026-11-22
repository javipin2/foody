-- Foody — bucket público para imágenes (Supabase Storage self-hosted)
-- Aplicar en supabase-db: ver docs/ENTORNO_LOCAL.md

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'foody-assets',
  'foody-assets',
  true,
  5242880,
  ARRAY['image/webp', 'image/jpeg', 'image/png', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Lectura pública (menú cliente)
DROP POLICY IF EXISTS foody_assets_public_read ON storage.objects;
CREATE POLICY foody_assets_public_read ON storage.objects
  FOR SELECT
  USING (bucket_id = 'foody-assets');

-- Subida solo vía service role (NestJS con SUPABASE_SERVICE_KEY)
DROP POLICY IF EXISTS foody_assets_service_insert ON storage.objects;
CREATE POLICY foody_assets_service_insert ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'foody-assets');

DROP POLICY IF EXISTS foody_assets_service_update ON storage.objects;
CREATE POLICY foody_assets_service_update ON storage.objects
  FOR UPDATE
  USING (bucket_id = 'foody-assets');

DROP POLICY IF EXISTS foody_assets_service_delete ON storage.objects;
CREATE POLICY foody_assets_service_delete ON storage.objects
  FOR DELETE
  USING (bucket_id = 'foody-assets');
