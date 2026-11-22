import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateIf,
} from 'class-validator';

export class ActualizarProductoDto {
  @IsOptional()
  @IsUUID()
  categoria_id?: string;

  @IsOptional()
  @IsUUID()
  cocina_id?: string;

  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  precio?: number;

  @IsOptional()
  @IsBoolean()
  disponible?: boolean;

  @IsOptional()
  @Min(0)
  orden?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  margen_objetivo?: number;

  @IsOptional()
  @ValidateIf((_, v) => v != null)
  @IsNumber()
  @Min(0)
  precio_para_llevar?: number | null;

  @IsOptional()
  @IsString()
  imagen_url?: string | null;
}
