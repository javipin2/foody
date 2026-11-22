import { IsIn, IsNumber, IsOptional, IsString, IsUUID } from 'class-validator';

export class IniciarSesionDto {
  @IsNumber()
  lat: number;

  @IsNumber()
  lng: number;

  @IsOptional()
  @IsUUID()
  ciudad_id?: string;
}

export class UbicacionDto {
  @IsNumber()
  lat: number;

  @IsNumber()
  lng: number;
}

/** Ubicación durante entrega activa (planta o independiente). */
export class UbicacionEntregaDto extends UbicacionDto {
  @IsOptional()
  @IsUUID()
  pedido_id?: string;
}

export class ResponderOfertaDto {
  @IsIn(['aceptada', 'rechazada'])
  respuesta: 'aceptada' | 'rechazada';
}
