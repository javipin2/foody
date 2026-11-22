import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

/** GET /costeo/productos/:id/impacto-stock (BN-DTO-25). */
export class ImpactoStockQueryDto {
  @IsUUID()
  sucursal_id!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(9999)
  cantidad?: number;

  @IsOptional()
  @IsIn(['producto', 'bebida', 'topping'])
  tipo_entidad?: 'producto' | 'bebida' | 'topping';
}
