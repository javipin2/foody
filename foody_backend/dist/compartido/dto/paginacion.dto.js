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
exports.PaginacionQueryDto = exports.LIMITE_LISTADO_SIN_PAGINA = void 0;
exports.resolverPaginacion = resolverPaginacion;
exports.envolverPaginado = envolverPaginado;
exports.opcionesListado = opcionesListado;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
exports.LIMITE_LISTADO_SIN_PAGINA = 200;
class PaginacionQueryDto {
    page;
    limit;
}
exports.PaginacionQueryDto = PaginacionQueryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], PaginacionQueryDto.prototype, "page", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(100),
    __metadata("design:type", Number)
], PaginacionQueryDto.prototype, "limit", void 0);
function resolverPaginacion(page, limit, limitPorDefecto = 20) {
    const p = Math.max(1, page ?? 1);
    const l = Math.min(100, Math.max(1, limit ?? limitPorDefecto));
    return { page: p, limit: l, offset: (p - 1) * l };
}
function envolverPaginado(items, total, page, limit) {
    return {
        items,
        total,
        page,
        limit,
        totalPages: total === 0 ? 0 : Math.ceil(total / limit),
    };
}
function opcionesListado(query, limitPorDefectoPagina = 50) {
    if (query.page != null) {
        const { page, limit } = resolverPaginacion(query.page, query.limit, limitPorDefectoPagina);
        return { paginar: true, page, limite: limit };
    }
    const tope = query.limit != null
        ? Math.min(100, Math.max(1, query.limit))
        : exports.LIMITE_LISTADO_SIN_PAGINA;
    return { paginar: false, limite: tope };
}
//# sourceMappingURL=paginacion.dto.js.map