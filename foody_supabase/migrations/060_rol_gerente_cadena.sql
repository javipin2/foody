-- P1-02: rol corporativo gerente_cadena (mismos permisos que admin de restaurante).
INSERT INTO roles_permisos (rol, permiso)
SELECT 'gerente_cadena', permiso
FROM roles_permisos
WHERE rol = 'admin'
ON CONFLICT (rol, permiso) DO NOTHING;
