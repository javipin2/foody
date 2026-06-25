import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CrearCiudadDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  slug?: string;
}

export class ActualizarCiudadDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre?: string;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;
}

export class ActualizarRestauranteDto {
  @IsOptional()
  @IsBoolean()
  activo?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  motivo_bloqueo?: string;
}

export class ActualizarSuscripcionDto {
  @IsOptional()
  @IsIn(['prueba', 'activa', 'vencida', 'bloqueada'])
  estado?: string;

  @IsOptional()
  @IsIn(['gratis', 'basico', 'pro', 'enterprise'])
  plan?: string;

  /** ISO 8601, ej. 2026-12-31T23:59:59.000Z */
  @IsOptional()
  @IsString()
  fecha_vencimiento?: string;
}

export class ActualizarDomiciliarioEstadoDto {
  @IsIn(['pendiente_verificacion', 'activo', 'suspendido', 'bloqueado'])
  estado_cuenta: string;

  @IsOptional()
  @IsString()
  motivo?: string;
}

const ROLES_STAFF_SUPER = [
  'admin',
  'gerente',
  'cajero',
  'mesero',
  'domiciliario_planta',
  'cocina_principal',
] as const;

export class CrearRestauranteDto {
  @IsUUID()
  ciudad_id: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre_restaurante: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre_sucursal: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  direccion_sucursal?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  admin_nombre: string;

  @IsEmail()
  admin_email: string;

  @IsString()
  @MinLength(6)
  admin_contrasena: string;
}

export class CrearUsuarioSuperDto {
  @IsString()
  @MinLength(2)
  nombre: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  contrasena: string;

  @IsString()
  @IsIn(ROLES_STAFF_SUPER)
  rol: (typeof ROLES_STAFF_SUPER)[number];

  @IsUUID()
  sucursal_id: string;
}

export class ActualizarUsuarioSuperDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  nombre?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @IsIn(ROLES_STAFF_SUPER)
  rol?: (typeof ROLES_STAFF_SUPER)[number];
}

export class CambiarContrasenaSuperDto {
  @IsString()
  @MinLength(6)
  contrasena: string;
}

export class CambiarEstadoUsuarioSuperDto {
  @IsBoolean()
  activo: boolean;
}

export class ActualizarConfiguracionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  valor: string;
}

export class AprobarDocumentoDto {
  @IsUUID()
  documento_id: string;
}

export class RechazarDocumentoDto {
  @IsUUID()
  documento_id: string;

  @IsString()
  @MinLength(3)
  motivo: string;
}
