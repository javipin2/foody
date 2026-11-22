import { IsOptional, IsUUID } from 'class-validator';

export class AprobarPedidoMesaDto {
  /** Mesero responsable. Obligatorio si quien aprueba no es mesero. */
  @IsOptional()
  @IsUUID()
  mesera_id?: string;
}
