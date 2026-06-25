import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateIf,
} from 'class-validator';

export class CrearIngredienteDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nombre: string;

  @IsString()
  unidad_base: string;

  @IsOptional()
  @IsIn(['peso', 'pieza', 'rendimiento', 'produccion'])
  tipo_costeo?: string;

  @IsOptional()
  @IsString()
  proveedor?: string;

  @IsOptional()
  @IsIn(['alimento', 'empaque', 'mano_obra', 'servicio'])
  categoria_insumo?: string;

  /** Modo mercado: precio pagado por la presentación. */
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

  @IsOptional()
  @IsNumber()
  @Min(0)
  stock_actual?: number;

  /** Modo solo costo (sin mercado). Ignorado si vienen precio_compra + peso_neto. */
  @IsOptional()
  @IsNumber()
  @Min(0)
  costo_unitario_actual?: number;

  /** false = solo costeo (mano de obra, gas fijo); no descuenta stock al vender. */
  @IsOptional()
  @IsBoolean()
  descontar_stock?: boolean;
}
