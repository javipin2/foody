"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CosteoModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const alertas_module_1 = require("../alertas/alertas.module");
const stock_movimiento_module_1 = require("../inventario/stock-movimiento.module");
const costeo_controller_1 = require("./costeo.controller");
const costeo_service_1 = require("./costeo.service");
let CosteoModule = class CosteoModule {
};
exports.CosteoModule = CosteoModule;
exports.CosteoModule = CosteoModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule, alertas_module_1.AlertasModule, stock_movimiento_module_1.StockMovimientoModule],
        controllers: [costeo_controller_1.CosteoController],
        providers: [costeo_service_1.CosteoService],
        exports: [costeo_service_1.CosteoService],
    })
], CosteoModule);
//# sourceMappingURL=costeo.module.js.map