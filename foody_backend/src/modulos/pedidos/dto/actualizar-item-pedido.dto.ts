import { Type } from 'class-transformer';
import {
  ArrayUnique,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

class ToppingPatchDto {
  @IsUUID()
  topping_id!: string;
}

export class ActualizarItemPedidoDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  cantidad?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string | null;

  /** Reemplaza el set completo de toppings (vacío = sin toppings). */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ToppingPatchDto)
  @ArrayUnique((t: ToppingPatchDto) => t.topping_id)
  toppings?: ToppingPatchDto[];
}
