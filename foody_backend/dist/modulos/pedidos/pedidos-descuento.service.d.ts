import { DatabaseService } from '../../core/database/database.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosSoporteService } from './pedidos-soporte.service';
export declare class PedidosDescuentoService {
    private readonly database;
    private readonly facturacion;
    private readonly alertasRiesgo;
    private readonly soporte;
    constructor(database: DatabaseService, facturacion: FacturacionService, alertasRiesgo: AlertasRiesgoService, soporte: PedidosSoporteService);
    aplicarDescuento(pedidoId: string, sucursalId: string, usuarioId: string, dto: AplicarDescuentoDto, contexto: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        descuento: number;
        porcentaje: number;
        total: number;
        iva_valor: number;
    }>;
}
