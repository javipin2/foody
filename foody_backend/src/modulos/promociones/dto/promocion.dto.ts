import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  IsDateString,
  Max,
  Min,
  MinLength,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';

export class CrearPromocionDto {
  @IsUUID()
  sucursal_id: string;

  @IsOptional()
  @IsString()
  titulo?: string;

  @IsString()
  imagen_url: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsOptional()
  @IsDateString()
  expira_at?: string;

  /** Producto opcional (CTA «Ir al producto» en stories). */
  @IsOptional()
  @IsUUID()
  producto_id?: string;

  /** imagen (default) | video (máx 30 s). */
  @IsOptional()
  @IsIn(['imagen', 'video'])
  tipo_media?: 'imagen' | 'video';

  /** Código que el cliente ingresa en checkout (opcional). */
  @IsOptional()
  @IsString()
  codigo?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  descuento_porcentaje?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  descuento_monto?: number;
}

export class ActualizarPromocionDto {
  @IsOptional()
  @IsString()
  titulo?: string;

  @IsOptional()
  @IsString()
  imagen_url?: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsOptional()
  @IsDateString()
  expira_at?: string;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;

  @IsOptional()
  @IsUUID()
  producto_id?: string | null;

  @IsOptional()
  @IsString()
  codigo?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  descuento_porcentaje?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  descuento_monto?: number;
}

export class RegistrarVistaPromocionDto {
  @IsString()
  device_id: string;
}

/** GET /promociones/validar-codigo (BN-DTO-20). */
export class ValidarCodigoPromocionDto {
  @IsUUID()
  sucursal_id!: string;

  @IsString()
  @MinLength(1)
  codigo!: string;

  @IsOptional()
  @Transform(({ value }) =>
    value === undefined || value === null || value === '' ? 0 : Number(value),
  )
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  subtotal: number = 0;
}
