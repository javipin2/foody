import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { ZonasService } from '../zonas/zonas.service';
import { PromocionesService } from '../promociones/promociones.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosSoporteService, OpcionesStaffPedido } from './pedidos-soporte.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
export declare class PedidosCrearService {
    private readonly database;
    private readonly facturacion;
    private readonly zonas;
    private readonly realtime;
    private readonly alertasRiesgo;
    private readonly costeo;
    private readonly promociones;
    private readonly cajaAuditoria;
    private readonly soporte;
    private readonly cuentaMesa;
    private readonly inventario;
    constructor(database: DatabaseService, facturacion: FacturacionService, zonas: ZonasService, realtime: RealtimeBroadcastService, alertasRiesgo: AlertasRiesgoService, costeo: CosteoService, promociones: PromocionesService, cajaAuditoria: PedidosCajaAuditoriaService, soporte: PedidosSoporteService, cuentaMesa: PedidosCuentaMesaService);
    crear(dto: CrearPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        costo_domicilio: number;
        total: number;
        estado: string;
        tiempo_estimado_minutos: number;
        factura_id: string | null;
    } | {
        idempotente: boolean;
    }>;
}
