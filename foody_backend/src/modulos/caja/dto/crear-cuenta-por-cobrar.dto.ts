import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class CrearCuentaPorCobrarDto {
  @IsUUID()
  sucursal_id: string;

  @IsOptional()
  @IsUUID()
  pedido_id?: string;

  @IsString()
  cliente_nombre: string;

  @IsOptional()
  @IsString()
  cliente_telefono?: string;

  @IsNumber()
  @Min(0.01)
  monto: number;
}
