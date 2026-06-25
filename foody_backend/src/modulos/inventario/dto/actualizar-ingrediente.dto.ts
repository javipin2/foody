import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class ActualizarIngredienteDto {
  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsString()
  proveedor?: string;

  @IsOptional()
  @IsIn(['alimento', 'empaque', 'mano_obra', 'servicio'])
  categoria_insumo?: string;

  @IsOptional()
  @IsString()
  unidad_base?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  precio_compra?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  peso_bruto?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  peso_neto?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  stock_minimo?: number;

  /** Modo solo costo (sin recalcular desde mercado). */
  @IsOptional()
  @IsNumber()
  @Min(0)
  costo_unitario_actual?: number;

  @IsOptional()
  @IsBoolean()
  descontar_stock?: boolean;

  /** Ajuste manual: stock final deseado (registra movimiento tipo ajuste). */
  @IsOptional()
  @IsNumber()
  @Min(0)
  stock_nuevo?: number;

  @IsOptional()
  @IsString()
  motivo_ajuste?: string;
}
