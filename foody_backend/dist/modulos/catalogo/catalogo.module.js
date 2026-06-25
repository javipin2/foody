"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CatalogoModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const costeo_module_1 = require("../costeo/costeo.module");
const realtime_module_1 = require("../../core/realtime/realtime.module");
const catalogo_service_1 = require("./catalogo.service");
const catalogo_disponibilidad_service_1 = require("./catalogo-disponibilidad.service");
const bebidas_controller_1 = require("./bebidas.controller");
const combos_controller_1 = require("./combos.controller");
const categorias_controller_1 = require("./categorias.controller");
const productos_controller_1 = require("./productos.controller");
const toppings_controller_1 = require("./toppings.controller");
let CatalogoModule = class CatalogoModule {
};
exports.CatalogoModule = CatalogoModule;
exports.CatalogoModule = CatalogoModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule, costeo_module_1.CosteoModule, realtime_module_1.RealtimeModule],
        controllers: [
            categorias_controller_1.CategoriasController,
            productos_controller_1.ProductosController,
            toppings_controller_1.ToppingsController,
            bebidas_controller_1.BebidasController,
            combos_controller_1.CombosController,
        ],
        providers: [catalogo_service_1.CatalogoService, catalogo_disponibilidad_service_1.CatalogoDisponibilidadService],
        exports: [catalogo_service_1.CatalogoService, catalogo_disponibilidad_service_1.CatalogoDisponibilidadService],
    })
], CatalogoModule);
//# sourceMappingURL=catalogo.module.js.map