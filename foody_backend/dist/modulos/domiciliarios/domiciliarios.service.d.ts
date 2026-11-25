import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosCajaAuditoriaService } from '../pedidos/pedidos-caja-auditoria.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { PedidosSoporteService } from '../pedidos/pedidos-soporte.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import { UbicacionEntregaDto } from './dto/independiente.dto';
import { DispatchService } from './dispatch.service';
export declare class DomiciliariosService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly realtime;
    private readonly cajaAuditoria;
    private readonly pedidosEstadoCommand;
    private readonly pedidosSoporte;
    private readonly dispatch;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService, cajaAuditoria: PedidosCajaAuditoriaService, pedidosEstadoCommand: PedidosEstadoCommandService, pedidosSoporte: PedidosSoporteService, dispatch: DispatchService);
    listarPlantaDisponibles(sucursalId: string): Promise<QueryResultRow[]>;
    asignarPlanta(dto: AsignarDomiciliarioDto, usuarioAdminId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    reasignarPlanta(dto: AsignarDomiciliarioDto, usuarioAdminId: string): Promise<{
        pedido_id: string;
        estado: string;
        reasignado: boolean;
    }>;
    historialEntregas(usuarioId: string, opts?: {
        desde?: string;
        hasta?: string;
        limite?: number;
    }): Promise<QueryResultRow[]>;
    estadisticasPlanta(usuarioId: string, opts?: {
        desde?: string;
        hasta?: string;
    }): Promise<{
        entregas_hoy: number;
        entregas_semana: number;
        entregas_mes: number;
        entregas_rango: number;
        total_cobrado_rango: number;
        tiempo_promedio_min: number | null;
        saldo_por_liquidar: number;
    }>;
    pedidosAsignados(usuarioId: string): Promise<{
        saldo_pendiente: number;
        requiere_cobro: boolean;
        producto_total: number;
        producto_pendiente: number;
        domicilio_pendiente: number;
        id: string;
        numero_pedido: string;
        tipo: string;
        estado: string;
        cliente_nombre: string | null;
        cliente_telefono: string | null;
        direccion_entrega: string | null;
        lat: string | null;
        lng: string | null;
        subtotal: string;
        costo_domicilio: string;
        total: string;
        monto_pagado: string;
        metodo_pago: string | null;
        created_at: string;
        estado_asignacion: string;
        asignado_at: string;
        permite_fiado_domiciliario: boolean;
        domicilio_ingresa_a_caja: boolean;
    }[]>;
    resumenLiquidacion(sucursalId: string): Promise<{
        permite_fiado_domiciliario: boolean;
        domiciliarios: {
            domiciliario_planta_id: string;
            nombre: string;
            pedidos: number;
            total_pendiente: number;
        }[];
    }>;
    resumenDomicilios(sucursalId: string, desde?: string, hasta?: string): Promise<{
        domicilio_ingresa_a_caja: boolean;
        domiciliarios: {
            domiciliario_planta_id: string;
            nombre: string;
            pedidos_entregados: number;
            total_domicilios: number;
        }[];
    }>;
    liquidarDomiciliario(sucursalId: string, domiciliarioPlantaId: string, usuarioId: string): Promise<{
        domiciliario_planta_id: string;
        liquidados: number;
        total: number;
    }>;
    configurarFiadoDomiciliario(sucursalId: string, permitir: boolean): Promise<{
        sucursal_id: string;
        permite_fiado_domiciliario: boolean;
    }>;
    configurarDomicilioEnCaja(sucursalId: string, ingresa: boolean): Promise<{
        sucursal_id: string;
        domicilio_ingresa_a_caja: boolean;
    }>;
    marcarEnCamino(pedidoId: string, usuarioId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    registrarUbicacionEntrega(usuarioId: string, dto: UbicacionEntregaDto): Promise<{
        ok: boolean;
        registrado: boolean;
        pedido_id?: undefined;
    } | {
        ok: boolean;
        registrado: boolean;
        pedido_id: string;
    }>;
    private registrarCobroEntrega;
    confirmarEntrega(pedidoId: string, usuarioId: string, dto: ConfirmarEntregaDto): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    resumenComisionesIndependientes(sucursalId: string): Promise<QueryResultRow[]>;
    private obtenerPlantaPorUsuario;
    private consultarUno;
}
