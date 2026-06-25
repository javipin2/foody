"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RequiereModulo = exports.MODULO_PLAN_KEY = void 0;
const common_1 = require("@nestjs/common");
exports.MODULO_PLAN_KEY = 'modulo_plan';
const RequiereModulo = (modulo) => (0, common_1.SetMetadata)(exports.MODULO_PLAN_KEY, modulo);
exports.RequiereModulo = RequiereModulo;
//# sourceMappingURL=requiere-modulo.decorator.js.map