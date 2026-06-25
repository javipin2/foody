import { IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CrearSucursalDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  direccion?: string;

  @IsOptional()
  @IsUUID()
  ciudad_id?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  telefono?: string;
}
