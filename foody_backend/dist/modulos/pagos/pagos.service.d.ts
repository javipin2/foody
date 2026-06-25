import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { CheckoutPlanDto } from './dto/checkout-plan.dto';
import { SincronizarPagoDto } from './dto/sincronizar-pago.dto';
import { PlanPago } from './pagos-planes.config';
import { WompiService } from './wompi.service';
export declare class PagosService {
    private readonly database;
    private readonly wompi;
    private readonly config;
    private readonly logger;
    constructor(database: DatabaseService, wompi: WompiService, config: ConfigService);
    crearCheckout(usuario: JwtPayload, dto: CheckoutPlanDto): Promise<{
        pago_id: string;
        plan: PlanPago;
        monto_centavos: number;
        monto_cop: number;
        checkout_url: string;
        payment_link_id: string;
        referencia_interna: string;
        clave_publica: string;
    }>;
    estadoRestaurante(restauranteId: string): Promise<{
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
        precios: Record<PlanPago, number>;
    }>;
    sincronizarPago(restauranteId: string, dto: SincronizarPagoDto): Promise<{
        sincronizado: boolean;
        motivo: string;
        plan: PlanPago;
        pago_id: string;
        transaccion_wompi_id?: undefined;
    } | {
        sincronizado: boolean;
        plan: PlanPago;
        pago_id: string;
        transaccion_wompi_id: string;
        motivo?: undefined;
    } | {
        sincronizado: boolean;
        motivo: string;
        pago_id: string;
        plan?: undefined;
        transaccion_wompi_id?: undefined;
    }>;
    private aprobarPago;
    procesarWebhookWompi(eventoRaw: Record<string, unknown>, checksumHeader?: string): Promise<{
        procesado: boolean;
        motivo?: string;
    }>;
    private buscarPagoPendiente;
}
