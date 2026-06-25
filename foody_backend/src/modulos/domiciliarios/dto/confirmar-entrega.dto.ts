import { IsIn, IsOptional, IsString } from 'class-validator';

export class ConfirmarEntregaDto {
  @IsOptional()
  @IsString()
  @IsIn(['efectivo', 'tarjeta', 'transferencia', 'nequi', 'pendiente'])
  metodo_pago?: string;
}
