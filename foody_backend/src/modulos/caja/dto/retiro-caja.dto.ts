import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class RetiroCajaDto {
  @IsUUID()
  caja_id: string;

  @IsNumber()
  @Min(0.01)
  monto: number;

  @IsOptional()
  @IsString()
  descripcion?: string;
}
