import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class GuardarConfigFiscalDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nit: string;

  @IsString()
  razon_social: string;

  @IsIn(['simplificado', 'comun'])
  regimen: string;

  @IsOptional()
  @IsBoolean()
  aplica_iva?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  porcentaje_iva?: number;

  @IsOptional()
  @IsString()
  resolucion_dian?: string;

  @IsOptional()
  @IsString()
  prefijo_factura?: string;
}
