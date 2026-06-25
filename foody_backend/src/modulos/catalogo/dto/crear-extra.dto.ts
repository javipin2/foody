import { IsNumber, IsString, IsUUID, Min } from 'class-validator';

export class CrearExtraDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nombre: string;

  @IsNumber()
  @Min(0)
  precio: number;
}
