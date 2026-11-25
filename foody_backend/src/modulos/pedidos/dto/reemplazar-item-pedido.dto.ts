import { Type } from 'class-transformer';
import {
  IsArray,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { ComboPedidoDto, ItemPedidoDto } from './crear-pedido.dto';

export class ReemplazarItemPedidoDto {
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  idempotency_key!: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ItemPedidoDto)
  items?: ItemPedidoDto[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComboPedidoDto)
  combos?: ComboPedidoDto[];

  @IsOptional()
  @IsString()
  @MaxLength(300)
  motivo?: string;
}
