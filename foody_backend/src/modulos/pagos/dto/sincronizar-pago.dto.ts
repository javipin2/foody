import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class SincronizarPagoDto {
  @IsOptional()
  @IsUUID()
  pago_id?: string;

  /** ID Wompi del comprobante (ej. 1969957-1782290934-46563). Opcional si el enlace aún está pendiente. */
  @IsOptional()
  @IsString()
  @MaxLength(80)
  transaccion_wompi_id?: string;
}
