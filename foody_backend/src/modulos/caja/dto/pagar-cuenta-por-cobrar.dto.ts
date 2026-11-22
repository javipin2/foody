import { IsIn, IsOptional, IsString } from 'class-validator';

const METODOS = ['efectivo', 'tarjeta', 'transferencia', 'nequi'] as const;

export class PagarCuentaPorCobrarDto {
  @IsOptional()
  @IsString()
  @IsIn(METODOS)
  metodo_pago?: (typeof METODOS)[number];
}
