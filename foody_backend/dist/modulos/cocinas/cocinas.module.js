"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CocinasModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const alertas_module_1 = require("../alertas/alertas.module");
const domiciliarios_module_1 = require("../domiciliarios/domiciliarios.module");
const pedidos_module_1 = require("../pedidos/pedidos.module");
const cocina_tickets_controller_1 = require("./cocina-tickets.controller");
const cocinas_controller_1 = require("./cocinas.controller");
const cocinas_service_1 = require("./cocinas.service");
const cocinas_demoras_cron_service_1 = require("./cocinas-demoras-cron.service");
const impresoras_controller_1 = require("./impresoras.controller");
let CocinasModule = class CocinasModule {
};
exports.CocinasModule = CocinasModule;
exports.CocinasModule = CocinasModule = __decorate([
    (0, common_1.Module)({
        imports: [
            auth_module_1.AuthModule,
            alertas_module_1.AlertasModule,
            domiciliarios_module_1.DomiciliariosModule,
            (0, common_1.forwardRef)(() => pedidos_module_1.PedidosModule),
        ],
        controllers: [
            cocinas_controller_1.CocinasController,
            impresoras_controller_1.ImpresorasController,
            cocina_tickets_controller_1.CocinaTicketsController,
        ],
        providers: [cocinas_service_1.CocinasService, cocinas_demoras_cron_service_1.CocinasDemorasCronService],
        exports: [cocinas_service_1.CocinasService],
    })
], CocinasModule);
//# sourceMappingURL=cocinas.module.js.map