import { IsBoolean, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class ActualizarCostoFijoDto {
  @IsOptional()
  @IsString()
  concepto?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  monto_mensual?: number;

  @IsOptional()
  @IsString()
  categoria?: string;

  @IsOptional()
  @IsNumber()
  dia_pago?: number;

  @IsOptional()
  @IsString()
  notas?: string;

  @IsOptional()
  @IsBoolean()
  activo?: boolean;
}
