import { IsIn, IsOptional, IsString } from 'class-validator';

const ESTADOS_VALIDOS = [
  'pendiente',
  'pendiente_aprobacion',
  'confirmado',
  'en_cocina',
  'listo',
  'pagando',
  'asignado',
  'en_camino',
  'entregado',
  'cancelado',
  'rechazado',
] as const;

export class CambiarEstadoPedidoDto {
  @IsString()
  @IsIn(ESTADOS_VALIDOS)
  estado: (typeof ESTADOS_VALIDOS)[number];

  @IsOptional()
  @IsString()
  motivo?: string;
}
