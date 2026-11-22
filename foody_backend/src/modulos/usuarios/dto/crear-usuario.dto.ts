import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
  ValidateIf,
  ArrayUnique,
} from 'class-validator';

const ROLES_STAFF = [
  'gerente',
  'gerente_cadena',
  'cajero',
  'mesero',
  'domiciliario_planta',
  'cocina',
] as const;

export type RolStaff = (typeof ROLES_STAFF)[number];

export const ROLES_STAFF_ASIGNABLES = ROLES_STAFF;

export class CrearUsuarioDto {
  @IsString()
  @MinLength(2)
  nombre: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  contrasena: string;

  @IsString()
  @IsIn(ROLES_STAFF)
  rol: (typeof ROLES_STAFF)[number];

  @IsString()
  sucursal_id: string;

  /** Obligatorio si rol = cocina. */
  @ValidateIf((o: CrearUsuarioDto) => o.rol === 'cocina')
  @IsUUID()
  cocina_id?: string;

  /** Checklist por usuario (opcional). Si se omite → plantilla del rol. */
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  permisos?: string[];
}

export class CambiarEstadoUsuarioDto {
  @IsBoolean()
  activo: boolean;
}

export class ActualizarUsuarioDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  nombre?: string;

  @IsOptional()
  @IsString()
  @IsIn(ROLES_STAFF)
  rol?: RolStaff;

  @IsOptional()
  @IsString()
  sucursal_id?: string;

  @IsOptional()
  @IsUUID()
  cocina_id?: string | null;

  /** Checklist por usuario. Si se envía, reemplaza overrides de ese usuario. */
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  permisos?: string[];
}
