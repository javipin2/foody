import { IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class CrearCategoriaDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nombre: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  orden?: number;
}
