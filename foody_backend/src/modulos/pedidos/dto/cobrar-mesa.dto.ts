import { IsArray, IsIn, IsNumber, IsOptional, IsString, IsUUID, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class PagoLineaDto {
  @IsIn(['efectivo', 'tarjeta', 'transferencia', 'nequi'])
  metodo_pago: string;

  @IsNumber()
  @Min(0.01)
  monto: number;
}

export class CobrarMesaDto {
  /** Un solo método (legacy) — cobra el saldo indicado o el total pendiente. */
  @IsOptional()
  @IsIn(['efectivo', 'tarjeta', 'transferencia', 'nequi', 'pendiente'])
  metodo_pago?: string;

  @IsOptional()
  @IsString()
  motivo?: string;

  /** Pago mixto: varias líneas que deben sumar el monto a cobrar. */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PagoLineaDto)
  pagos?: PagoLineaDto[];

  /** Split bill: solo estos ítems (precio línea = cantidad × precio_unitario). */
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  item_ids?: string[];

  /** Abono parcial sobre el total mesa (sin split por ítem). */
  @IsOptional()
  @IsNumber()
  @Min(0.01)
  monto_parcial?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  propina?: number;

  /** API-IDEM-02: reintento seguro tras timeout / doble tap. */
  @IsOptional()
  @IsString()
  idempotency_key?: string;
}
