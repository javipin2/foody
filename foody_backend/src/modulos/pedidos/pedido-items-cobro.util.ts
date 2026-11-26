import { ConflictException } from '@nestjs/common';

/** Evita perder la asignación de pagos por línea al cambiar su importe o borrarla. */
export function validarLineaSinCobroAsignado(
  estadoCobro: string | null | undefined,
  tienePagoAsociado: boolean,
): void {
  if (estadoCobro !== 'cobrado' && !tienePagoAsociado) return;
  throw new ConflictException({
    error: 'ITEM_REQUIERE_AJUSTE_COBRO',
    message:
      'Este producto ya tiene un cobro asignado. Ajusta el cobro o registra el reembolso antes de modificar su importe.',
  });
}
