import { IsOptional, IsUUID } from 'class-validator';
import { PaginacionQueryDto } from '../../../compartido/dto/paginacion.dto';

export class CajaMovimientosPedidoQueryDto extends PaginacionQueryDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;
}
