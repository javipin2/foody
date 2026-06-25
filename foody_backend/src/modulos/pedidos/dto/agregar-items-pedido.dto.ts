import { Type } from 'class-transformer';
import {
  IsArray,
  IsOptional,
  ValidateNested,
} from 'class-validator';
import { ComboPedidoDto, ItemPedidoDto } from './crear-pedido.dto';

export class AgregarItemsPedidoDto {
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
}
