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
var PagosService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PagosService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const database_service_1 = require("../../core/database/database.service");
const pagos_planes_config_1 = require("./pagos-planes.config");
const wompi_service_1 = require("./wompi.service");
let PagosService = PagosService_1 = class PagosService {
    database;
    wompi;
    config;
    logger = new common_1.Logger(PagosService_1.name);
    constructor(database, wompi, config) {
        this.database = database;
        this.wompi = wompi;
        this.config = config;
    }
    async crearCheckout(usuario, dto) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Solo dueños de restaurante pueden pagar un plan');
        }
        if (usuario.rol !== 'admin') {
            throw new common_1.ForbiddenException('Solo el administrador del restaurante puede mejorar el plan');
        }
        if (!this.wompi.estaConfigurado()) {
            throw new common_1.BadRequestException('Pasarela de pago no configurada en el servidor');
        }
        const plan = dto.plan;
        if (!(0, pagos_planes_config_1.esPlanPago)(plan)) {
            throw new common_1.BadRequestException('Plan no válido para pago');
        }
        const restaurante = await this.database.consultarUno(`SELECT nombre FROM restaurantes WHERE id = $1`, [usuario.restaurante_id]);
        if (!restaurante)
            throw new common_1.NotFoundException('Restaurante no encontrado');
        const referencia = this.wompi.generarReferenciaInterna();
        const monto = pagos_planes_config_1.PRECIO_PLAN_CENTAVOS[plan];
        const pago = await this.database.consultarUno(`INSERT INTO pagos_suscripcion (
         restaurante_id, usuario_id, plan, monto_centavos, referencia_interna
       ) VALUES ($1, $2, $3, $4, $5)
       RETURNING id`, [usuario.restaurante_id, usuario.sub, plan, monto, referencia]);
        const redirectBase = this.config.get('WOMPI_REDIRECT_URL')?.trim() ||
            'http://localhost:8080/admin/panel?seccion=mejorar_plan';
        const separador = redirectBase.includes('?') ? '&' : '?';
        const redirect = `${redirectBase}${separador}pago_id=${pago.id}`;
        const enlace = await this.wompi.crearEnlacePago({
            nombre: `Foody plan ${plan}`,
            descripcion: `Suscripción mensual Foody — ${restaurante.nombre}`,
            montoCentavos: monto,
            referenciaInterna: referencia,
            redirectUrl: redirect,
        });
        await this.database.consultar(`UPDATE pagos_suscripcion SET
         payment_link_id = $2, referencia_wompi = $3, updated_at = now()
       WHERE id = $1`, [pago.id, enlace.id, referencia]);
        return {
            pago_id: pago.id,
            plan,
            monto_centavos: monto,
            monto_cop: monto / 100,
            checkout_url: enlace.url,
            payment_link_id: enlace.id,
            referencia_interna: referencia,
            clave_publica: this.wompi.clavePublica(),
        };
    }
    async estadoRestaurante(restauranteId) {
        const suscripcion = await this.database.consultarUno(`SELECT estado, plan, fecha_vencimiento
       FROM suscripciones_restaurante WHERE restaurante_id = $1`, [restauranteId]);
        const ultimoPago = await this.database.consultarUno(`SELECT p.id, p.plan, p.estado, p.monto_centavos, p.created_at,
              NULL::text AS checkout_url
       FROM pagos_suscripcion p
       WHERE p.restaurante_id = $1
       ORDER BY p.created_at DESC
       LIMIT 1`, [restauranteId]);
        return {
            suscripcion,
            ultimo_pago: ultimoPago,
            precios: pagos_planes_config_1.PRECIO_PLAN_CENTAVOS,
        };
    }
    async sincronizarPago(restauranteId, dto) {
        let pago = dto.pago_id
            ? await this.database.consultarUno(`SELECT id, restaurante_id, plan, estado, monto_centavos,
                  payment_link_id, referencia_interna
           FROM pagos_suscripcion
           WHERE id = $1 AND restaurante_id = $2`, [dto.pago_id, restauranteId])
            : await this.database.consultarUno(`SELECT id, restaurante_id, plan, estado, monto_centavos,
                  payment_link_id, referencia_interna
           FROM pagos_suscripcion
           WHERE restaurante_id = $1 AND estado = 'pendiente'
           ORDER BY created_at DESC LIMIT 1`, [restauranteId]);
        if (!pago) {
            throw new common_1.NotFoundException('No hay un pago pendiente para sincronizar');
        }
        if (pago.restaurante_id !== restauranteId) {
            throw new common_1.ForbiddenException('El pago no pertenece a este restaurante');
        }
        if (pago.estado === 'aprobado') {
            return {
                sincronizado: true,
                motivo: 'ya_aprobado',
                plan: pago.plan,
                pago_id: pago.id,
            };
        }
        if (!dto.transaccion_wompi_id?.trim()) {
            throw new common_1.BadRequestException('Indica el ID de transacción Wompi del comprobante (ej. 1969957-1782290934-46563)');
        }
        const tx = await this.wompi.consultarTransaccion(dto.transaccion_wompi_id);
        if (tx.payment_link_id && pago.payment_link_id && tx.payment_link_id !== pago.payment_link_id) {
            throw new common_1.BadRequestException('La transacción no corresponde a este checkout');
        }
        if (tx.amount_in_cents !== pago.monto_centavos) {
            throw new common_1.BadRequestException('El monto de la transacción no coincide con el plan');
        }
        if (tx.status === 'APPROVED') {
            await this.aprobarPago(pago, {
                transaccionId: tx.id,
                metodo: tx.payment_method_type,
                referenciaWompi: tx.reference,
            });
            return {
                sincronizado: true,
                plan: pago.plan,
                pago_id: pago.id,
                transaccion_wompi_id: tx.id,
            };
        }
        if (['DECLINED', 'VOIDED', 'ERROR'].includes(tx.status)) {
            await this.database.consultar(`UPDATE pagos_suscripcion SET
           estado = 'rechazado',
           transaccion_wompi_id = $2,
           metodo = COALESCE($3, metodo),
           updated_at = now()
         WHERE id = $1`, [pago.id, tx.id, tx.payment_method_type]);
            throw new common_1.BadRequestException(`El pago fue ${tx.status.toLowerCase()} en Wompi`);
        }
        return {
            sincronizado: false,
            motivo: `transaccion_${tx.status.toLowerCase()}`,
            pago_id: pago.id,
        };
    }
    async aprobarPago(pago, tx) {
        const yaProcesado = await this.database.consultarUno(`SELECT id FROM pagos_suscripcion
       WHERE transaccion_wompi_id = $1 AND estado = 'aprobado'`, [tx.transaccionId]);
        if (yaProcesado)
            return;
        await this.database.enTransaccion(async (client) => {
            await client.query(`UPDATE pagos_suscripcion SET
           estado = 'aprobado',
           metodo = $2,
           transaccion_wompi_id = $3,
           referencia_wompi = COALESCE($4, referencia_wompi),
           updated_at = now()
         WHERE id = $1`, [pago.id, tx.metodo, tx.transaccionId, tx.referenciaWompi]);
            await client.query(`UPDATE suscripciones_restaurante SET
           estado = 'activa',
           plan = $2,
           fecha_vencimiento = now() + interval '30 days',
           motivo_bloqueo = NULL
         WHERE restaurante_id = $1`, [pago.restaurante_id, pago.plan]);
            await client.query(`UPDATE suscripciones_restaurante SET
           aviso_3d_enviado_at = NULL,
           aviso_vence_hoy_enviado_at = NULL
         WHERE restaurante_id = $1`, [pago.restaurante_id]);
        });
        this.logger.log(`Pago aprobado restaurante=${pago.restaurante_id} plan=${pago.plan}`);
    }
    async procesarWebhookWompi(eventoRaw, checksumHeader) {
        const evento = eventoRaw;
        if (!this.wompi.validarFirmaEvento(evento, checksumHeader)) {
            this.logger.warn('Webhook Wompi con firma inválida');
            throw new common_1.BadRequestException('Firma de evento inválida');
        }
        if (evento.event !== 'transaction.updated') {
            return { procesado: false, motivo: 'evento_ignorado' };
        }
        const tx = evento.data['transaction'];
        if (!tx) {
            return { procesado: false, motivo: 'sin_transaccion' };
        }
        const estadoTx = String(tx['status'] ?? '');
        const transaccionId = String(tx['id'] ?? '');
        const paymentLinkId = tx['payment_link_id']
            ? String(tx['payment_link_id'])
            : null;
        const sku = tx['sku'] ? String(tx['sku']) : null;
        const metodo = tx['payment_method_type']
            ? String(tx['payment_method_type'])
            : null;
        if (!transaccionId) {
            return { procesado: false, motivo: 'sin_id_transaccion' };
        }
        const pago = await this.buscarPagoPendiente(paymentLinkId, sku);
        if (!pago) {
            return { procesado: false, motivo: 'pago_no_encontrado' };
        }
        if (estadoTx === 'APPROVED') {
            const yaProcesado = await this.database.consultarUno(`SELECT id FROM pagos_suscripcion
         WHERE transaccion_wompi_id = $1 AND estado = 'aprobado'`, [transaccionId]);
            if (yaProcesado) {
                return { procesado: true, motivo: 'idempotente' };
            }
            await this.aprobarPago(pago, {
                transaccionId,
                metodo,
                referenciaWompi: String(tx['reference'] ?? ''),
            });
            return { procesado: true };
        }
        if (['DECLINED', 'VOIDED', 'ERROR'].includes(estadoTx)) {
            await this.database.consultar(`UPDATE pagos_suscripcion SET
           estado = 'rechazado',
           transaccion_wompi_id = COALESCE(transaccion_wompi_id, $2),
           metodo = COALESCE($3, metodo),
           updated_at = now()
         WHERE id = $1 AND estado = 'pendiente'`, [pago.id, transaccionId, metodo]);
            return { procesado: true, motivo: `transaccion_${estadoTx.toLowerCase()}` };
        }
        return { procesado: false, motivo: `estado_${estadoTx}` };
    }
    async buscarPagoPendiente(paymentLinkId, sku) {
        if (paymentLinkId) {
            const porLink = await this.database.consultarUno(`SELECT id, restaurante_id, plan FROM pagos_suscripcion
         WHERE payment_link_id = $1
         ORDER BY created_at DESC LIMIT 1`, [paymentLinkId]);
            if (porLink)
                return porLink;
        }
        if (sku) {
            return this.database.consultarUno(`SELECT id, restaurante_id, plan FROM pagos_suscripcion
         WHERE referencia_interna = $1
         ORDER BY created_at DESC LIMIT 1`, [sku]);
        }
        return null;
    }
};
exports.PagosService = PagosService;
exports.PagosService = PagosService = PagosService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        wompi_service_1.WompiService,
        config_1.ConfigService])
], PagosService);
//# sourceMappingURL=pagos.service.js.map