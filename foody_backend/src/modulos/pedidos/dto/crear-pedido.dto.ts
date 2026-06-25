import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { PagoLineaDto } from './cobrar-mesa.dto';

class ToppingItemDto {
  @IsUUID()
  topping_id: string;
}

class BebidaItemDto {
  @IsUUID()
  bebida_id: string;

  @IsNumber()
  @Min(1)
  cantidad: number;
}

export class ItemPedidoDto {
  @IsUUID()
  producto_id: string;

  @IsNumber()
  @Min(1)
  cantidad: number;

  @IsNumber()
  @Min(0)
  precio: number;

  @IsOptional()
  @IsString()
  observaciones?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ToppingItemDto)
  toppings?: ToppingItemDto[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => BebidaItemDto)
  bebidas?: BebidaItemDto[];
}

export class ComboPedidoDto {
  @IsUUID()
  combo_id: string;

  @IsNumber()
  @Min(1)
  cantidad: number;

  @IsNumber()
  @Min(0)
  precio: number;
}

export class CrearPedidoDto {
  @IsUUID()
  sucursal_id: string;

  @IsOptional()
  @IsUUID()
  mesa_id?: string;

  @IsString()
  device_id: string;

  @IsIn(['mesa', 'para_llevar', 'domicilio', 'encargo'])
  tipo: string;

  @IsOptional()
  @IsString()
  cliente_nombre?: string;

  @IsOptional()
  @IsString()
  cliente_telefono?: string;

  @IsOptional()
  @IsString()
  direccion_entrega?: string;

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsIn(['efectivo', 'tarjeta', 'transferencia', 'nequi', 'pendiente'])
  metodo_pago?: string;

  @IsOptional()
  requiere_factura?: boolean;

  @IsOptional()
  @IsString()
  nit_cliente?: string;

  @IsOptional()
  @IsString()
  nombre_fiscal_cliente?: string;

  @IsOptional()
  @IsString()
  email_cliente?: string;

  @IsOptional()
  @IsString()
  observaciones?: string;

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
  codigo_promocion?: string;

  @IsOptional()
  @IsString()
  idempotency_key?: string;

  /** CAJ-005: pago mixto al crear (para llevar / mostrador). Suma debe igualar total. */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PagoLineaDto)
  pagos?: PagoLineaDto[];

  @IsOptional()
  @IsNumber()
  @Min(0)
  propina?: number;
}
