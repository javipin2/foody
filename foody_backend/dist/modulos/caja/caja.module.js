"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CajaModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const realtime_module_1 = require("../../core/realtime/realtime.module");
const alertas_module_1 = require("../alertas/alertas.module");
const auditoria_module_1 = require("../auditoria/auditoria.module");
const pedidos_module_1 = require("../pedidos/pedidos.module");
const caja_controller_1 = require("./caja.controller");
const caja_service_1 = require("./caja.service");
let CajaModule = class CajaModule {
};
exports.CajaModule = CajaModule;
exports.CajaModule = CajaModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule, alertas_module_1.AlertasModule, realtime_module_1.RealtimeModule, auditoria_module_1.AuditoriaModule, pedidos_module_1.PedidosModule],
        controllers: [caja_controller_1.CajaController],
        providers: [caja_service_1.CajaService],
        exports: [caja_service_1.CajaService],
    })
], CajaModule);
//# sourceMappingURL=caja.module.js.map