"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PermisosTodos = exports.Permisos = exports.PERMISOS_TODOS_KEY = exports.PERMISOS_KEY = void 0;
const common_1 = require("@nestjs/common");
exports.PERMISOS_KEY = 'permisos';
exports.PERMISOS_TODOS_KEY = 'permisos_todos';
const Permisos = (...permisos) => (0, common_1.SetMetadata)(exports.PERMISOS_KEY, permisos);
exports.Permisos = Permisos;
const PermisosTodos = (...permisos) => (0, common_1.SetMetadata)(exports.PERMISOS_TODOS_KEY, permisos);
exports.PermisosTodos = PermisosTodos;
//# sourceMappingURL=permisos.decorator.js.map