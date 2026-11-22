"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const unidad_costeo_util_1 = require("./unidad-costeo.util");
function assert(cond, msg) {
    if (!cond)
        throw new Error(`FAIL: ${msg}`);
}
assert((0, unidad_costeo_util_1.normalizarUnidad)('l') === 'L', 'l → L');
assert((0, unidad_costeo_util_1.normalizarUnidad)('gr') === 'g', 'gr → g');
assert((0, unidad_costeo_util_1.unidadesCompatibles)('g', 'kg'), 'g↔kg');
assert((0, unidad_costeo_util_1.unidadesCompatibles)('ml', 'L'), 'ml↔L');
assert(!(0, unidad_costeo_util_1.unidadesCompatibles)('g', 'ml'), 'g↛ml');
assert((0, unidad_costeo_util_1.convertirCantidad)(1, 'kg', 'g') === 1000, '1kg → 1000g');
assert((0, unidad_costeo_util_1.convertirCantidad)(500, 'g', 'kg') === 0.5, '500g → 0.5kg');
assert((0, unidad_costeo_util_1.convertirCantidad)(2, 'L', 'ml') === 2000, '2L → 2000ml');
assert((0, unidad_costeo_util_1.convertirCantidad)(250, 'ml', 'L') === 0.25, '250ml → 0.25L');
assert(JSON.stringify((0, unidad_costeo_util_1.unidadesDeFamilia)('kg')) === JSON.stringify(['g', 'kg']), 'familia peso');
assert(JSON.stringify((0, unidad_costeo_util_1.unidadesDeFamilia)('L')) === JSON.stringify(['ml', 'L']), 'familia volumen');
console.log('OK unidad-costeo.util.selfcheck');
//# sourceMappingURL=unidad-costeo.util.selfcheck.js.map