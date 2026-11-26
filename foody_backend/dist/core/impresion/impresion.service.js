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
const qa_safety_1 = require("../config/qa-safety");
const MAX_INTENTOS_JOB = 10;
const INTERVALO_COLA_MS = 5000;
let ImpresionService = ImpresionService_1 = class ImpresionService {
    database;
    config;
    logger = new common_1.Logger(ImpresionService_1.name);
    procesando = false;
    LOCK_IMPRESION_COLA = 9200003;
    constructor(database, config) {
        this.database = database;
        this.config = config;
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Cola de impresión pausada por FOODY_QA_SIN_EFECTOS');
            return;
        }
        setInterval(() => void this.database.intentarAdvisoryLock(this.LOCK_IMPRESION_COLA, () => this.procesarCola()), INTERVALO_COLA_MS);
    }
    async reimprimirPedido(pedidoId, sucursalId) {
        const pedido = await this.database.consultarUno(`SELECT id FROM pedidos WHERE id = $1 AND sucursal_id = $2`, [pedidoId, sucursalId]);
        if (!pedido) {
            throw new common_1.NotFoundException({
                error: 'PEDIDO_NO_ENCONTRADO',
                message: 'Pedido no encontrado en esta sucursal',
            });
        }
        const cocinas = await this.database.consultar(`SELECT DISTINCT pi.cocina_id
       FROM pedido_items pi
       WHERE pi.pedido_id = $1 AND pi.cocina_id IS NOT NULL`, [pedidoId]);
        if (!cocinas.length) {
            throw new common_1.BadRequestException({
                error: 'IMPRESION_SIN_COCINA',
                message: 'Este pedido no tiene ítems de cocina para imprimir',
            });
        }
        await this.encolarPorPedidoInterno(pedidoId, sucursalId);
        return { pedido_id: pedidoId, encolado: true };
    }
    async encolarPorPedido(pedidoId, sucursalId) {
        try {
            await this.encolarPorPedidoInterno(pedidoId, sucursalId);
        }
        catch (err) {
            const mensaje = err instanceof Error ? err.message : String(err);
            this.logger.error(`Cola impresión pedido ${pedidoId}: ${mensaje}`);
            try {
                await this.database.consultar(`INSERT INTO impresion_cocina_jobs
             (sucursal_id, cocina_id, pedido_id, payload, estado, ultimo_error)
           VALUES ($1, NULL, $2, $3::jsonb, 'error', $4)`, [
                    sucursalId,
                    pedidoId,
                    JSON.stringify({
                        error_encolado: true,
                        pedido_id: pedidoId,
                    }),
                    mensaje.slice(0, 500),
                ]);
            }
            catch (e2) {
                this.logger.error(`No se pudo registrar job error impresión: ${e2 instanceof Error ? e2.message : e2}`);
            }
        }
    }
    async listarJobs(sucursalId, limit = 20) {
        return this.database.consultar(`SELECT j.id, j.pedido_id, j.cocina_id, j.estado, j.intentos,
              j.ultimo_error, j.simulado, j.created_at, j.procesado_at,
              c.nombre AS cocina_nombre
       FROM impresion_cocina_jobs j
       LEFT JOIN cocinas c ON c.id = j.cocina_id
       WHERE j.sucursal_id = $1
       ORDER BY j.created_at DESC
       LIMIT $2`, [sucursalId, limit]);
    }
    async procesarColaManual() {
        await this.procesarCola();
    }
    async estadisticasCola() {
        const fila = await this.database.consultarUno(`SELECT
         COUNT(*) FILTER (WHERE estado = 'pendiente')::int AS pendientes,
         COUNT(*) FILTER (WHERE estado = 'error')::int AS error,
         COUNT(*) FILTER (
           WHERE estado = 'enviado'
             AND procesado_at > NOW() - INTERVAL '24 hours'
         )::int AS enviados_24h
       FROM impresion_cocina_jobs`);
        return {
            pendientes: fila?.pendientes ?? 0,
            error: fila?.error ?? 0,
            enviados_24h: fila?.enviados_24h ?? 0,
        };
    }
    async verificarAgente() {
        const url = this.config.get('FOODY_PRINTER_WS') ?? 'ws://127.0.0.1:8765';
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            return {
                conectado: false,
                url,
                mensaje: 'Agente de impresión desactivado en QA aislada',
            };
        }
        try {
            const r = await this.enviarWs({ accion: 'ping' }, 3000);
            if (r.exito) {
                return {
                    conectado: true,
                    url,
                    mensaje: 'Agente Python de impresión conectado',
                };
            }
            return {
                conectado: false,
                url,
                mensaje: r.error ?? 'Agente respondió con error',
            };
        }
        catch (err) {
            return {
                conectado: false,
                url,
                mensaje: err instanceof Error
                    ? err.message
                    : 'Agente no disponible - inicia foody_python_printer',
            };
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
        const copiaRow = await this.database.consultarUno(`UPDATE pedidos
       SET comanda_copia = comanda_copia + 1
       WHERE id = $1 AND sucursal_id = $2
       RETURNING comanda_copia`, [pedidoId, sucursalId]);
        const nCopia = copiaRow?.comanda_copia ?? 1;
        const pedido = await this.database.consultarUno(`SELECT p.numero_pedido, p.tipo, p.created_at, m.nombre AS mesa_nombre
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       WHERE p.id = $1`, [pedidoId]);
        const fecha = pedido?.created_at
            ? new Date(pedido.created_at).toLocaleString('es-CO', {
                timeZone: 'America/Bogota',
                dateStyle: 'short',
                timeStyle: 'short',
            })
            : '—';
        for (const coc of cocinas) {
            const items = await this.database.consultar(`SELECT pr.nombre, pi.cantidad, pi.observaciones, pi.producto_id,
                pcs.componentes_snapshot
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         LEFT JOIN pedido_combo_selecciones pcs ON pcs.pedido_item_id = pi.id
         WHERE pi.pedido_id = $1 AND pi.cocina_id = $2
         ORDER BY pi.created_at ASC`, [pedidoId, coc.cocina_id]);
            const lineas = items.map((i) => {
                const nota = i.observaciones?.trim();
                const componentes = Array.isArray(i.componentes_snapshot)
                    ? i.componentes_snapshot
                        .filter((c) => c.item_id !== i.producto_id)
                        .map((c) => `${Number(c.cantidad) * i.cantidad}x ${c.nombre}`)
                    : [];
                const detalle = componentes.length
                    ? ` [Incluye: ${componentes.join(', ')}]`
                    : '';
                return `${i.cantidad}x ${i.nombre}${detalle}${nota ? ` (${nota})` : ''}`;
            });
            const encabezado = [
                `=== ${coc.cocina_nombre ?? 'Cocina'} ===`,
                `Pedido #${pedido?.numero_pedido ?? '?'}`,
                pedido?.mesa_nombre ? `Mesa: ${pedido.mesa_nombre}` : null,
                `Tipo: ${pedido?.tipo ?? '—'}`,
                `Fecha: ${fecha}`,
                '------------------------',
                ...lineas,
                '------------------------',
                `Copia ${nCopia}`,
                'Foody',
            ]
                .filter((l) => l != null)
                .join('\n');
            await this.database.consultar(`INSERT INTO impresion_cocina_jobs (sucursal_id, cocina_id, pedido_id, payload)
         VALUES ($1, $2, $3, $4::jsonb)`, [
                sucursalId,
                coc.cocina_id,
                pedidoId,
                JSON.stringify({
                    ticket: encabezado,
                    pedido_id: pedidoId,
                    copia: nCopia,
                }),
            ]);
        }
        void this.procesarCola();
    }
    async procesarCola() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Procesamiento de impresión bloqueado en QA aislada');
            return;
        }
        if (this.procesando)
            return;
        this.procesando = true;
        try {
            const jobs = await this.database.consultar(`SELECT j.id, j.payload, j.cocina_id, j.intentos,
                i.nombre AS impresora_nombre,
                i.ip_local AS impresora_ip,
                i.tipo AS impresora_tipo
         FROM impresion_cocina_jobs j
         LEFT JOIN impresoras i
           ON i.cocina_id = j.cocina_id
          AND i.sucursal_id = j.sucursal_id
          AND i.activa = true
         WHERE j.estado = 'pendiente'
           AND j.intentos < $1
         ORDER BY j.created_at ASC
         LIMIT 5`, [MAX_INTENTOS_JOB]);
            for (const job of jobs) {
                await this.procesarJob(job);
            }
        }
        finally {
            this.procesando = false;
        }
    }
    async procesarJob(job) {
        const ticket = job.payload?.ticket ?? '';
        try {
            const resultado = await this.enviarTicket(ticket, {
                cocina_id: job.cocina_id,
                impresora: job.impresora_ip
                    ? {
                        nombre: job.impresora_nombre,
                        ip_local: job.impresora_ip,
                        tipo: job.impresora_tipo,
                    }
                    : null,
            });
            if (resultado.exito) {
                await this.database.consultar(`UPDATE impresion_cocina_jobs
           SET estado = 'enviado',
               simulado = $2,
               ultimo_error = NULL,
               procesado_at = now()
           WHERE id = $1`, [job.id, resultado.simulado === true]);
                if (resultado.simulado) {
                    this.logger.log(`Job ${job.id}: ticket simulado (sin impresora física)`);
                }
                return;
            }
            await this.registrarFalloJob(job.id, job.intentos, resultado.error ?? 'Impresión rechazada por el agente');
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            await this.registrarFalloJob(job.id, job.intentos, msg);
        }
    }
    async registrarFalloJob(jobId, intentosActuales, error) {
        const nuevosIntentos = intentosActuales + 1;
        const estado = nuevosIntentos >= MAX_INTENTOS_JOB ? 'error' : 'pendiente';
        await this.database.consultar(`UPDATE impresion_cocina_jobs
       SET intentos = $2,
           ultimo_error = $3,
           estado = $4
       WHERE id = $1`, [jobId, nuevosIntentos, error.slice(0, 500), estado]);
        if (estado === 'error') {
            this.logger.warn(`Job impresión ${jobId} agotó reintentos: ${error}`);
        }
        else {
            this.logger.debug(`Job impresión ${jobId} reintento ${nuevosIntentos}/${MAX_INTENTOS_JOB}: ${error}`);
        }
    }
    enviarTicket(ticket, meta) {
        return this.enviarWs({
            ticket,
            cuerpo: ticket,
            cocina_id: meta?.cocina_id ?? null,
            impresora: meta?.impresora ?? null,
        });
    }
    enviarWs(payload, timeoutMs = 8000) {
        const url = this.config.get('FOODY_PRINTER_WS') ?? 'ws://127.0.0.1:8765';
        return new Promise((resolve, reject) => {
            const ws = new ws_1.default(url);
            let resuelto = false;
            const finalizar = (fn) => {
                if (resuelto)
                    return;
                resuelto = true;
                clearTimeout(timeout);
                try {
                    ws.close();
                }
                catch {
                }
                fn();
            };
            const timeout = setTimeout(() => {
                ws.terminate();
                reject(new Error('Timeout agente impresión'));
            }, timeoutMs);
            ws.on('open', () => {
                ws.send(JSON.stringify(payload));
            });
            ws.on('message', (raw) => {
                try {
                    const texto = raw.toString();
                    const data = JSON.parse(texto);
                    if (data.pong) {
                        finalizar(() => resolve({ exito: true, mensaje: 'pong' }));
                        return;
                    }
                    finalizar(() => {
                        if (data.exito) {
                            resolve(data);
                        }
                        else {
                            resolve({
                                exito: false,
                                error: data.error ?? data.mensaje ?? 'Error desconocido',
                            });
                        }
                    });
                }
                catch {
                    finalizar(() => reject(new Error('Respuesta inválida del agente de impresión')));
                }
            });
            ws.on('error', (err) => {
                finalizar(() => reject(err));
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