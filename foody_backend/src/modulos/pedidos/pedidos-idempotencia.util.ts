import { createHash } from 'node:crypto';

function ordenarJson(valor: unknown): unknown {
  if (Array.isArray(valor)) return valor.map(ordenarJson);
  if (valor !== null && typeof valor === 'object') {
    return Object.fromEntries(
      Object.entries(valor as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([clave, dato]) => [clave, ordenarJson(dato)]),
    );
  }
  return valor;
}

/** Firma el contenido funcional del alta sin incluir su propia clave idempotente. */
export function huellaIdempotenciaPedido(dto: Record<string, unknown>): string {
  const { idempotency_key: _clave, ...payload } = dto;
  return createHash('sha256')
    .update(JSON.stringify(ordenarJson(payload)))
    .digest('hex');
}
