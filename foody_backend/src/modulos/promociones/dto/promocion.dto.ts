import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  IsDateString,
  Max,
  Min,
} from 'class-validator';

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
