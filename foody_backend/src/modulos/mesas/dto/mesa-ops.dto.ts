import {
  IsArray,
  IsDateString,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';

export class ReservarMesaDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  @MinLength(1)
  cliente_nombre: string;

  @IsOptional()
  @IsString()
  cliente_telefono?: string;

  @IsDateString()
  reserva_hasta: string;
}

export class UnirMesasDto {
  @IsUUID()
  sucursal_id: string;

  @IsUUID()
  mesa_principal_id: string;

  @IsArray()
  @IsUUID('4', { each: true })
  mesas_secundarias: string[];
}

export class SalioSinPagarDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  @MinLength(1)
  cliente_nombre: string;

  @IsOptional()
  @IsString()
  cliente_telefono?: string;

  @IsString()
  @MinLength(3)
  motivo: string;
}
