import { IsOptional, IsUUID } from 'class-validator';

/** GET /pagos/retorno-app (BN-DTO-27). Público — solo redirige. */
export class RetornoAppQueryDto {
  @IsOptional()
  @IsUUID()
  pago_id?: string;
}
