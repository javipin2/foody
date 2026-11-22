import { IsDateString, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class PagarCostoFijoDto {
  @IsOptional()
  @IsNumber()
  @Min(0.01)
  monto?: number;

  @IsOptional()
  @IsDateString()
  fecha?: string;

  @IsOptional()
  @IsDateString()
  periodo_desde?: string;

  @IsOptional()
  @IsDateString()
  periodo_hasta?: string;

  @IsOptional()
  @IsString()
  concepto?: string;
}
