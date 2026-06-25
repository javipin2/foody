import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsNumber,
  IsOptional,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class ItemIncluidoDto {
  @IsUUID()
  producto_incluido_id: string;

  @IsNumber()
  @Min(0.001)
  cantidad: number;
}

export class ConfigurarItemsIncluidosDto {
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ItemIncluidoDto)
  items: ItemIncluidoDto[] = [];
}
