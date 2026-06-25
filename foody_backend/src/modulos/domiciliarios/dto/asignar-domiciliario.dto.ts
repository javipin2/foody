import { IsUUID } from 'class-validator';

export class AsignarDomiciliarioDto {
  @IsUUID()
  pedido_id: string;

  @IsUUID()
  sucursal_id: string;

  @IsUUID()
  domiciliario_planta_id: string;
}
