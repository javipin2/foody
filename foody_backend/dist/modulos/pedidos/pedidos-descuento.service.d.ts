import { DatabaseService } from '../../core/database/database.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { CajaMovimientosService } from '../../core/caja/caja-movimientos.service';
import { PedidosSoporteService } from './pedidos-soporte.service';
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
export declare class PedidosDescuentoService {
    private readonly database;
    private readonly facturacion;
    private readonly alertasRiesgo;
    private readonly soporte;
    private readonly auditoria;
    private readonly cajaMovimientos;
    private readonly estadoCommand;
    private readonly cuentaMesa;
    constructor(database: DatabaseService, facturacion: FacturacionService, alertasRiesgo: AlertasRiesgoService, soporte: PedidosSoporteService, auditoria: AuditoriaService, cajaMovimientos: CajaMovimientosService, estadoCommand: PedidosEstadoCommandService, cuentaMesa: PedidosCuentaMesaService);
    aplicarDescuento(pedidoId: string, sucursalId: string, usuarioId: string, dto: AplicarDescuentoDto, contexto: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        mesa_id: string | null;
        descuento: number;
        porcentaje: number;
        total: number;
        iva_valor: number;
    }>;
}
