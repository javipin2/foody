import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class RegistrarProduccionDto {
  @IsUUID()
  sucursal_id: string;

  @IsUUID()
  receta_id: string;

  @IsNumber()
  @Min(0.001)
  cantidad_producida: number;

  @IsOptional()
  @IsString()
  observaciones?: string;
}
