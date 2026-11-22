import { IsNumber, IsOptional, Min } from 'class-validator';

export class ActualizarMargenesSucursalDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  margen_objetivo_default?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  umbral_alerta_margen?: number;
}

