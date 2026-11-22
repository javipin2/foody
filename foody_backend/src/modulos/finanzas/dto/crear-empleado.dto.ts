import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CrearEmpleadoDto {
  @IsUUID()
  sucursal_id: string;

  @IsString()
  nombre: string;

  @IsOptional()
  @IsString()
  cargo?: string;

  @IsNumber()
  @Min(0)
  sueldo_base: number;

  @IsOptional()
  @IsIn(['diario', 'semanal', 'quincenal', 'mensual'])
  frecuencia_pago?: string;

  @IsOptional()
  @IsUUID()
  usuario_id?: string;
}
