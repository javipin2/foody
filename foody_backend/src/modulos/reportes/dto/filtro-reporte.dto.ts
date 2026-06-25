import { IsDateString, IsOptional, IsUUID } from 'class-validator';

export class FiltroReporteDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @IsDateString()
  desde?: string;

  @IsOptional()
  @IsDateString()
  hasta?: string;
}
