"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.InventarioModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const alertas_module_1 = require("../alertas/alertas.module");
const costeo_module_1 = require("../costeo/costeo.module");
const catalogo_module_1 = require("../catalogo/catalogo.module");
const inventario_controller_1 = require("./inventario.controller");
const inventario_service_1 = require("./inventario.service");
const stock_movimiento_module_1 = require("./stock-movimiento.module");
let InventarioModule = class InventarioModule {
};
exports.InventarioModule = InventarioModule;
exports.InventarioModule = InventarioModule = __decorate([
    (0, common_1.Module)({
        imports: [
            auth_module_1.AuthModule,
            alertas_module_1.AlertasModule,
            costeo_module_1.CosteoModule,
            catalogo_module_1.CatalogoModule,
            stock_movimiento_module_1.StockMovimientoModule,
        ],
        controllers: [inventario_controller_1.InventarioController],
        providers: [inventario_service_1.InventarioService],
        exports: [inventario_service_1.InventarioService, stock_movimiento_module_1.StockMovimientoModule],
    })
], InventarioModule);
//# sourceMappingURL=inventario.module.js.map