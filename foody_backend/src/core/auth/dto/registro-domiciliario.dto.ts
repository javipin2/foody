import { IsEmail, IsOptional, IsString, IsUUID, MinLength } from 'class-validator';

export class RegistroDomiciliarioDto {
  @IsString()
  @MinLength(2)
  nombre: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  contrasena: string;

  @IsOptional()
  @IsString()
  telefono?: string;

  @IsOptional()
  @IsString()
  tipo_vehiculo?: string;

  @IsOptional()
  @IsString()
  placa?: string;

  @IsOptional()
  @IsUUID()
  ciudad_id?: string;
}
