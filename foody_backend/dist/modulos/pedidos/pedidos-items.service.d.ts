import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { ActualizarItemPedidoDto } from './dto/actualizar-item-pedido.dto';
import { PedidosSoporteService, OpcionesStaffPedido } from './pedidos-soporte.service';
import { PedidosInventarioService } from './pedidos-inventario.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';
export declare class PedidosItemsService {
    private readonly database;
    private readonly facturacion;
    private readonly realtime;
    private readonly alertasRiesgo;
    private readonly costeo;
    private readonly soporte;
    private readonly inventario;
    private readonly auditoria;
    private readonly pedidosEstadoCommand;
    constructor(database: DatabaseService, facturacion: FacturacionService, realtime: RealtimeBroadcastService, alertasRiesgo: AlertasRiesgoService, costeo: CosteoService, soporte: PedidosSoporteService, inventario: PedidosInventarioService, auditoria: AuditoriaService, pedidosEstadoCommand: PedidosEstadoCommandService);
    private recalcularDescuentoTrasCambioSubtotal;
    agregarItems(pedidoId: string, sucursalId: string, dto: AgregarItemsPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        delta_subtotal: number;
        total: number;
        estado: string;
        mesa_id: string | null;
        catalogo_cambios: {
            producto_id: string;
            disponible: boolean;
        }[];
    }>;
    eliminarItemPedido(pedidoId: string, itemId: string, sucursalId: string, usuarioId: string, motivo?: string): Promise<{
        pedido_id: string;
        item_id: string;
        estado: string;
        numero_pedido: string;
        subtotal: number;
        total: number;
        cocina_id: string | null;
        mesa_id: string | null;
    }>;
    actualizarItemPedido(pedidoId: string, itemId: string, sucursalId: string, usuarioId: string, dto: ActualizarItemPedidoDto): Promise<{
        pedido_id: string;
        item_id: string;
        estado: string;
        numero_pedido: string;
        subtotal: number;
        total: number;
        cocina_id: string | null;
        mesa_id: string | null;
        reimprimir: boolean;
    }>;
    actualizarComensalEtiqueta(pedidoId: string, itemId: string, sucursalId: string, comensalEtiqueta: string | null): Promise<{
        item_id: string;
        comensal_etiqueta: string | null;
    }>;
}
