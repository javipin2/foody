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
  ValidateNested,
} from 'class-validator';

export class ComboItemDto {
  @IsIn(['producto', 'bebida', 'topping'])
  tipo_item: string;

  @IsUUID()
  item_id: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  cantidad?: number;
}

export class CrearComboDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nombre: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsNumber()
  @Min(0)
  precio_fijo: number;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ComboItemDto)
  items: ComboItemDto[];
}
