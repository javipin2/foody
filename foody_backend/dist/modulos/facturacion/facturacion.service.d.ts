import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { GuardarConfigFiscalDto } from './dto/guardar-config-fiscal.dto';
export interface DesgloseIva {
    subtotal: number;
    iva: number;
    total: number;
}
export interface ConfigFiscalRow {
    id: string;
    sucursal_id: string;
    nit: string | null;
    razon_social: string | null;
    regimen: string;
    aplica_iva: boolean;
    porcentaje_iva: string;
    resolucion_dian: string | null;
    prefijo_factura: string | null;
    consecutivo_actual: number;
}
export declare class FacturacionService {
    private readonly database;
    private readonly auditoria;
    constructor(database: DatabaseService, auditoria: AuditoriaService);
    calcularDesgloseIva(total: number, config: Pick<ConfigFiscalRow, 'aplica_iva' | 'porcentaje_iva'>): DesgloseIva;
    obtenerConfig(sucursalId: string): Promise<ConfigFiscalRow | null>;
    guardarConfig(dto: GuardarConfigFiscalDto): Promise<QueryResultRow | null>;
    listarFacturas(sucursalId: string, estado?: string): Promise<QueryResultRow[]>;
    crearBorradorEnTransaccion(client: PoolClient, params: {
        sucursalId: string;
        pedidoId: string;
        total: number;
        nitCliente: string;
        nombreFiscalCliente: string;
        emailCliente: string;
    }): Promise<string>;
    sincronizarBorradorDesdePedidoEnTransaccion(client: PoolClient, sucursalId: string, pedidoId: string): Promise<boolean>;
    calcularIvaParaPedidoEnTransaccion(client: PoolClient, sucursalId: string, total: number): Promise<{
        iva_porcentaje: number;
        iva_valor: number;
    }>;
    emitir(pedidoId: string, sucursalId: string): Promise<Record<string, unknown> | null>;
    anular(facturaId: string, sucursalId: string, usuarioId: string, motivo: string): Promise<{
        factura_id: string;
        estado: string;
        nota: string;
    }>;
    obtenerPdf(facturaId: string, sucursalId: string): Promise<{
        html: string;
        factura: Record<string, unknown>;
    }>;
    private generarHtmlFactura;
    private consultarConfigCliente;
    private consultarUnoCliente;
    private redondear;
}
