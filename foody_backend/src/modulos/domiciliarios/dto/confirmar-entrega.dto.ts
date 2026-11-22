import { IsIn, IsOptional, IsString } from 'class-validator';

const METODOS_ENTREGA = [
  'efectivo',
  'tarjeta',
  'transferencia',
  'nequi',
  'pendiente',
  'pendiente_liquidacion',
];

export class ConfirmarEntregaDto {
  @IsOptional()
  @IsString()
  @IsIn(METODOS_ENTREGA)
  metodo_pago?: string;

  /**
   * Método con el que se cobró el domicilio, cuando difiere del producto
   * (pago mixto: p.ej. producto por transferencia y domicilio en efectivo).
   * Si no se envía, se asume el mismo que `metodo_pago`.
   */
  @IsOptional()
  @IsString()
  @IsIn(METODOS_ENTREGA)
  metodo_pago_domicilio?: string;
}
