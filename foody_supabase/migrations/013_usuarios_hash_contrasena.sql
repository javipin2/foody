-- Foody — contraseña staff (hash bcrypt, nunca texto plano)
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS hash_contrasena text;
