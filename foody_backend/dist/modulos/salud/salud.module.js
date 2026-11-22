"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SaludModule = void 0;
const common_1 = require("@nestjs/common");
const realtime_module_1 = require("../../core/realtime/realtime.module");
const impresion_module_1 = require("../../core/impresion/impresion.module");
const health_controller_1 = require("./health.controller");
const salud_controller_1 = require("./salud.controller");
const salud_service_1 = require("./salud.service");
let SaludModule = class SaludModule {
};
exports.SaludModule = SaludModule;
exports.SaludModule = SaludModule = __decorate([
    (0, common_1.Module)({
        imports: [realtime_module_1.RealtimeModule, impresion_module_1.ImpresionModule],
        controllers: [salud_controller_1.SaludController, health_controller_1.HealthController],
        providers: [salud_service_1.SaludService],
    })
], SaludModule);
//# sourceMappingURL=salud.module.js.map