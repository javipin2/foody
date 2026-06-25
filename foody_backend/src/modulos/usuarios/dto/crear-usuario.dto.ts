import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsString,
  MinLength,
} from 'class-validator';

const ROLES_STAFF = [
  'gerente',
  'cajero',
  'mesero',
  'domiciliario_planta',
] as const;

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
}

export class CambiarEstadoUsuarioDto {
  @IsBoolean()
  activo: boolean;
}
