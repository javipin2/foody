import { IsOptional, IsString, MinLength } from 'class-validator';

export class RegistrarFcmDto {
  @IsString()
  @MinLength(8)
  fcm_token: string;

  @IsOptional()
  @IsString()
  plataforma?: string;
}

export class DesactivarFcmDto {
  @IsOptional()
  @IsString()
  fcm_token?: string;
}
