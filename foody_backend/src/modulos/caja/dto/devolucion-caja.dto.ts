import { IsNumber, IsOptional, IsString, IsUUID, Min, MinLength } from 'class-validator';

export class DevolucionCajaDto {
  @IsUUID()
  caja_id: string;

  @IsUUID()
  sucursal_id: string;

  @IsNumber()
  @Min(0.01)
  monto: number;

  @IsString()
  @MinLength(3)
  motivo: string;

  @IsOptional()
  @IsUUID()
  pedido_id?: string;

  @IsOptional()
  @IsString()
  metodo_pago?: string;
}
