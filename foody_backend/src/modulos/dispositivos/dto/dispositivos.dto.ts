import { IsOptional, IsString, IsUUID, MinLength } from 'class-validator';

export class RegistrarDispositivoDto {
  @IsString()
  @MinLength(8)
  device_id!: string;

  @IsOptional()
  @IsString()
  fcm_token?: string;

  @IsOptional()
  @IsUUID()
  ciudad_id?: string;

  @IsOptional()
  @IsString()
  plataforma?: string;
}

export class VincularAuthDispositivoDto {
  @IsString()
  @MinLength(8)
  device_id!: string;

  @IsString()
  @MinLength(10)
  access_token!: string;
}

export class AnonimizarDispositivoDto {
  @IsOptional()
  @IsString()
  fcm_token?: string;

  @IsOptional()
  @IsString()
  access_token?: string;
}
