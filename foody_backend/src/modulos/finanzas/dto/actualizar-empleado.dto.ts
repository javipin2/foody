import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class ActualizarEmpleadoDto {
  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsString()
  cargo?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  sueldo_base?: number;

  @IsOptional()
  @IsIn(['diario', 'semanal', 'quincenal', 'mensual'])
  frecuencia_pago?: string;

  @IsOptional()
  @IsUUID()
  usuario_id?: string;

  @IsOptional()
  @IsBoolean()
  activo?: boolean;
}
