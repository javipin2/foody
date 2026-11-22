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
exports.DomiciliariosDocumentosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const almacenamiento_service_1 = require("../almacenamiento/almacenamiento.service");
const domiciliarios_documentos_config_1 = require("./domiciliarios-documentos.config");
let DomiciliariosDocumentosService = class DomiciliariosDocumentosService {
    database;
    almacenamiento;
    constructor(database, almacenamiento) {
        this.database = database;
        this.almacenamiento = almacenamiento;
    }
    listarTiposRequeridos() {
        return domiciliarios_documentos_config_1.TIPOS_DOCUMENTO_DOMICILIARIO;
    }
    async listarPorDomiciliario(domiciliarioId) {
        return this.database.consultar(`SELECT id, tipo, url, estado, motivo_rechazo, created_at, revisado_por
       FROM documentos_domiciliario
       WHERE domiciliario_id = $1
       ORDER BY created_at DESC`, [domiciliarioId]);
    }
    async resumenCarga(domiciliarioId) {
        const docs = await this.listarPorDomiciliario(domiciliarioId);
        const porTipo = new Map();
        for (const d of docs) {
            const actual = porTipo.get(d.tipo);
            if (!actual || new Date(d.created_at) > new Date(actual.created_at)) {
                porTipo.set(d.tipo, d);
            }
        }
        const faltantes = domiciliarios_documentos_config_1.TIPOS_DOCUMENTO_DOMICILIARIO.filter((t) => {
            const doc = porTipo.get(t);
            return !doc || doc.estado === 'rechazado';
        });
        const pendientesRevision = [...porTipo.values()].filter((d) => d.estado === 'pendiente').length;
        return {
            documentos: [...porTipo.values()],
            faltantes,
            completo: faltantes.length === 0,
            pendientes_revision: pendientesRevision,
        };
    }
    async subir(domiciliarioId, tipo, archivo) {
        if (!(0, domiciliarios_documentos_config_1.esTipoDocumentoDomiciliario)(tipo)) {
            throw new common_1.BadRequestException('Tipo de documento no válido');
        }
        const dom = await this.database.consultarUno(`SELECT estado_cuenta FROM domiciliarios_independientes WHERE id = $1`, [domiciliarioId]);
        if (!dom)
            throw new common_1.NotFoundException('Domiciliario no encontrado');
        if (dom.estado_cuenta === 'activo') {
            const aprobado = await this.database.consultarUno(`SELECT id FROM documentos_domiciliario
         WHERE domiciliario_id = $1 AND tipo = $2 AND estado = 'aprobado'
         LIMIT 1`, [domiciliarioId, tipo]);
            if (aprobado) {
                throw new common_1.BadRequestException('Este documento ya fue aprobado. Contacta a soporte si necesitas actualizarlo.');
            }
        }
        const { url } = await this.almacenamiento.subirDocumentoDomiciliario(domiciliarioId, tipo, archivo);
        const existente = await this.database.consultarUno(`SELECT id FROM documentos_domiciliario
       WHERE domiciliario_id = $1 AND tipo = $2
         AND estado IN ('pendiente', 'rechazado')
       ORDER BY created_at DESC
       LIMIT 1`, [domiciliarioId, tipo]);
        if (existente) {
            await this.database.consultar(`UPDATE documentos_domiciliario SET
           url = $2,
           estado = 'pendiente',
           motivo_rechazo = NULL,
           revisado_por = NULL
         WHERE id = $1`, [existente.id, url]);
            return { id: existente.id, tipo, url, estado: 'pendiente' };
        }
        const fila = await this.database.consultarUno(`INSERT INTO documentos_domiciliario (domiciliario_id, tipo, url, estado)
       VALUES ($1, $2, $3, 'pendiente')
       RETURNING id`, [domiciliarioId, tipo, url]);
        return { id: fila.id, tipo, url, estado: 'pendiente' };
    }
};
exports.DomiciliariosDocumentosService = DomiciliariosDocumentosService;
exports.DomiciliariosDocumentosService = DomiciliariosDocumentosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        almacenamiento_service_1.AlmacenamientoService])
], DomiciliariosDocumentosService);
//# sourceMappingURL=domiciliarios-documentos.service.js.map