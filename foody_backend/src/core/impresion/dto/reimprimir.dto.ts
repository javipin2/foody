import { IsOptional, IsUUID } from 'class-validator';

export class ReimprimirComandaDto {
  @IsUUID()
  pedido_id!: string;

  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @IsUUID()
  cocina_id?: string;
}
