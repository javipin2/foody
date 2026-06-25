import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarMesaDto, CrearMesaDto } from './dto/crear-mesa.dto';
import { TransferirMesaDto } from './dto/transferir-mesa.dto';
import { ReservarMesaDto, SalioSinPagarDto, UnirMesasDto } from './dto/mesa-ops.dto';
import { AsignarTurnoMesasDto } from './dto/asignar-turno-mesas.dto';
import { MesasService } from './mesas.service';
export declare class MesasController {
    private readonly mesasService;
    private readonly sucursalScope;
    constructor(mesasService: MesasService, sucursalScope: SucursalScopeService);
    asignarTurno(dto: AsignarTurnoMesasDto, usuario: JwtPayload): Promise<{
        sucursal_id: string;
        mesas_actualizadas: number;
    }>;
    transferir(dto: TransferirMesaDto, usuario: JwtPayload): Promise<{
        transferencia_id: string;
        pedido_id: string;
        numero_pedido: string;
        mesa_origen_id: string;
        mesa_destino_id: string;
        total_transferencias: number;
        alerta_transferencias_multiples: boolean;
    }>;
    reservar(mesaId: string, dto: ReservarMesaDto, usuario: JwtPayload): Promise<{
        mesa_id: string;
        estado_operativo: string;
    }>;
    cancelarReserva(mesaId: string, sucursalId: string, usuario: JwtPayload): Promise<{
        mesa_id: string;
        estado_operativo: string;
    }>;
    unir(dto: UnirMesasDto, usuario: JwtPayload): Promise<{
        mesa_principal_id: string;
        mesas_unidas: string[];
    }>;
    salioSinPagar(mesaId: string, dto: SalioSinPagarDto, usuario: JwtPayload): Promise<{
        mesa_id: string;
        cuentas_creadas: {
            pedido_id: string;
            monto: number;
        }[];
    }>;
    qr(mesaId: string, sucursalId: string, baseUrl: string | undefined, usuario: JwtPayload): Promise<{
        mesa: {
            id: string;
            nombre: string;
            qr_token: string;
            activa: boolean;
            sucursal_id: string;
        };
        url: string;
        html: string;
    }>;
    listar(sucursalId: string, incluirInactivas: string | undefined, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearMesaDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    actualizar(mesaId: string, sucursalId: string, dto: ActualizarMesaDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | {
        id: string;
        nombre: string;
        qr_token: string;
        activa: boolean;
        sucursal_id: string;
    } | null>;
    desactivar(mesaId: string, sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow | {
        id: string;
        nombre: string;
        qr_token: string;
        activa: boolean;
        sucursal_id: string;
    } | null>;
}
