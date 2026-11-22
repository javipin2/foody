import { IsIn, IsOptional, IsString } from 'class-validator';

const PRESETS = [
  'hoy',
  'ayer',
  'semana',
  'mes',
  'mes_anterior',
  '7d',
  '30d',
  'rango',
] as const;

export class FiltroPopularidadQueryDto {
  @IsOptional()
  @IsIn(PRESETS)
  preset?: (typeof PRESETS)[number];

  @IsOptional()
  @IsString()
  desde?: string;

  @IsOptional()
  @IsString()
  hasta?: string;
}
