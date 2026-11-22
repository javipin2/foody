import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CrearGastoManualDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  concepto: string;

  @IsNumber()
  @Min(0.01)
  monto: number;

  @IsOptional()
  @IsString()
  categoria?: string;

  @IsOptional()
  @IsDateString()
  fecha?: string;

  @IsOptional()
  @IsString()
  comprobante_url?: string;
}
