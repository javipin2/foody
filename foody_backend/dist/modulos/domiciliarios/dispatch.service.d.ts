import { OnModuleInit } from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { PedidosDispatchHooksService, ResultadoDispatchAuto } from '../pedidos/pedidos-dispatch-hooks.service';
import { ConfiguracionGlobalService } from '../../core/config/configuracion-global.module';
export declare class DispatchService implements OnModuleInit {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly realtime;
    private readonly notificaciones;
    private readonly pedidosEstadoCommand;
    private readonly pedidosDispatchHooks;
    private readonly configGlobal;
    private readonly logger;
    private expirandoOfertas;
    private readonly LOCK_TICK_EXPIRAR_OFERTAS;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService, notificaciones: NotificacionesService, pedidosEstadoCommand: PedidosEstadoCommandService, pedidosDispatchHooks: PedidosDispatchHooksService, configGlobal: ConfiguracionGlobalService);
    private get radioInicialKm();
    private get radioIncrementoKm();
    private get maxIntentos();
    private get ofertaExpiraSeg();
    validarPedidoParaDespacho(pedidoId: string, sucursalId: string, client?: PoolClient): Promise<{
        valido: true;
        pedido: {
            id: string;
            tipo: string;
            estado: string;
            direccion_entrega: string | null;
            tiene_items: boolean;
            tiene_items_no_disponibles: boolean;
            tiene_items_cocina_pendientes: boolean;
        };
    } | {
        valido: false;
        motivo: string;
        mensaje: string;
    }>;
    private resultadoBloqueado;
    private get comisionFoodyPct();
    onModuleInit(): void;
    private tickExpirarOfertas;
    contarPlantaLibres(sucursalId: string): Promise<number>;
    intentarDispatchAutomatico(pedidoId: string, sucursalId: string): Promise<ResultadoDispatchAuto>;
    private asignarPrimeraPlantaLibre;
    iniciarBusquedaIndependientes(pedidoId: string, sucursalId: string): Promise<{
        iniciado: boolean;
        motivo: string;
        mensaje: string;
    } | {
        iniciado: boolean;
        motivo: string;
        oferta_id: string;
        intento?: undefined;
        mensaje?: undefined;
        radio_km?: undefined;
        expira_en_seg?: undefined;
        domiciliarios_notificados?: undefined;
    } | {
        iniciado: boolean;
        motivo: string;
        intento: number;
        oferta_id?: undefined;
        mensaje?: undefined;
        radio_km?: undefined;
        expira_en_seg?: undefined;
        domiciliarios_notificados?: undefined;
    } | {
        iniciado: boolean;
        motivo: string;
        mensaje: string;
        intento: number;
        radio_km: number;
        expira_en_seg: number;
        oferta_id?: undefined;
        domiciliarios_notificados?: undefined;
    } | {
        iniciado: boolean;
        oferta_id: string;
        intento: number;
        radio_km: number;
        domiciliarios_notificados: number;
        expira_en_seg: number;
        motivo?: undefined;
        mensaje?: undefined;
    }>;
    private buscarIndependientesCercanos;
    private expirarOfertasVencidas;
    private crearAlertaSinDomiciliario;
    distanciaKm(lat1: number, lng1: number, lat2: number, lng2: number): number;
    consultarUnoCliente<T extends QueryResultRow>(client: PoolClient, sql: string, params: unknown[]): Promise<T | null>;
    calcularGanancias(costoDomicilio: number): {
        comision: number;
        ganancia: number;
    };
    private centroCiudadPorSlug;
}
