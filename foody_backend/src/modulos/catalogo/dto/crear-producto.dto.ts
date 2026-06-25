import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CrearProductoDto {
  @IsUUID()
  sucursal_id: string;

  @IsUUID()
  categoria_id: string;

  @IsOptional()
  @IsUUID()
  cocina_id?: string;

  @IsString()
  nombre: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsNumber()
  @Min(0)
  precio: number;

  @IsOptional()
  @IsBoolean()
  disponible?: boolean;

  @IsOptional()
  @Min(0)
  orden?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  precio_para_llevar?: number;
}
