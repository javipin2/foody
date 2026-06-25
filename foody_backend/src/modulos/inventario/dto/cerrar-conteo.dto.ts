import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsNumber,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class ConteoItemDto {
  @IsUUID()
  ingrediente_id: string;

  @IsNumber()
  @Min(0)
  cantidad_real: number;
}

export class CerrarConteoDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ConteoItemDto)
  items: ConteoItemDto[];
}
