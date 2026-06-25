import {
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class AplicarDescuentoDto {
  /** Monto fijo en COP (mutuamente excluyente con porcentaje). */
  @ValidateIf((o) => o.porcentaje == null)
  @IsNumber()
  @Min(0)
  monto?: number;

  /** Porcentaje sobre el subtotal + domicilio (0–100). */
  @ValidateIf((o) => o.monto == null)
  @IsNumber()
  @Min(0)
  @Max(100)
  porcentaje?: number;

  @IsString()
  @MinLength(3)
  motivo: string;
}
