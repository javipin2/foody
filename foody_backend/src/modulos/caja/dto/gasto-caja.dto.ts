import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class GastoCajaDto {
  @IsUUID()
  caja_id: string;

  @IsString()
  concepto: string;

  @IsNumber()
  @Min(0.01)
  monto: number;

  @IsOptional()
  @IsString()
  categoria?: string;
}
