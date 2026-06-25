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

export class RecetaItemDto {
  @IsIn(['ingrediente', 'subreceta', 'empaque'])
  tipo_item: 'ingrediente' | 'subreceta' | 'empaque';

  @ValidateIf(
    (o: RecetaItemDto) =>
      o.tipo_item === 'ingrediente' || o.tipo_item === 'empaque',
  )
  @IsUUID()
  ingrediente_id?: string;

  @ValidateIf((o: RecetaItemDto) => o.tipo_item === 'subreceta')
  @IsUUID()
  subreceta_id?: string;

  @IsNumber()
  @Min(0.001)
  cantidad: number;

  @IsString()
  unidad: string;
}

export class ConfigurarRecetaProductoDto {
  @IsUUID()
  producto_id: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => RecetaItemDto)
  items: RecetaItemDto[];

  @IsOptional()
  @IsNumber()
  @Min(0)
  margen_error?: number;
}
