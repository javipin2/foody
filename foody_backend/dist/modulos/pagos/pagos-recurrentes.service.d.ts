import { DatabaseService } from '../../core/database/database.service';
import { PlanPago } from './pagos-planes.config';
import { WompiService } from './wompi.service';
type FuentePagoRow = {
    id: string;
    restaurante_id: string;
    wompi_payment_source_id: string;
    tipo: string;
    estado_wompi: string | null;
    ultimos_cuatro: string | null;
    marca: string | null;
    customer_email: string | null;
    activa: boolean;
    ultimo_cobro_at: Date | null;
    ultimo_intento_at: Date | null;
};
type SuscripcionRenovacion = {
    restaurante_id: string;
    plan: string;
    estado: string;
    fecha_vencimiento: Date;
    fuente_id: string;
    wompi_payment_source_id: string;
    customer_email: string | null;
};
export declare class PagosRecurrentesService {
    private readonly database;
    private readonly wompi;
    private readonly logger;
    constructor(database: DatabaseService, wompi: WompiService);
    obtenerFuenteActiva(restauranteId: string): Promise<FuentePagoRow | null>;
    resumenFuente(fuente: FuentePagoRow | null): {
        activa: boolean;
        tipo: string;
        ultimos_cuatro: string | null;
        marca: string | null;
        renovacion_automatica: boolean;
        ultimo_cobro_at: Date | null;
    } | null;
    registrarFuenteDesdeTransaccion(restauranteId: string, transaccionId: string, paymentSourceIdDirecto?: string | null): Promise<void>;
    listarCandidatasRenovacionAutomatica(): Promise<SuscripcionRenovacion[]>;
    intentarCobroRenovacion(restauranteId: string, planForzado?: PlanPago): Promise<{
        iniciado: boolean;
        motivo: string;
        pago_id?: string;
        transaccion_wompi_id?: string;
        estado_transaccion?: string;
    }>;
    extenderSuscripcion(restauranteId: string, plan: string): Promise<void>;
    private emailAdminRestaurante;
    private mapearTipoFuente;
}
export {};
