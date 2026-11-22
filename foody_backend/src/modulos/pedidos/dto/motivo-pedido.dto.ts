import { IsOptional, IsString, MinLength } from 'class-validator';

/** DELETE /pedidos/:id/items/:itemId — motivo opcional (merma). */
export class EliminarItemPedidoDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  motivo?: string;
}

/** PATCH /pedidos/:id/rechazar */
export class RechazarPedidoMesaDto {
  @IsString()
  @MinLength(3)
  motivo!: string;
}
