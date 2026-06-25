-- Cajero puede crear pedidos y cobrar, pero no recibe turno de mesa (solo meseros).
-- Limpia asignaciones erróneas donde un cajero quedó como mesera_asignada.

UPDATE mesas m
SET mesera_asignada_id = NULL,
    mesera_asignada_at = NULL
FROM usuarios u
WHERE m.mesera_asignada_id = u.id
  AND u.rol = 'cajero';

UPDATE pedidos p
SET mesera_id = NULL
FROM usuarios u
WHERE p.mesera_id = u.id
  AND u.rol = 'cajero'
  AND p.estado NOT IN ('pagado', 'cancelado', 'rechazado');
