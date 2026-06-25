"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AlertasModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const realtime_module_1 = require("../../core/realtime/realtime.module");
const alertas_controller_1 = require("./alertas.controller");
const alertas_riesgo_service_1 = require("./alertas-riesgo.service");
const alertas_service_1 = require("./alertas.service");
let AlertasModule = class AlertasModule {
};
exports.AlertasModule = AlertasModule;
exports.AlertasModule = AlertasModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule, realtime_module_1.RealtimeModule],
        controllers: [alertas_controller_1.AlertasController],
        providers: [alertas_service_1.AlertasService, alertas_riesgo_service_1.AlertasRiesgoService],
        exports: [alertas_service_1.AlertasService, alertas_riesgo_service_1.AlertasRiesgoService],
    })
], AlertasModule);
//# sourceMappingURL=alertas.module.js.map