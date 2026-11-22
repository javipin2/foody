import type { Response } from 'express';
import { RetornoAppQueryDto } from './dto/retorno-app-query.dto';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { CheckoutPlanDto } from './dto/checkout-plan.dto';
import { SincronizarPagoDto } from './dto/sincronizar-pago.dto';
import { PagosService } from './pagos.service';
export declare class PagosController {
    private readonly pagosService;
    constructor(pagosService: PagosService);
    checkout(usuario: JwtPayload, dto: CheckoutPlanDto): Promise<{
        pago_id: string;
        plan: import("./pagos-planes.config").PlanPago;
        monto_centavos: number;
        monto_cop: number;
        checkout_url: string;
        payment_link_id: string;
        referencia_interna: string;
        clave_publica: string;
    }>;
    estado(usuario: JwtPayload): Promise<{
        suscripcion: {
            estado: string;
            plan: string;
            fecha_vencimiento: Date;
        } | null;
        ultimo_pago: {
            id: string;
            plan: string;
            estado: string;
            monto_centavos: number;
            created_at: Date;
            checkout_url: string | null;
        } | null;
        historial: {
            id: string;
            plan: string;
            estado: string;
            monto_centavos: number;
            created_at: Date;
        }[];
        fuente_pago: {
            activa: boolean;
            tipo: string;
            ultimos_cuatro: string | null;
            marca: string | null;
            renovacion_automatica: boolean;
            ultimo_cobro_at: Date | null;
        } | null;
        precios: Record<import("./pagos-planes.config").PlanPago, number>;
    }> | {
        suscripcion: null;
        ultimo_pago: null;
    };
    sincronizar(usuario: JwtPayload, dto: SincronizarPagoDto): Promise<{
        sincronizado: boolean;
        motivo: string;
        plan: import("./pagos-planes.config").PlanPago;
        pago_id: string;
        estado_pago?: undefined;
        transaccion_wompi_id?: undefined;
    } | {
        sincronizado: boolean;
        motivo: string;
        pago_id: string;
        estado_pago: string;
        plan?: undefined;
        transaccion_wompi_id?: undefined;
    } | {
        sincronizado: boolean;
        plan: import("./pagos-planes.config").PlanPago;
        pago_id: string;
        transaccion_wompi_id: string;
        motivo?: undefined;
        estado_pago?: undefined;
    } | {
        sincronizado: boolean;
        motivo: string;
        pago_id: string;
        plan?: undefined;
        estado_pago?: undefined;
        transaccion_wompi_id?: undefined;
    }>;
    renovar(usuario: JwtPayload): Promise<{
        plan: import("./pagos-planes.config").PlanPago;
        iniciado: boolean;
        motivo: string;
        pago_id?: string;
        transaccion_wompi_id?: string;
        estado_transaccion?: string;
        modo: string;
    } | {
        plan: import("./pagos-planes.config").PlanPago;
        pago_id: string;
        monto_centavos: number;
        monto_cop: number;
        checkout_url: string;
        payment_link_id: string;
        referencia_interna: string;
        clave_publica: string;
        modo: string;
        motivo: string;
    }>;
    retornoApp(query: RetornoAppQueryDto, res: Response): void;
    webhookWompi(evento: Record<string, unknown>, checksum?: string): Promise<{
        procesado: boolean;
        motivo?: string;
    }>;
}
