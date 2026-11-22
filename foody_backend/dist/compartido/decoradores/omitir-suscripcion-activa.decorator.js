"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OmitirSuscripcionActiva = exports.OMITIR_SUSCRIPCION_ACTIVA_KEY = void 0;
const common_1 = require("@nestjs/common");
exports.OMITIR_SUSCRIPCION_ACTIVA_KEY = 'omitir_suscripcion_activa';
const OmitirSuscripcionActiva = () => (0, common_1.SetMetadata)(exports.OMITIR_SUSCRIPCION_ACTIVA_KEY, true);
exports.OmitirSuscripcionActiva = OmitirSuscripcionActiva;
//# sourceMappingURL=omitir-suscripcion-activa.decorator.js.map