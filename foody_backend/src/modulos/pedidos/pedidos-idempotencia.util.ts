import { createHash } from 'node:crypto';
import { BadRequestException, ConflictException } from '@nestjs/common';

export function validarTotalEsperadoPedido(
  esperado: number | undefined,
  actual: number,
  contexto: {
    subtotal: number;
    costoDomicilio: number;
    descuento: number;
  },
): void {
  if (esperado === undefined) {
    throw new BadRequestException({
      error: 'TOTAL_ESPERADO_REQUERIDO',
      message:
        'Actualiza la pantalla de caja para confirmar el precio antes de cobrar',
    });
  }
  // Comparar centavos enteros evita que 12000.01 - 12000 resulte
  // 0.0100000002 por representación binaria y dispare un falso conflicto.
  if (Math.abs(Math.round((esperado - actual) * 100)) <= 1) return;
  throw new ConflictException({
    error: 'TOTAL_PEDIDO_CAMBIO',
    message: 'El total cambió desde la última cotización',
    total_esperado: esperado,
    total_actual: actual,
    subtotal: contexto.subtotal,
    costo_domicilio: contexto.costoDomicilio,
    descuento: contexto.descuento,
  });
}

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
  // La cotización es una precondición de cobro, no contenido del pedido. Si
  // una respuesta se pierde tras crear, un reintento debe recuperar el mismo
  // pedido incluso si la cotización ya cambió.
  const { idempotency_key: _clave, total_esperado: _total, ...payload } = dto;
  return createHash('sha256')
    .update(JSON.stringify(ordenarJson(payload)))
    .digest('hex');
}
