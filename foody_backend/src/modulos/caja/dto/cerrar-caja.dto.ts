import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class CerrarCajaDto {
  @IsUUID()
  caja_id: string;

  @IsNumber()
  @Min(0)
  monto_final_contado: number;

  @IsOptional()
  @IsString()
  observaciones_cierre?: string;
}
