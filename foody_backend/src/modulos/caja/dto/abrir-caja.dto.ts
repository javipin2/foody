import { IsBoolean, IsNumber, IsOptional, IsUUID, Min } from 'class-validator';

export class AbrirCajaDto {
  @IsUUID()
  sucursal_id: string;

  @IsNumber()
  @Min(0)
  monto_inicial: number;

  @IsOptional()
  @IsBoolean()
  arqueo_ciego?: boolean;
}
