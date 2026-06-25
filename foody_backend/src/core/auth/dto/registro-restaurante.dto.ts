import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RegistroRestauranteDto {
  @IsUUID()
  ciudad_id: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre_restaurante: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre_sucursal?: string;

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

  @IsOptional()
  @IsString()
  @MinLength(6)
  contrasena?: string;

  @IsOptional()
  @IsIn(['correo', 'google'])
  proveedor_auth?: 'correo' | 'google';

  @IsOptional()
  @IsString()
  supabase_access_token?: string;
}
