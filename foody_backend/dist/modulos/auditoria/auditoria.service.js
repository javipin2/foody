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
exports.AuditoriaService = void 0;
const common_1 = require("@nestjs/common");
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
const database_service_1 = require("../../core/database/database.service");
let AuditoriaService = class AuditoriaService {
    database;
    constructor(database) {
        this.database = database;
    }
    async registrarEnTransaccion(client, registro) {
        await client.query(`INSERT INTO auditoria_logs (
         sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_antes, datos_despues
       ) VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7::jsonb)`, [
            registro.sucursalId,
            registro.usuarioId ?? null,
            registro.accion,
            registro.tablaAfectada,
            registro.registroId,
            registro.datosAntes ? JSON.stringify(registro.datosAntes) : null,
            registro.datosDespues ? JSON.stringify(registro.datosDespues) : null,
        ]);
    }
    async registrar(registro) {
        await this.database.enTransaccion((client) => this.registrarEnTransaccion(client, registro));
    }
    async timelineTurno(filtro) {
        const { sucursal_id, desde, hasta } = filtro;
        const auditoria = await this.database.consultar(`SELECT a.id, a.created_at AS ocurrido_at, 'auditoria' AS fuente,
              a.accion AS tipo, a.tabla_afectada, a.registro_id,
              a.datos_despues AS detalle,
              u.nombre AS usuario_nombre
       FROM auditoria_logs a
       LEFT JOIN usuarios u ON u.id = a.usuario_id
       WHERE a.sucursal_id = $1
         AND ${(0, ventas_metricas_sql_1.sqlFechaRango)('a.created_at', '$2', '$3')}
       ORDER BY a.created_at ASC
       LIMIT 500`, [sucursal_id, desde, hasta]);
        const alertas = await this.database.consultar(`SELECT ar.id, ar.created_at AS ocurrido_at, 'alerta' AS fuente,
              ar.tipo, ar.nivel, ar.descripcion AS detalle,
              ar.referencia_id, ar.referencia_tipo, ar.revisada
       FROM alertas_riesgo ar
       WHERE ar.sucursal_id = $1
         AND ${(0, ventas_metricas_sql_1.sqlFechaRango)('ar.created_at', '$2', '$3')}
       ORDER BY ar.created_at ASC
       LIMIT 500`, [sucursal_id, desde, hasta]);
        const caja = await this.database.consultar(`SELECT m.id, m.created_at AS ocurrido_at, 'caja' AS fuente,
              m.tipo, m.monto, m.metodo_pago, m.descripcion AS detalle,
              m.pedido_id, u.nombre AS usuario_nombre
       FROM movimientos_caja m
       LEFT JOIN usuarios u ON u.id = m.usuario_id
       WHERE m.sucursal_id = $1
         AND ${(0, ventas_metricas_sql_1.sqlFechaRango)('m.created_at', '$2', '$3')}
       ORDER BY m.created_at ASC
       LIMIT 500`, [sucursal_id, desde, hasta]);
        const pedidos = await this.database.consultar(`SELECT p.id, p.created_at AS ocurrido_at, 'pedido' AS fuente,
              p.estado AS tipo, p.numero_pedido, p.total, p.tipo AS canal
       FROM pedidos p
       WHERE p.sucursal_id = $1
         AND ${(0, ventas_metricas_sql_1.sqlFechaRango)('p.created_at', '$2', '$3')}
       ORDER BY p.created_at ASC
       LIMIT 500`, [sucursal_id, desde, hasta]);
        const eventos = [
            ...auditoria.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
            ...alertas.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
            ...caja.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
            ...pedidos.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
        ].sort((a, b) => new Date(String(a.ocurrido_at)).getTime() -
            new Date(String(b.ocurrido_at)).getTime());
        return {
            sucursal_id,
            desde,
            hasta,
            total_eventos: eventos.length,
            resumen: {
                auditoria: auditoria.length,
                alertas: alertas.length,
                caja: caja.length,
                pedidos: pedidos.length,
            },
            eventos,
        };
    }
};
exports.AuditoriaService = AuditoriaService;
exports.AuditoriaService = AuditoriaService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], AuditoriaService);
//# sourceMappingURL=auditoria.service.js.map