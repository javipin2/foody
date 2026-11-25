import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import {
  CajaMovimientosService,
  ReversaVentasPedidoResultado,
} from '../../core/caja/caja-movimientos.service';
import { AuditoriaService } from '../auditoria/auditoria.service';

export const METODOS_CON_CAJA = [
  'efectivo',
  'tarjeta',
  'transferencia',
  'nequi',
] as const;

/** Cuenta mesa / pedidos con mesa_id: la venta contable se registra al cobrar. */
export function esPagoDiferidoMesa(
  tipo: string,
  mesaId: string | null | undefined,
): boolean {
  return tipo === 'mesa' || mesaId != null;
}

/**
 * Movimiento de caja y auditoría dentro de la transacción de pedido.
 * Escritura en caja delegada a `CajaMovimientosService` (A-02).
 */
@Injectable()
export class PedidosCajaAuditoriaService {
  constructor(
    private readonly cajaMovimientos: CajaMovimientosService,
    private readonly auditoria: AuditoriaService,
  ) {}

  debeRegistrarVentaAlCrear(
    estadoInicial: string,
    tipo: string,
    mesaId: string | null | undefined,
    metodoPago: string,
  ): boolean {
    if (
      !METODOS_CON_CAJA.includes(
        metodoPago as (typeof METODOS_CON_CAJA)[number],
      )
    ) {
      return false;
    }
    if (estadoInicial === 'pendiente_aprobacion') return false;
    if (esPagoDiferidoMesa(tipo, mesaId)) return false;
    // Domicilio: la venta entra a caja solo al confirmar entrega (o marcar entregado).
    if (tipo === 'domicilio') return false;
    return true;
  }

  obtenerCajaAbiertaId(
    client: PoolClient,
    sucursalId: string,
  ): Promise<string | null> {
    return this.cajaMovimientos.obtenerCajaAbiertaId(client, sucursalId);
  }

  async registrarVentaEnCaja(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    total: number,
    metodoPago: string,
    opciones?: {
      exigirCaja?: boolean;
      descripcion?: string;
      usuarioId?: string;
    },
  ): Promise<boolean> {
    if (
      !METODOS_CON_CAJA.includes(
        metodoPago as (typeof METODOS_CON_CAJA)[number],
      )
    ) {
      return false;
    }

    return this.cajaMovimientos.registrarVentaPedido(
      client,
      {
        sucursalId,
        pedidoId,
        monto: total,
        metodoPago,
        descripcion: opciones?.descripcion ?? 'Venta automática por pedido',
        usuarioId: opciones?.usuarioId ?? null,
      },
      { exigirCaja: opciones?.exigirCaja ?? true },
    );
  }

  revertirVentasPedido(
    client: PoolClient,
    pedidoId: string,
    sucursalId: string,
    usuarioId?: string,
    motivo?: string,
  ): Promise<ReversaVentasPedidoResultado> {
    return this.cajaMovimientos.revertirVentasPedido(
      client,
      pedidoId,
      sucursalId,
      usuarioId,
      motivo,
    );
  }

  async registrarAuditoria(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    datos: Record<string, unknown>,
  ): Promise<void> {
    await this.auditoria.registrarEnTransaccion(client, {
      sucursalId,
      accion: 'CREAR_PEDIDO',
      tablaAfectada: 'pedidos',
      registroId: pedidoId,
      datosDespues: datos,
    });
  }

  async registrarAuditoriaCobroMesa(
    client: PoolClient,
    sucursalId: string,
    mesaId: string,
    usuarioId: string,
    datos: Record<string, unknown>,
  ): Promise<void> {
    await this.auditoria.registrarEnTransaccion(client, {
      sucursalId,
      accion: 'COBRAR_CUENTA_MESA',
      tablaAfectada: 'mesas',
      registroId: mesaId,
      usuarioId,
      datosDespues: datos,
    });
  }
}
