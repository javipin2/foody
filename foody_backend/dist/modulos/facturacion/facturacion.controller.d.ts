import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { GuardarConfigFiscalDto } from './dto/guardar-config-fiscal.dto';
import { FacturacionService } from './facturacion.service';
export declare class FacturacionController {
    private readonly facturacionService;
    private readonly sucursalScope;
    constructor(facturacionService: FacturacionService, sucursalScope: SucursalScopeService);
    obtenerConfig(sucursalId: string, usuario: JwtPayload): Promise<import("./facturacion.service").ConfigFiscalRow | null>;
    guardarConfig(dto: GuardarConfigFiscalDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    pdf(facturaId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        html: string;
        factura: Record<string, unknown>;
    }>;
    listarFacturas(sucursalId: string, estado: string | undefined, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    emitir(pedidoId: string, usuario: JwtPayload, sucursalId?: string): Promise<Record<string, unknown> | null>;
    anular(facturaId: string, body: {
        motivo: string;
    }, usuario: JwtPayload, sucursalId?: string): Promise<{
        factura_id: string;
        estado: string;
        nota: string;
    }>;
}
