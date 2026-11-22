import { IsIn, IsOptional, IsUUID } from 'class-validator';

const TIPOS_IMAGEN = [
  'producto',
  'categoria',
  'combo',
  'promocion',
  'general',
] as const;

/** POST /almacenamiento/imagen query (BN-DTO-26). */
export class SubirImagenQueryDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @IsIn(TIPOS_IMAGEN)
  tipo?: (typeof TIPOS_IMAGEN)[number];

  @IsOptional()
  @IsUUID()
  entidad_id?: string;
}

/** POST /almacenamiento/video query. */
export class SubirVideoQueryDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @IsIn(TIPOS_IMAGEN)
  tipo?: (typeof TIPOS_IMAGEN)[number];
}
