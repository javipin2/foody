import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class TransferirMesaDto {
  @IsUUID()
  sucursal_id: string;

  @IsUUID()
  pedido_id: string;

  @IsUUID()
  mesa_origen_id: string;

  @IsUUID()
  mesa_destino_id: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  motivo?: string;
}
