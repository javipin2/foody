import { IsUUID } from 'class-validator';

export class CotizarReemplazoComboDto {
  @IsUUID()
  reemplazo_id!: string;
}
