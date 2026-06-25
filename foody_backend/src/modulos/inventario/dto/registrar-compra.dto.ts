import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class CompraItemDto {
  @IsUUID()
  ingrediente_id: string;

  @IsNumber()
  @Min(0.001)
  cantidad_unidades_base: number;

  @IsNumber()
  @Min(0)
  precio_total: number;
}

export class RegistrarCompraDto {
  @IsUUID()
  sucursal_id: string;

  @IsOptional()
  @IsString()
  proveedor?: string;

  @IsOptional()
  @IsString()
  observaciones?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CompraItemDto)
  items: CompraItemDto[];
}
