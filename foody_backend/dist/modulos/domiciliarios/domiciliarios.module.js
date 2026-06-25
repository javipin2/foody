"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DomiciliariosModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const alertas_module_1 = require("../alertas/alertas.module");
const pedidos_module_1 = require("../pedidos/pedidos.module");
const domiciliario_independiente_guard_1 = require("../../core/auth/guards/domiciliario-independiente.guard");
const dispatch_service_1 = require("./dispatch.service");
const domiciliarios_independientes_service_1 = require("./domiciliarios-independientes.service");
const domiciliarios_controller_1 = require("./domiciliarios.controller");
const domiciliarios_service_1 = require("./domiciliarios.service");
let DomiciliariosModule = class DomiciliariosModule {
};
exports.DomiciliariosModule = DomiciliariosModule;
exports.DomiciliariosModule = DomiciliariosModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule, alertas_module_1.AlertasModule, (0, common_1.forwardRef)(() => pedidos_module_1.PedidosModule)],
        controllers: [
            domiciliarios_controller_1.DomiciliariosPlantaController,
            domiciliarios_controller_1.DomiciliarioPlantaController,
            domiciliarios_controller_1.DomiciliariosIndependientesController,
        ],
        providers: [
            domiciliarios_service_1.DomiciliariosService,
            domiciliarios_independientes_service_1.DomiciliariosIndependientesService,
            dispatch_service_1.DispatchService,
            domiciliario_independiente_guard_1.DomiciliarioIndependienteGuard,
        ],
        exports: [domiciliarios_service_1.DomiciliariosService, dispatch_service_1.DispatchService],
    })
], DomiciliariosModule);
//# sourceMappingURL=domiciliarios.module.js.map