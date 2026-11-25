import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { CobrarMesaDto, PagoLineaDto } from './dto/cobrar-mesa.dto';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
export declare class PedidosPagosService {
    private readonly database;
    private readonly cajaAuditoria;
    private readonly cuentaMesa;
    private readonly realtime;
    constructor(database: DatabaseService, cajaAuditoria: PedidosCajaAuditoriaService, cuentaMesa: PedidosCuentaMesaService, realtime: RealtimeBroadcastService);
    cobrarCuentaMesa(sucursalId: string, mesaId: string, usuarioId: string, dto?: CobrarMesaDto, rol?: string | null): Promise<Record<string, unknown> | {
        mesa_id: string;
        mesa_nombre: string;
        total_cobrado: number;
        propina: number;
        pagos: PagoLineaDto[];
        saldo_restante: number;
        pedidos_cobrados: Array<{
            id: string;
            numero_pedido: string;
        }>;
        parcial: boolean;
    }>;
    cobrarPedidoCaja(sucursalId: string, pedidoId: string, usuarioId: string, dto?: CobrarMesaDto, rol?: string | null): Promise<Record<string, unknown> | {
        pedido_id: string;
        numero_pedido: string;
        total_cobrado: number;
        propina: number;
        pagos: PagoLineaDto[];
        saldo_restante: number;
        parcial: boolean;
        pagado: boolean;
        mesa_id: string | null;
    }>;
    private exigirCocinaCompletaParaPagado;
    private leerCobroIdempotente;
    private leerCobroIdempotenteEnTx;
    private guardarCobroIdempotente;
    private calcularMontoObjetivo;
    private normalizarPagos;
    private saldoPendientePedidos;
    private resolverMesasGrupo;
    private obtenerPedidosActivos;
    private validarItemsSplit;
    private obtenerItemsSplitPorPedido;
    private distribuirPagosPorPedido;
    private calcularMontosItems;
    private validarSaldoItems;
    private distribuirMonto;
    private liberarMesasGrupo;
    private consultarUnoCliente;
}
