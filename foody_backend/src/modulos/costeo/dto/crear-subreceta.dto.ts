import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

export class SubrecetaItemDto {
  @IsOptional()
  @IsIn(['ingrediente', 'subreceta'])
  tipo_item?: 'ingrediente' | 'subreceta';

  @ValidateIf((o: SubrecetaItemDto) => (o.tipo_item ?? 'ingrediente') === 'ingrediente')
  @IsUUID()
  ingrediente_id?: string;

  @ValidateIf((o: SubrecetaItemDto) => o.tipo_item === 'subreceta')
  @IsUUID()
  subreceta_id?: string;

  @IsNumber()
  @Min(0.001)
  cantidad: number;

  @IsString()
  unidad: string;
}

export class CrearSubrecetaDto {
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

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => SubrecetaItemDto)
  items: SubrecetaItemDto[];
}
