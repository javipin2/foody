"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SuscripcionesCronModule = void 0;
const common_1 = require("@nestjs/common");
const database_module_1 = require("../database/database.module");
const notificaciones_module_1 = require("../../modulos/notificaciones/notificaciones.module");
const pagos_module_1 = require("../../modulos/pagos/pagos.module");
const suscripciones_cron_service_1 = require("./suscripciones-cron.service");
let SuscripcionesCronModule = class SuscripcionesCronModule {
};
exports.SuscripcionesCronModule = SuscripcionesCronModule;
exports.SuscripcionesCronModule = SuscripcionesCronModule = __decorate([
    (0, common_1.Module)({
        imports: [database_module_1.DatabaseModule, notificaciones_module_1.NotificacionesModule, pagos_module_1.PagosModule],
        providers: [suscripciones_cron_service_1.SuscripcionesCronService],
    })
], SuscripcionesCronModule);
//# sourceMappingURL=suscripciones-cron.module.js.map