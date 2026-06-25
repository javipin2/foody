import { BadRequestException } from '@nestjs/common';

export type CategoriaInsumo =
  | 'alimento'
  | 'empaque'
  | 'mano_obra'
  | 'servicio';

export interface DatosMercadoInsumo {
  precio_compra: number;
  peso_bruto: number;
  peso_neto: number;
  unidad_base: string;
}

export interface CostoDerivadoMercado {
  costo_unitario_actual: number;
  rendimiento_porcentaje: number;
  factor_correccion: number;
  costo_por_unidad_bruta: number;
}

/** Deriva costo real y rendimiento según Excel KYG (precio / peso neto). */
export function derivarCostoDesdeMercado(
  datos: DatosMercadoInsumo,
): CostoDerivadoMercado {
  const { precio_compra, peso_bruto, peso_neto } = datos;
  if (precio_compra < 0 || peso_bruto <= 0 || peso_neto <= 0) {
    throw new BadRequestException('DATOS_MERCADO_INVALIDOS');
  }
  if (peso_neto > peso_bruto * 1.001) {
    throw new BadRequestException('PESO_NETO_MAYOR_QUE_BRUTO');
  }
  const factor = peso_bruto / peso_neto;
  const costoBruto = precio_compra / peso_bruto;
  const costoReal = precio_compra / peso_neto;
  const rendimiento = (peso_neto / peso_bruto) * 100;
  return {
    costo_unitario_actual: costoReal,
    rendimiento_porcentaje: Math.round(rendimiento * 10000) / 10000,
    factor_correccion: Math.round(factor * 1000000) / 1000000,
    costo_por_unidad_bruta: Math.round(costoBruto * 10000) / 10000,
  };
}

export function tipoCosteoDesdeUnidad(unidad: string): string {
  const u = unidad.toLowerCase();
  if (u === 'und' || u === 'servicio') return 'pieza';
  return 'peso';
}

export function enriquecerInsumoRespuesta<T extends Record<string, unknown>>(
  fila: T,
): T & {
  costo_real: number;
  factor_correccion: number | null;
} {
  const costo = Number(fila.costo_unitario_actual ?? 0);
  const bruto = fila.peso_bruto != null ? Number(fila.peso_bruto) : null;
  const neto = fila.peso_neto != null ? Number(fila.peso_neto) : null;
  let factor: number | null = null;
  if (bruto != null && neto != null && neto > 0) {
    factor = bruto / neto;
  }
  return {
    ...fila,
    costo_real: costo,
    factor_correccion: factor,
  };
}
