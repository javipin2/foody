import { IsString, MinLength } from 'class-validator';

export class CancelarPedidoClienteDto {
  @IsString()
  @MinLength(1)
  device_id: string;

  @IsString()
  @MinLength(3)
  motivo: string;
}
