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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var ImpresionService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ImpresionService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const ws_1 = __importDefault(require("ws"));
const database_service_1 = require("../database/database.service");
let ImpresionService = ImpresionService_1 = class ImpresionService {
    database;
    config;
    logger = new common_1.Logger(ImpresionService_1.name);
    procesando = false;
    constructor(database, config) {
        this.database = database;
        this.config = config;
    }
    onModuleInit() {
        setInterval(() => void this.procesarCola(), 5000);
    }
    async encolarPorPedido(pedidoId, sucursalId) {
        try {
            await this.encolarPorPedidoInterno(pedidoId, sucursalId);
        }
        catch (err) {
            this.logger.warn(`Cola impresión pedido ${pedidoId}: ${err instanceof Error ? err.message : String(err)}`);
        }
    }
    async encolarPorPedidoInterno(pedidoId, sucursalId) {
        const cocinas = await this.database.consultar(`SELECT DISTINCT pi.cocina_id, c.nombre AS cocina_nombre
       FROM pedido_items pi
       INNER JOIN pedidos p ON p.id = pi.pedido_id
       LEFT JOIN cocinas c ON c.id = pi.cocina_id
       WHERE pi.pedido_id = $1 AND p.sucursal_id = $2 AND pi.cocina_id IS NOT NULL`, [pedidoId, sucursalId]);
        if (!cocinas.length)
            return;
        const pedido = await this.database.consultarUno(`SELECT numero_pedido, tipo FROM pedidos WHERE id = $1`, [pedidoId]);
        for (const coc of cocinas) {
            const items = await this.database.consultar(`SELECT pr.nombre, pi.cantidad, pi.observaciones
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         WHERE pi.pedido_id = $1 AND pi.cocina_id = $2
         ORDER BY pi.created_at ASC`, [pedidoId, coc.cocina_id]);
            const lineas = items.map((i) => {
                const nota = i.observaciones?.trim();
                return `${i.cantidad}x ${i.nombre}${nota ? ` (${nota})` : ''}`;
            });
            const ticket = [
                `=== ${coc.cocina_nombre ?? 'Cocina'} ===`,
                `Pedido #${pedido?.numero_pedido ?? '?'}`,
                `Tipo: ${pedido?.tipo ?? '—'}`,
                ...lineas,
                '---',
            ].join('\n');
            await this.database.consultar(`INSERT INTO impresion_cocina_jobs (sucursal_id, cocina_id, pedido_id, payload)
         VALUES ($1, $2, $3, $4::jsonb)`, [
                sucursalId,
                coc.cocina_id,
                pedidoId,
                JSON.stringify({ ticket, pedido_id: pedidoId }),
            ]);
        }
        void this.procesarCola();
    }
    async procesarCola() {
        if (this.procesando)
            return;
        this.procesando = true;
        try {
            const jobs = await this.database.consultar(`SELECT id, payload FROM impresion_cocina_jobs
         WHERE estado = 'pendiente'
         ORDER BY created_at ASC
         LIMIT 5`);
            for (const job of jobs) {
                try {
                    await this.enviarTicket(job.payload?.ticket ?? '');
                    await this.database.consultar(`UPDATE impresion_cocina_jobs SET estado = 'enviado' WHERE id = $1`, [job.id]);
                }
                catch (err) {
                    this.logger.warn(`Job impresión ${job.id}: ${String(err)}`);
                    await this.database.consultar(`UPDATE impresion_cocina_jobs SET estado = 'error' WHERE id = $1`, [job.id]);
                }
            }
        }
        finally {
            this.procesando = false;
        }
    }
    enviarTicket(ticket) {
        const url = this.config.get('FOODY_PRINTER_WS') ?? 'ws://127.0.0.1:8765';
        return new Promise((resolve, reject) => {
            const ws = new ws_1.default(url);
            const timeout = setTimeout(() => {
                ws.terminate();
                reject(new Error('Timeout impresora'));
            }, 4000);
            ws.on('open', () => {
                ws.send(JSON.stringify({ ticket, cuerpo: ticket }));
            });
            ws.on('message', () => {
                clearTimeout(timeout);
                ws.close();
                resolve();
            });
            ws.on('error', (err) => {
                clearTimeout(timeout);
                reject(err);
            });
        });
    }
};
exports.ImpresionService = ImpresionService;
exports.ImpresionService = ImpresionService = ImpresionService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        config_1.ConfigService])
], ImpresionService);
//# sourceMappingURL=impresion.service.js.map