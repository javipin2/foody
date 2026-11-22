"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PagosModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../../core/auth/auth.module");
const database_module_1 = require("../../core/database/database.module");
const pagos_controller_1 = require("./pagos.controller");
const pagos_recurrentes_service_1 = require("./pagos-recurrentes.service");
const pagos_service_1 = require("./pagos.service");
const wompi_service_1 = require("./wompi.service");
let PagosModule = class PagosModule {
};
exports.PagosModule = PagosModule;
exports.PagosModule = PagosModule = __decorate([
    (0, common_1.Module)({
        imports: [database_module_1.DatabaseModule, auth_module_1.AuthModule],
        controllers: [pagos_controller_1.PagosController],
        providers: [pagos_service_1.PagosService, pagos_recurrentes_service_1.PagosRecurrentesService, wompi_service_1.WompiService],
        exports: [pagos_service_1.PagosService, pagos_recurrentes_service_1.PagosRecurrentesService, wompi_service_1.WompiService],
    })
], PagosModule);
//# sourceMappingURL=pagos.module.js.map