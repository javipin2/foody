import { BadRequestException } from '@nestjs/common';

/** Normaliza unidades del Excel KYG / UI Foody. */
export function normalizarUnidad(unidad: string): string {
  const u = (unidad ?? '').trim().toLowerCase();
  const map: Record<string, string> = {
    gr: 'g',
    g: 'g',
    gramo: 'g',
    gramos: 'g',
    kg: 'kg',
    kilo: 'kg',
    kilogramo: 'kg',
    ml: 'ml',
    mililitro: 'ml',
    l: 'L',
    lt: 'L',
    litro: 'L',
    litros: 'L',
    und: 'und',
    un: 'und',
    unidad: 'und',
    unidades: 'und',
    mts: 'mts',
    m: 'mts',
    metro: 'mts',
    servicio: 'servicio',
    porcion: 'servicio',
    porción: 'servicio',
  };
  return map[u] ?? u;
}

const GRUPO_PESO = new Set(['g', 'kg']);
const GRUPO_VOLUMEN = new Set(['ml', 'L']);

export function unidadesCompatibles(
  unidadLinea: string,
  unidadBase: string,
): boolean {
  const a = normalizarUnidad(unidadLinea);
  const b = normalizarUnidad(unidadBase);
  if (a === b) return true;
  if (GRUPO_PESO.has(a) && GRUPO_PESO.has(b)) return true;
  if (GRUPO_VOLUMEN.has(a) && GRUPO_VOLUMEN.has(b)) return true;
  return false;
}

/** Convierte cantidad de `desde` hacia `hacia` (misma familia peso/volumen). */
export function convertirCantidad(
  cantidad: number,
  desde: string,
  hacia: string,
): number {
  const d = normalizarUnidad(desde);
  const h = normalizarUnidad(hacia);
  if (d === h) return cantidad;
  if (d === 'kg' && h === 'g') return cantidad * 1000;
  if (d === 'g' && h === 'kg') return cantidad / 1000;
  if (d === 'L' && h === 'ml') return cantidad * 1000;
  if (d === 'ml' && h === 'L') return cantidad / 1000;
  return cantidad;
}

export function exigirUnidadesCompatibles(
  unidadLinea: string,
  unidadBase: string,
  contexto: string,
): void {
  if (!unidadesCompatibles(unidadLinea, unidadBase)) {
    throw new BadRequestException({
      error: 'UNIDAD_INCOMPATIBLE',
      mensaje: `${contexto}: la línea usa «${unidadLinea}» pero el insumo está en «${unidadBase}». Usa la misma unidad o g/kg, ml/L.`,
    });
  }
}
