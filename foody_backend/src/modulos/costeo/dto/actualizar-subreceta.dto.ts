import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { SubrecetaItemDto } from './crear-subreceta.dto';

export class ActualizarSubrecetaDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nombre: string;

  @IsNumber()
  @Min(0.001)
  cantidad_resultado: number;

  @IsString()
  unidad_resultado: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  margen_error?: number;

  @IsOptional()
  @IsBoolean()
  usa_produccion_lote?: boolean;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SubrecetaItemDto)
  items: SubrecetaItemDto[];
}
