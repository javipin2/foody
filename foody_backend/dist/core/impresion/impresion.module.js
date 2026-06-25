"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ImpresionModule = void 0;
const common_1 = require("@nestjs/common");
const database_module_1 = require("../database/database.module");
const impresion_service_1 = require("./impresion.service");
let ImpresionModule = class ImpresionModule {
};
exports.ImpresionModule = ImpresionModule;
exports.ImpresionModule = ImpresionModule = __decorate([
    (0, common_1.Module)({
        imports: [database_module_1.DatabaseModule],
        providers: [impresion_service_1.ImpresionService],
        exports: [impresion_service_1.ImpresionService],
    })
], ImpresionModule);
//# sourceMappingURL=impresion.module.js.map