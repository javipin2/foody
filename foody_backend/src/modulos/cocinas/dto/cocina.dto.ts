import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';

export class CrearCocinaDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  @MinLength(1)
  nombre: string;
}

export class ActualizarCocinaDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  nombre?: string;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;
}

export class CrearImpresoraDto {
  @IsUUID()
  sucursal_id: string;

  @IsUUID()
  cocina_id: string;

  @IsString()
  @MinLength(1)
  nombre: string;

  @IsOptional()
  @IsString()
  ip_local?: string;

  @IsOptional()
  @IsIn(['termica_red', 'termica_usb', 'pdf'])
  tipo?: string;
}

export class ActualizarImpresoraDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  nombre?: string;

  @IsOptional()
  @IsUUID()
  cocina_id?: string;

  @IsOptional()
  @IsString()
  ip_local?: string;

  @IsOptional()
  @IsIn(['termica_red', 'termica_usb', 'pdf'])
  tipo?: string;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;
}

export class CambiarEstadoItemDto {
  @IsIn(['pendiente', 'preparando', 'listo', 'no_disponible'])
  estado_cocina: 'pendiente' | 'preparando' | 'listo' | 'no_disponible';

  @IsOptional()
  @IsString()
  motivo?: string;
}

/** VIE-09 C: fallo de preparación (motivo obligatorio). */
export class FalloPreparacionDto {
  @IsString()
  motivo: string;
}
