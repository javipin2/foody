import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class CrearTrasladoDto {
  @IsUUID()
  sucursal_origen_id: string;

  @IsUUID()
  sucursal_destino_id: string;

  @IsUUID()
  ingrediente_id: string;

  @IsNumber()
  @Min(0.0001)
  cantidad: number;

  @IsOptional()
  @IsString()
  motivo?: string;
}
