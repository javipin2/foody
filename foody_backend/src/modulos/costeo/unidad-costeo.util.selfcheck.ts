/**
 * ponytail: runnable check — conversión g↔kg / ml↔L.
 * Ejecutar: npx ts-node -r tsconfig-paths/register src/modulos/costeo/unidad-costeo.util.selfcheck.ts
 * o tras build: node -e "require('./dist/...')" vía script verificar.
 */
import {
  convertirCantidad,
  normalizarUnidad,
  unidadesCompatibles,
  unidadesDeFamilia,
} from './unidad-costeo.util';

function assert(cond: boolean, msg: string) {
  if (!cond) throw new Error(`FAIL: ${msg}`);
}

assert(normalizarUnidad('l') === 'L', 'l → L');
assert(normalizarUnidad('gr') === 'g', 'gr → g');
assert(unidadesCompatibles('g', 'kg'), 'g↔kg');
assert(unidadesCompatibles('ml', 'L'), 'ml↔L');
assert(!unidadesCompatibles('g', 'ml'), 'g↛ml');
assert(convertirCantidad(1, 'kg', 'g') === 1000, '1kg → 1000g');
assert(convertirCantidad(500, 'g', 'kg') === 0.5, '500g → 0.5kg');
assert(convertirCantidad(2, 'L', 'ml') === 2000, '2L → 2000ml');
assert(convertirCantidad(250, 'ml', 'L') === 0.25, '250ml → 0.25L');
assert(
  JSON.stringify(unidadesDeFamilia('kg')) === JSON.stringify(['g', 'kg']),
  'familia peso',
);
assert(
  JSON.stringify(unidadesDeFamilia('L')) === JSON.stringify(['ml', 'L']),
  'familia volumen',
);

console.log('OK unidad-costeo.util.selfcheck');
