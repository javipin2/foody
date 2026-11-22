-- Estados: tipo imagen|video; Storage admite video corto.
ALTER TABLE estados_promociones
  ADD COLUMN IF NOT EXISTS tipo_media TEXT NOT NULL DEFAULT 'imagen'
    CHECK (tipo_media IN ('imagen', 'video'));

COMMENT ON COLUMN estados_promociones.tipo_media IS
  'imagen = foto; video = clip (máx 30s, validado en cliente/API). URL en imagen_url.';

UPDATE storage.buckets
SET
  file_size_limit = 20971520, -- 20 MB (videos cortos)
  allowed_mime_types = ARRAY[
    'image/webp', 'image/jpeg', 'image/png', 'image/gif',
    'video/mp4', 'video/webm', 'video/quicktime'
  ]
WHERE id = 'foody-assets';
