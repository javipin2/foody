import { IsBoolean, IsOptional, IsString, IsUUID, MinLength, ValidateIf } from 'class-validator';

export class CrearMesaDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  @MinLength(1)
  nombre: string;

  @IsOptional()
  @IsString()
  qr_token?: string;
}

export class ActualizarMesaDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  nombre?: string;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;

  /** Asignar o quitar mesera del turno (null = sin asignar). */
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsUUID()
  mesera_asignada_id?: string | null;
}
