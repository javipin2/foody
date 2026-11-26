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
var PagosRecurrentesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PagosRecurrentesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const roles_food_1 = require("../../core/auth/roles-food");
const pagos_planes_config_1 = require("./pagos-planes.config");
const wompi_service_1 = require("./wompi.service");
let PagosRecurrentesService = PagosRecurrentesService_1 = class PagosRecurrentesService {
    database;
    wompi;
    logger = new common_1.Logger(PagosRecurrentesService_1.name);
    constructor(database, wompi) {
        this.database = database;
        this.wompi = wompi;
    }
    async obtenerFuenteActiva(restauranteId) {
        return this.database.consultarUno(`SELECT id, restaurante_id, wompi_payment_source_id, tipo, estado_wompi,
              ultimos_cuatro, marca, customer_email, activa,
              ultimo_cobro_at, ultimo_intento_at
       FROM fuentes_pago
       WHERE restaurante_id = $1 AND activa = true
       LIMIT 1`, [restauranteId]);
    }
    resumenFuente(fuente) {
        if (!fuente)
            return null;
        return {
            activa: fuente.activa,
            tipo: fuente.tipo,
            ultimos_cuatro: fuente.ultimos_cuatro,
            marca: fuente.marca,
            renovacion_automatica: true,
            ultimo_cobro_at: fuente.ultimo_cobro_at,
        };
    }
    async registrarFuenteDesdeTransaccion(restauranteId, transaccionId, paymentSourceIdDirecto) {
        if (!this.wompi.estaConfigurado())
            return;
        let paymentSourceId = paymentSourceIdDirecto?.trim() || null;
        let customerEmail = null;
        let metodo = null;
        try {
            const tx = await this.wompi.consultarTransaccion(transaccionId);
            paymentSourceId = paymentSourceId ?? tx.payment_source_id;
            customerEmail = tx.customer_email;
            metodo = tx.payment_method_type;
        }
        catch (e) {
            const mensaje = e instanceof Error ? e.message : String(e);
            this.logger.error(`No se pudo consultar TX ${transaccionId} para fuente: ${mensaje}`);
            if (!paymentSourceId) {
                throw new common_1.BadRequestException(`No se pudo obtener fuente de pago desde la transacción: ${mensaje}`);
            }
        }
        if (!paymentSourceId) {
            throw new common_1.BadRequestException('La transacción aprobada no incluye payment_source_id (renovación automática no disponible)');
        }
        let ultimosCuatro = null;
        let marca = null;
        let estadoWompi = null;
        let tipo = this.mapearTipoFuente(metodo);
        try {
            const fuente = await this.wompi.consultarFuentePago(paymentSourceId);
            estadoWompi = fuente.status;
            tipo = fuente.type ?? tipo;
            ultimosCuatro = fuente.public_data?.last_four ?? null;
            marca = fuente.public_data?.brand ?? null;
            if (!['AVAILABLE', 'APPROVED'].includes(fuente.status)) {
                this.logger.error(`Fuente Wompi ${paymentSourceId} no disponible: ${fuente.status}`);
            }
        }
        catch (e) {
            const mensaje = e instanceof Error ? e.message : String(e);
            this.logger.error(`Consulta fuente ${paymentSourceId} falló (se guarda id sin metadata): ${mensaje}`);
            estadoWompi = estadoWompi ?? 'consulta_fallida';
        }
        await this.database.consultar(`UPDATE fuentes_pago SET activa = false, updated_at = now()
       WHERE restaurante_id = $1 AND activa = true
         AND wompi_payment_source_id <> $2`, [restauranteId, paymentSourceId]);
        await this.database.consultar(`INSERT INTO fuentes_pago (
         restaurante_id, wompi_payment_source_id, tipo, estado_wompi,
         ultimos_cuatro, marca, customer_email, activa
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, true)
       ON CONFLICT (restaurante_id, wompi_payment_source_id)
       DO UPDATE SET
         tipo = EXCLUDED.tipo,
         estado_wompi = EXCLUDED.estado_wompi,
         ultimos_cuatro = COALESCE(EXCLUDED.ultimos_cuatro, fuentes_pago.ultimos_cuatro),
         marca = COALESCE(EXCLUDED.marca, fuentes_pago.marca),
         customer_email = COALESCE(EXCLUDED.customer_email, fuentes_pago.customer_email),
         activa = true,
         updated_at = now()`, [
            restauranteId,
            paymentSourceId,
            tipo,
            estadoWompi,
            ultimosCuatro,
            marca,
            customerEmail,
        ]);
        this.logger.log(`Fuente de pago registrada restaurante=${restauranteId} wompi=${paymentSourceId}`);
    }
    async listarCandidatasRenovacionAutomatica() {
        return this.database.consultar(`SELECT s.restaurante_id, s.plan, s.estado, s.fecha_vencimiento,
              f.id AS fuente_id, f.wompi_payment_source_id, f.customer_email
       FROM suscripciones_restaurante s
       INNER JOIN fuentes_pago f
         ON f.restaurante_id = s.restaurante_id AND f.activa = true
       WHERE s.estado = 'activa'
         AND s.plan IN ('basico', 'pro', 'enterprise')
         AND s.fecha_vencimiento IS NOT NULL
         AND s.fecha_vencimiento <= now() + interval '2 days'
         AND s.fecha_vencimiento > now() - interval '12 hours'
         AND (f.ultimo_intento_at IS NULL OR f.ultimo_intento_at < now() - interval '20 hours')
         AND NOT EXISTS (
           SELECT 1 FROM pagos_suscripcion p
           WHERE p.restaurante_id = s.restaurante_id
             AND p.estado IN ('pendiente', 'aprobado')
             AND p.created_at > now() - interval '5 days'
             AND p.plan = s.plan
         )`);
    }
    async intentarCobroRenovacion(restauranteId, planForzado) {
        if (!this.wompi.estaConfigurado()) {
            return { iniciado: false, motivo: 'wompi_no_configurado' };
        }
        const suscripcion = await this.database.consultarUno(`SELECT plan, estado FROM suscripciones_restaurante WHERE restaurante_id = $1`, [restauranteId]);
        if (!suscripcion) {
            throw new common_1.NotFoundException('Suscripción no encontrada');
        }
        const plan = planForzado ?? suscripcion.plan;
        if (!(0, pagos_planes_config_1.esPlanPago)(plan)) {
            return { iniciado: false, motivo: 'plan_no_pagable' };
        }
        const fuente = await this.obtenerFuenteActiva(restauranteId);
        if (!fuente) {
            return { iniciado: false, motivo: 'sin_fuente_pago' };
        }
        const email = fuente.customer_email ??
            (await this.emailAdminRestaurante(restauranteId));
        if (!email) {
            return { iniciado: false, motivo: 'sin_email_cobro' };
        }
        const referencia = this.wompi.generarReferenciaInterna();
        const monto = pagos_planes_config_1.PRECIO_PLAN_CENTAVOS[plan];
        const reserva = await this.database.enTransaccion(async (client) => {
            const suscripcionBloqueada = await client.query(`SELECT restaurante_id FROM suscripciones_restaurante
         WHERE restaurante_id = $1 FOR UPDATE`, [restauranteId]);
            if (!suscripcionBloqueada.rows[0]) {
                return { pagoId: null, motivo: 'suscripcion_no_encontrada' };
            }
            const pagoReciente = await client.query(`SELECT id, estado FROM pagos_suscripcion
         WHERE restaurante_id = $1 AND plan = $2
           AND estado IN ('pendiente', 'aprobado')
           AND created_at > now() - interval '5 days'
         LIMIT 1`, [restauranteId, plan]);
            if (pagoReciente.rows[0]) {
                return {
                    pagoId: null,
                    motivo: pagoReciente.rows[0].estado === 'aprobado'
                        ? 'pago_reciente_aprobado'
                        : 'pago_reciente_existente',
                };
            }
            const fuenteReservada = await client.query(`UPDATE fuentes_pago SET ultimo_intento_at = now(), updated_at = now()
         WHERE id = $1 AND restaurante_id = $2 AND activa = true
           AND (ultimo_intento_at IS NULL
                OR ultimo_intento_at < now() - interval '20 hours')
         RETURNING id`, [fuente.id, restauranteId]);
            if (!fuenteReservada.rows[0]) {
                return { pagoId: null, motivo: 'intento_reciente' };
            }
            const pago = await client.query(`INSERT INTO pagos_suscripcion (
           restaurante_id, plan, monto_centavos, referencia_interna, metodo
         ) VALUES ($1, $2, $3, $4, 'renovacion_automatica')
         RETURNING id`, [restauranteId, plan, monto, referencia]);
            return { pagoId: pago.rows[0]?.id ?? null, motivo: 'iniciado' };
        });
        if (!reserva.pagoId) {
            return { iniciado: false, motivo: reserva.motivo };
        }
        const pagoId = reserva.pagoId;
        try {
            const tx = await this.wompi.crearTransaccionRecurrente({
                referenciaInterna: referencia,
                montoCentavos: monto,
                customerEmail: email,
                paymentSourceId: fuente.wompi_payment_source_id,
            });
            await this.database.consultar(`UPDATE pagos_suscripcion SET
           transaccion_wompi_id = $2,
           referencia_wompi = $3,
           updated_at = now()
         WHERE id = $1`, [pagoId, tx.id, tx.reference]);
            if (tx.status === 'APPROVED') {
                await this.database.consultar(`UPDATE pagos_suscripcion SET estado = 'aprobado', updated_at = now()
           WHERE id = $1`, [pagoId]);
                await this.extenderSuscripcion(restauranteId, plan);
                await this.database.consultar(`UPDATE fuentes_pago SET ultimo_cobro_at = now(), updated_at = now()
           WHERE id = $1`, [fuente.id]);
            }
            return {
                iniciado: true,
                motivo: tx.status === 'APPROVED'
                    ? 'cobro_aprobado'
                    : 'cobro_pendiente_webhook',
                pago_id: pagoId,
                transaccion_wompi_id: tx.id,
                estado_transaccion: tx.status,
            };
        }
        catch (e) {
            await this.database.consultar(`UPDATE pagos_suscripcion SET estado = 'error', updated_at = now()
         WHERE id = $1`, [pagoId]);
            throw e;
        }
    }
    async extenderSuscripcion(restauranteId, plan) {
        await this.database.consultar(`UPDATE suscripciones_restaurante SET
         estado = 'activa',
         plan = $2,
         fecha_vencimiento = GREATEST(
           COALESCE(fecha_vencimiento, now()),
           now()
         ) + interval '30 days',
         motivo_bloqueo = NULL,
         aviso_3d_enviado_at = NULL,
         aviso_vence_hoy_enviado_at = NULL
       WHERE restaurante_id = $1`, [restauranteId, plan]);
    }
    async emailAdminRestaurante(restauranteId) {
        const fila = await this.database.consultarUno(`SELECT correo FROM usuarios
       WHERE restaurante_id = $1
         AND rol IN ('admin', '${roles_food_1.ROL_GERENTE_CADENA}')
         AND activo = true
       ORDER BY CASE WHEN rol = 'admin' THEN 0 ELSE 1 END, created_at ASC
       LIMIT 1`, [restauranteId]);
        return fila?.correo ?? null;
    }
    mapearTipoFuente(metodo) {
        if (!metodo)
            return 'OTRO';
        const m = metodo.toUpperCase();
        if (m.includes('CARD'))
            return 'CARD';
        if (m.includes('NEQUI'))
            return 'NEQUI';
        if (m.includes('BANCOLOMBIA'))
            return 'BANCOLOMBIA_TRANSFER';
        return 'OTRO';
    }
};
exports.PagosRecurrentesService = PagosRecurrentesService;
exports.PagosRecurrentesService = PagosRecurrentesService = PagosRecurrentesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        wompi_service_1.WompiService])
], PagosRecurrentesService);
//# sourceMappingURL=pagos-recurrentes.service.js.map