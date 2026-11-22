"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SucursalScopeService = exports.PERMISO_VER_INVENTARIO_HERMANAS = exports.PERMISO_OPERAR_MULTI_SUCURSAL = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const roles_food_1 = require("./roles-food");
exports.PERMISO_OPERAR_MULTI_SUCURSAL = 'gestionar_sucursales';
exports.PERMISO_VER_INVENTARIO_HERMANAS = 'ver_inventario_otras_sucursales';
let SucursalScopeService = class SucursalScopeService {
    database;
    constructor(database) {
        this.database = database;
    }
    esCorporativo(usuario) {
        if (usuario.rol === roles_food_1.ROL_GERENTE_CADENA)
            return true;
        return (usuario.permisos?.includes(exports.PERMISO_OPERAR_MULTI_SUCURSAL) ?? false);
    }
    puedeVerInventarioHermanas(usuario) {
        return (this.esCorporativo(usuario) ||
            (usuario.permisos?.includes(exports.PERMISO_VER_INVENTARIO_HERMANAS) ?? false));
    }
    resolverSucursalId(usuario, solicitada) {
        const bruta = solicitada ?? usuario.sucursal_id;
        const id = typeof bruta === 'string' ? bruta.trim().replace(/^=+/, '') : bruta;
        if (!id) {
            throw new common_1.UnauthorizedException('Usuario sin sucursal asignada');
        }
        return id;
    }
    async assertPerteneceRestaurante(sucursalId, restauranteId) {
        const fila = await this.database.consultarUno(`SELECT id FROM sucursales
       WHERE id = $1 AND restaurante_id = $2 AND activa = true`, [sucursalId, restauranteId]);
        if (!fila) {
            throw new common_1.ForbiddenException('La sucursal no pertenece a tu restaurante o está inactiva');
        }
    }
    async validarLecturaOperativa(usuario, sucursalId) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Usuario sin restaurante asignado');
        }
        await this.assertPerteneceRestaurante(sucursalId, usuario.restaurante_id);
        if (sucursalId === usuario.sucursal_id)
            return;
        if (!this.esCorporativo(usuario)) {
            throw new common_1.ForbiddenException('Solo puedes consultar la operación de tu sucursal asignada');
        }
    }
    async validarLecturaInventario(usuario, sucursalId) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Usuario sin restaurante asignado');
        }
        await this.assertPerteneceRestaurante(sucursalId, usuario.restaurante_id);
        if (sucursalId === usuario.sucursal_id)
            return;
        if (!this.puedeVerInventarioHermanas(usuario)) {
            throw new common_1.ForbiddenException('No tienes permiso para ver inventario de otras sucursales');
        }
    }
    async validarEscritura(usuario, sucursalId) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Usuario sin restaurante asignado');
        }
        await this.assertPerteneceRestaurante(sucursalId, usuario.restaurante_id);
        if (sucursalId === usuario.sucursal_id)
            return;
        if (!this.esCorporativo(usuario)) {
            throw new common_1.ForbiddenException('Solo puedes modificar datos de tu sucursal asignada');
        }
    }
    async resolverLecturaOperativa(usuario, solicitada) {
        const id = this.resolverSucursalId(usuario, solicitada);
        await this.validarLecturaOperativa(usuario, id);
        return id;
    }
    async resolverLecturaInventario(usuario, solicitada) {
        const id = this.resolverSucursalId(usuario, solicitada);
        await this.validarLecturaInventario(usuario, id);
        return id;
    }
    async resolverEscritura(usuario, solicitada) {
        const id = this.resolverSucursalId(usuario, solicitada);
        await this.validarEscritura(usuario, id);
        return id;
    }
};
exports.SucursalScopeService = SucursalScopeService;
exports.SucursalScopeService = SucursalScopeService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], SucursalScopeService);
//# sourceMappingURL=sucursal-scope.service.js.map