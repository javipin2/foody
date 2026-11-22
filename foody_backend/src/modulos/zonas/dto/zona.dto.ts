import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CrearZonaDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  @MinLength(1)
  nombre: string;

  @IsNumber()
  @Min(0)
  costo_domicilio: number;

  @IsNumber()
  @Min(0.1)
  distancia_max_km: number;
}

export class ActualizarZonaDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  nombre?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  costo_domicilio?: number;

  @IsOptional()
  @IsNumber()
  @Min(0.1)
  distancia_max_km?: number;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;
}

export class UbicacionSucursalDto {
  @IsNumber()
  lat: number;

  @IsNumber()
  lng: number;
}

export class CotizarDomicilioDto {
  @IsUUID()
  sucursal_id!: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lng?: number;
}
