import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

function aBooleanQuery(value: unknown): boolean | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  if (value === true || value === 'true' || value === '1') return true;
  if (value === false || value === 'false' || value === '0') return false;
  return value as boolean;
}

/** GET /pedidos (BN-DTO-24). */
export class ListarPedidosQueryDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @Transform(({ value }) => aBooleanQuery(value))
  @IsBoolean()
  solo_activos?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @IsUUID()
  mesera_id?: string;
}

/** GET /pedidos/cerrados-hoy (BN-DTO-24). */
export class ListarCerradosHoyQueryDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @IsUUID()
  mesera_id?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
