import { IsOptional, IsUUID } from 'class-validator';
import { PaginacionQueryDto } from '../../../compartido/dto/paginacion.dto';

/** GET /usuarios — scope + paginación opt-in (API-PAGE-03). */
export class ListarUsuariosQueryDto extends PaginacionQueryDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;
}
