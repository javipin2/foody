import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class CrearCostoFijoDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  concepto: string;

  @IsNumber()
  @Min(0)
  monto_mensual: number;

  @IsOptional()
  @IsString()
  categoria?: string;

  @IsOptional()
  @IsNumber()
  dia_pago?: number;

  @IsOptional()
  @IsString()
  notas?: string;
}
