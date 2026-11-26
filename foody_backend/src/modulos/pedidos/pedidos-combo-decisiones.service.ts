import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { CajaMovimientosService } from '../../core/caja/caja-movimientos.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';
import { PedidosInventarioService } from './pedidos-inventario.service';
import { validarLineaSinCobroAsignado } from './pedido-items-cobro.util';

type TipoComponenteCombo = 'producto' | 'bebida' | 'topping';

type SnapshotComponente = {
  tipo_item: TipoComponenteCombo;
  componente_id: string;
  nombre: string;
  cantidad: number;
  precio_unitario: number | null;
  costo_unitario: number;
  cocina_id: string | null;
  producto_padre_id: string | null;
  producto_padre: string | null;
};

type DecisionCombo = {
  decision_id: string | null;
  pedido_id: string;
  pedido_item_id: string;
  tarea_id: string;
  sucursal_id: string;
  estado_decision: string;
  anterior: SnapshotComponente;
  reemplazo: SnapshotComponente | null;
  cotizacion_version: number;
  total_propuesto: string | null;
  diferencia_propuesta: string | null;
  total_aceptado: string | null;
  total_base_cotizacion: string | null;
  respuesta_accion: string | null;
  componente_indice: number;
  cantidad_combo: string;
  stock_descontado: boolean;
  mesa_id: string | null;
  precio_linea: string;
  costo_linea: string;
  tipo_pedido: string;
  estado_pedido: string;
  numero_pedido: string;
  subtotal: string;
  costo_domicilio: string;
  descuento: string;
  total: string;
  monto_pagado: string;
  promocion_id: string | null;
};

type ReemplazoCatalogo = {
  id: string;
  nombre: string;
  precio: string;
  costo_calculado: string | null;
  cocina_id: string | null;
};

@Injectable()
export class PedidosComboDecisionesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly auditoria: AuditoriaService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly inventario: PedidosInventarioService,
    private readonly facturacion: FacturacionService,
    private readonly caja: CajaMovimientosService,
    private readonly estadoCommand: PedidosEstadoCommandService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
  ) {}

  async listarPendientes(pedidoId: string, sucursalId: string) {
    const filas = await this.database.consultar<{
      decision_id: string;
      pedido_id: string;
      pedido_item_id: string;
      tarea_id: string;
      numero_pedido: string;
      estado_pedido: string;
      tipo_pedido: string;
      total_pedido: string;
      monto_pagado: string;
      estado_decision: string;
      motivo_no_disponible: string | null;
      componente_anterior: SnapshotComponente;
      componente_reemplazo: SnapshotComponente | null;
      diferencia_propuesta: string | null;
      total_propuesto: string | null;
      total_base_cotizacion: string | null;
      cotizacion_version: number;
      cantidad_combo: string;
      cocina_id: string;
      producto_padre: string | null;
    }>(
      `SELECT d.id AS decision_id, pi.pedido_id, pi.id AS pedido_item_id,
              t.id AS tarea_id, p.numero_pedido, p.estado AS estado_pedido,
              p.tipo AS tipo_pedido, p.total AS total_pedido,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              d.estado AS estado_decision,
              t.motivo_no_disponible,
              d.componente_anterior_snapshot AS componente_anterior,
              d.componente_reemplazo_snapshot AS componente_reemplazo,
              d.diferencia_propuesta, d.total_propuesto,
              d.total_base_cotizacion,
              d.cotizacion_version,
              pi.cantidad AS cantidad_combo, t.cocina_id,
              t.producto_padre_nombre_snapshot AS producto_padre
       FROM pedido_combo_decisiones_cliente d
       JOIN pedido_items pi ON pi.id = d.pedido_item_id
       JOIN pedidos p ON p.id = pi.pedido_id
       JOIN pedido_combo_tareas_cocina t ON t.id = d.tarea_no_disponible_id
       WHERE p.id = $1 AND p.sucursal_id = $2
         AND d.sucursal_id = $2 AND d.estado = 'pendiente_cliente'
       ORDER BY d.created_at, d.id`,
      [pedidoId, sucursalId],
    );

    const decisiones: Array<Record<string, unknown>> = [];
    for (const fila of filas) {
      const anterior = this.snapshot(fila.componente_anterior);
      const reemplazos =
        anterior.precio_unitario == null
          ? []
          : await this.listarReemplazos(sucursalId, fila.tipo_pedido, anterior);
      decisiones.push({
        decision_id: fila.decision_id,
        pedido_id: fila.pedido_id,
        pedido_item_id: fila.pedido_item_id,
        tarea_id: fila.tarea_id,
        numero_pedido: fila.numero_pedido,
        estado_pedido: fila.estado_pedido,
        estado: fila.estado_decision,
        motivo_no_disponible: fila.motivo_no_disponible,
        componente_anterior: anterior,
        componente_reemplazo: fila.componente_reemplazo,
        diferencia_propuesta:
          fila.diferencia_propuesta == null
            ? null
            : Number(fila.diferencia_propuesta),
        total_propuesto:
          fila.total_propuesto == null ? null : Number(fila.total_propuesto),
        cotizacion_version: Number(fila.cotizacion_version),
        total_pedido: Number(fila.total_pedido),
        monto_pagado: Number(fila.monto_pagado),
        cantidad_combo: Number(fila.cantidad_combo),
        cocina_id: fila.cocina_id,
        producto_padre: fila.producto_padre,
        reemplazos,
        sustitucion_habilitada: anterior.precio_unitario != null,
      });
    }
    return decisiones;
  }

  /** Cancela manualmente una línea combo conservando Caja, KDS y stock snapshot. */
  async cancelarComboManual(
    pedidoId: string,
    pedidoItemId: string,
    sucursalId: string,
    usuarioId: string,
    motivo?: string,
  ) {
    const resultado = await this.database.enTransaccion(async (client) => {
      const filaResult = await client.query<{
        pedido_id: string;
        pedido_item_id: string;
        sucursal_id: string;
        estado_pedido: string;
        tipo_pedido: string;
        numero_pedido: string;
        subtotal: string;
        costo_domicilio: string;
        descuento: string;
        total: string;
        monto_pagado: string;
        promocion_id: string | null;
        mesa_id: string | null;
        stock_descontado: boolean;
        cantidad_combo: string;
        precio_linea: string;
        costo_linea: string | null;
        estado_cobro: string;
        tiene_pago_asociado: boolean;
        tarea_id: string | null;
      }>(
        `SELECT p.id AS pedido_id, pi.id AS pedido_item_id,
                p.sucursal_id, p.estado AS estado_pedido, p.tipo AS tipo_pedido,
                p.numero_pedido, p.subtotal, p.costo_domicilio, p.descuento,
                p.total, COALESCE(p.monto_pagado, 0) AS monto_pagado,
                p.promocion_id, p.mesa_id, p.stock_descontado,
                pi.cantidad AS cantidad_combo, pi.precio_unitario AS precio_linea,
                pi.costo_unitario AS costo_linea, pi.estado_cobro,
                EXISTS (SELECT 1 FROM pago_pedido_items ppi
                        WHERE ppi.pedido_item_id = pi.id) AS tiene_pago_asociado,
                (SELECT t.id FROM pedido_combo_tareas_cocina t
                 WHERE t.pedido_item_id = pi.id ORDER BY t.componente_indice LIMIT 1) AS tarea_id
         FROM pedidos p
         JOIN pedido_items pi ON pi.pedido_id = p.id
         JOIN pedido_combo_selecciones pcs ON pcs.pedido_item_id = pi.id
         WHERE p.id = $1 AND p.sucursal_id = $2 AND pi.id = $3
         FOR UPDATE OF p, pi`,
        [pedidoId, sucursalId, pedidoItemId],
      );
      const fila = filaResult.rows[0];
      if (!fila) {
        throw new NotFoundException('Línea combo no encontrada');
      }
      if (
        ['cancelado', 'rechazado', 'pagado', 'entregado'].includes(
          fila.estado_pedido,
        )
      ) {
        throw new ConflictException({
          error: 'PEDIDO_CERRADO',
          message: 'No se puede cancelar una línea de un pedido cerrado.',
        });
      }
      if (!fila.tarea_id) {
        throw new ConflictException({
          error: 'COMBO_TAREAS_NO_ENCONTRADAS',
          message:
            'No se cancela el combo porque no están sus tareas snapshot por estación.',
        });
      }
      validarLineaSinCobroAsignado(fila.estado_cobro, fila.tiene_pago_asociado);

      const decision: DecisionCombo = {
        decision_id: null,
        pedido_id: fila.pedido_id,
        pedido_item_id: fila.pedido_item_id,
        tarea_id: fila.tarea_id,
        sucursal_id: fila.sucursal_id,
        estado_decision: 'aplicada',
        anterior: {
          tipo_item: 'producto',
          componente_id: pedidoItemId,
          nombre: 'Combo',
          cantidad: 1,
          precio_unitario: null,
          costo_unitario: 0,
          cocina_id: null,
          producto_padre_id: null,
          producto_padre: null,
        },
        reemplazo: null,
        cotizacion_version: 0,
        total_propuesto: null,
        diferencia_propuesta: null,
        total_aceptado: null,
        total_base_cotizacion: null,
        respuesta_accion: 'cancelar_combo',
        componente_indice: 0,
        cantidad_combo: fila.cantidad_combo,
        stock_descontado: fila.stock_descontado,
        mesa_id: fila.mesa_id,
        precio_linea: fila.precio_linea,
        costo_linea: fila.costo_linea ?? '0',
        tipo_pedido: fila.tipo_pedido,
        estado_pedido: fila.estado_pedido,
        numero_pedido: fila.numero_pedido,
        subtotal: fila.subtotal,
        costo_domicilio: fila.costo_domicilio,
        descuento: fila.descuento,
        total: fila.total,
        monto_pagado: fila.monto_pagado,
        promocion_id: fila.promocion_id,
      };
      const motivoFinal = motivo?.trim() || 'Cancelación manual del combo';
      const cancelacion = await this.cancelarComboEnTransaccion(
        client,
        decision,
        usuarioId,
        motivoFinal,
      );
      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'CANCELAR_COMBO_MANUAL',
        tablaAfectada: 'pedido_items',
        registroId: pedidoItemId,
        usuarioId,
        datosAntes: cancelacion,
        datosDespues: {
          pedido_id: pedidoId,
          numero_pedido: fila.numero_pedido,
          motivo: motivoFinal,
          origen: 'eliminacion_manual',
        },
      });
      return {
        pedido_id: pedidoId,
        item_id: pedidoItemId,
        numero_pedido: fila.numero_pedido,
        estado: fila.estado_pedido,
        cancelado: true,
      };
    });

    void this.notificarDecision(pedidoId, sucursalId);
    return resultado;
  }

  async cotizarReemplazo(
    pedidoId: string,
    decisionId: string,
    sucursalId: string,
    reemplazoId: string,
    usuarioId: string,
  ) {
    const result = await this.database.enTransaccion(async (client) => {
      const decision = await this.cargarDecisionBloqueada(
        client,
        pedidoId,
        decisionId,
        sucursalId,
      );
      this.exigirPendiente(decision);
      if (decision.anterior.precio_unitario == null) {
        throw new ConflictException({
          error: 'COMBO_SNAPSHOT_SIN_PRECIO',
          message:
            'Este pedido no tiene un precio histórico confiable para cotizar una sustitución. Solo se puede cancelar el combo.',
        });
      }
      this.exigirPedidoEditable(decision.estado_pedido);

      const reemplazo = await this.obtenerReemplazoDisponible(
        client,
        sucursalId,
        decision.tipo_pedido,
        decision.anterior,
        reemplazoId,
      );
      if (reemplazo.id === decision.anterior.componente_id) {
        throw new BadRequestException({
          error: 'COMBO_REEMPLAZO_IGUAL',
          message: 'Elige un componente diferente al que no está disponible.',
        });
      }

      const precioAnterior = decision.anterior.precio_unitario;
      const cantidad = Number(decision.anterior.cantidad);
      const diferencia = this.redondearMoneda(
        (Number(reemplazo.precio) - precioAnterior) *
          cantidad *
          Number(decision.cantidad_combo),
      );
      const subtotal = Number(decision.subtotal);
      const subtotalNuevo = subtotal + diferencia;
      if (subtotalNuevo < -0.01) {
        throw new ConflictException({
          error: 'COMBO_TOTAL_INVALIDO',
          message:
            'La sustitución no puede dejar el subtotal del pedido negativo.',
        });
      }
      const descuentoNuevo = await this.recalcularDescuento(
        client,
        sucursalId,
        decision.promocion_id,
        Math.max(0, subtotalNuevo),
        Number(decision.descuento),
      );
      const totalPropuesto = this.redondearMoneda(
        Math.max(
          0,
          Math.max(0, subtotalNuevo) +
            Number(decision.costo_domicilio) -
            descuentoNuevo,
        ),
      );
      const version = decision.cotizacion_version + 1;
      const snapshot: SnapshotComponente = {
        tipo_item: decision.anterior.tipo_item,
        componente_id: reemplazo.id,
        nombre: reemplazo.nombre,
        cantidad,
        precio_unitario: Number(reemplazo.precio),
        costo_unitario: Number(reemplazo.costo_calculado ?? 0),
        cocina_id: reemplazo.cocina_id ?? decision.anterior.cocina_id,
        producto_padre_id: decision.anterior.producto_padre_id,
        producto_padre: decision.anterior.producto_padre,
      };
      const diferenciaTotal = this.redondearMoneda(diferencia);

      await client.query(
        `UPDATE pedido_combo_decisiones_cliente
         SET componente_reemplazo_snapshot = $1::jsonb,
             diferencia_propuesta = $2,
             total_propuesto = $3,
             cotizacion_version = $4,
             total_base_cotizacion = $5
         WHERE id = $6 AND estado = 'pendiente_cliente'`,
        [
          JSON.stringify(snapshot),
          diferenciaTotal,
          totalPropuesto,
          version,
          Number(decision.total),
          decisionId,
        ],
      );
      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'COTIZAR_REEMPLAZO_COMBO',
        tablaAfectada: 'pedido_combo_decisiones_cliente',
        registroId: decisionId,
        usuarioId,
        datosAntes: {
          componente_reemplazo: decision.reemplazo,
          total_propuesto: decision.total_propuesto,
        },
        datosDespues: {
          componente_reemplazo: snapshot,
          diferencia_propuesta: diferenciaTotal,
          total_propuesto: totalPropuesto,
          cotizacion_version: version,
        },
      });
      return {
        decision_id: decisionId,
        pedido_id: pedidoId,
        componente_reemplazo: snapshot,
        diferencia_propuesta: diferenciaTotal,
        total_anterior: Number(decision.total),
        total_propuesto: totalPropuesto,
        cotizacion_version: version,
        pago_adicional_estimado: Math.max(
          0,
          this.redondearMoneda(totalPropuesto - Number(decision.monto_pagado)),
        ),
        devolucion_estimada: Math.max(
          0,
          this.redondearMoneda(Number(decision.monto_pagado) - totalPropuesto),
        ),
        aplicado: false,
      };
    });
    await this.notificarDecision(pedidoId, sucursalId);
    return result;
  }

  async responder(
    pedidoId: string,
    decisionId: string,
    sucursalId: string,
    usuarioId: string,
    dto: {
      accion: 'aceptar_sustitucion' | 'cancelar_combo';
      cotizacion_version?: number;
      total_aceptado?: number;
      motivo?: string;
    },
  ) {
    const result = await this.database.enTransaccion(async (client) => {
      const decision = await this.cargarDecisionBloqueada(
        client,
        pedidoId,
        decisionId,
        sucursalId,
      );
      const estadoObjetivo =
        dto.accion === 'aceptar_sustitucion' ? 'aceptada' : 'rechazada';
      if (decision.estado_decision !== 'pendiente_cliente') {
        if (
          decision.estado_decision === 'aplicada' &&
          decision.respuesta_accion === dto.accion &&
          (dto.accion === 'cancelar_combo' ||
            (Number(decision.cotizacion_version) === dto.cotizacion_version &&
              this.mismaMoneda(decision.total_aceptado, dto.total_aceptado)))
        ) {
          return {
            decision_id: decisionId,
            pedido_id: pedidoId,
            estado: decision.estado_decision,
            idempotente: true,
            aplicado: true,
          };
        }
        throw new ConflictException({
          error: 'COMBO_DECISION_YA_RESPONDIDA',
          message: 'Esta decisión ya fue respondida con otra opción.',
        });
      }
      this.exigirPedidoEditable(decision.estado_pedido);

      if (dto.accion === 'aceptar_sustitucion') {
        if (!decision.reemplazo || decision.total_propuesto == null) {
          throw new ConflictException({
            error: 'COMBO_SIN_COTIZACION',
            message: 'Cotiza un reemplazo antes de confirmar el nuevo total.',
          });
        }
        if (dto.cotizacion_version !== decision.cotizacion_version) {
          throw new ConflictException({
            error: 'COMBO_COTIZACION_DESACTUALIZADA',
            message:
              'La cotización cambió. Actualiza el total antes de pedir aprobación.',
          });
        }
        if (!this.mismaMoneda(decision.total_propuesto, dto.total_aceptado)) {
          throw new ConflictException({
            error: 'COMBO_TOTAL_NO_CONFIRMADO',
            message:
              'El total aceptado debe coincidir con la cotización mostrada.',
          });
        }
        if (
          decision.total_base_cotizacion == null ||
          !this.mismaMoneda(
            decision.total_base_cotizacion,
            Number(decision.total),
          )
        ) {
          throw new ConflictException({
            error: 'COMBO_TOTAL_BASE_DESACTUALIZADO',
            message:
              'El total del pedido cambió desde que se cotizó el reemplazo. Cotiza de nuevo antes de pedir aprobación.',
          });
        }
        const candidatoActual = await this.obtenerReemplazoDisponible(
          client,
          sucursalId,
          decision.tipo_pedido,
          decision.anterior,
          decision.reemplazo.componente_id,
        );
        if (
          Number(candidatoActual.precio) !==
          Number(decision.reemplazo.precio_unitario)
        ) {
          throw new ConflictException({
            error: 'COMBO_COTIZACION_PRECIO_CAMBIO',
            message:
              'El precio del reemplazo cambió. Cotiza de nuevo antes de confirmar.',
          });
        }
      } else if (!dto.motivo?.trim()) {
        throw new BadRequestException({
          error: 'COMBO_CANCELACION_MOTIVO',
          message: 'Registra que el cliente rechazó el combo y el motivo.',
        });
      }

      if (dto.accion === 'aceptar_sustitucion') {
        await this.aplicarSustitucionEnTransaccion(
          client,
          decision,
          decision.reemplazo!,
          usuarioId,
        );
      } else {
        await this.cancelarComboEnTransaccion(
          client,
          decision,
          usuarioId,
          dto.motivo!.trim(),
        );
      }

      await client.query(
        `UPDATE pedido_combo_decisiones_cliente
         SET estado = 'aplicada',
             respuesta_accion = $1,
             total_aceptado = $2,
             respuesta_at = now(),
             respuesta_usuario_id = $3,
             aplicada_at = now()
         WHERE id = $4 AND estado = 'pendiente_cliente'`,
        [
          dto.accion,
          dto.accion === 'aceptar_sustitucion'
            ? Number(decision.total_propuesto)
            : null,
          usuarioId,
          decisionId,
        ],
      );
      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion:
          dto.accion === 'aceptar_sustitucion'
            ? 'ACEPTAR_REEMPLAZO_COMBO'
            : 'RECHAZAR_COMBO_NO_DISPONIBLE',
        tablaAfectada: 'pedido_combo_decisiones_cliente',
        registroId: decisionId,
        usuarioId,
        datosAntes: { estado: decision.estado_decision },
        datosDespues: {
          estado: 'aplicada',
          respuesta_accion: dto.accion,
          total_aceptado:
            dto.accion === 'aceptar_sustitucion'
              ? Number(decision.total_propuesto)
              : null,
          motivo: dto.motivo?.trim() || null,
        },
      });
      return {
        decision_id: decisionId,
        pedido_id: pedidoId,
        estado: 'aplicada',
        respuesta_accion: dto.accion,
        total_aceptado:
          dto.accion === 'aceptar_sustitucion'
            ? Number(decision.total_propuesto)
            : null,
        delta_propuesto:
          decision.diferencia_propuesta == null
            ? null
            : Number(decision.diferencia_propuesta),
        aplicado: true,
        idempotente: false,
      };
    });
    if (!result.idempotente) {
      await this.notificarDecision(pedidoId, sucursalId);
    }
    return result;
  }

  private async aplicarSustitucionEnTransaccion(
    client: PoolClient,
    decision: DecisionCombo,
    reemplazo: SnapshotComponente,
    usuarioId: string,
  ) {
    const seleccion = await client.query<{
      componentes_snapshot: unknown;
      precio_combo: string;
    }>(
      `SELECT componentes_snapshot, precio_combo
       FROM pedido_combo_selecciones
       WHERE pedido_item_id = $1
       FOR UPDATE`,
      [decision.pedido_item_id],
    );
    const filaSeleccion = seleccion.rows[0];
    if (!filaSeleccion) {
      throw new ConflictException({
        error: 'COMBO_SNAPSHOT_NO_ENCONTRADO',
        message: 'No se encontró el snapshot del combo para aplicar el cambio.',
      });
    }
    const componentes =
      typeof filaSeleccion.componentes_snapshot === 'string'
        ? JSON.parse(filaSeleccion.componentes_snapshot)
        : filaSeleccion.componentes_snapshot;
    if (
      !Array.isArray(componentes) ||
      !componentes[decision.componente_indice] ||
      (componentes[decision.componente_indice].item_id ??
        componentes[decision.componente_indice].componente_id) !==
        decision.anterior.componente_id
    ) {
      throw new ConflictException({
        error: 'COMBO_SNAPSHOT_CAMBIO',
        message:
          'La composición del combo cambió desde que se reportó el faltante. Revisa el pedido antes de aplicar.',
      });
    }

    const cantidadLinea = Number(decision.cantidad_combo);
    const cantidadComponente =
      Number(decision.anterior.cantidad) * cantidadLinea;
    const precioDeltaUnitario = this.redondearMoneda(
      (Number(reemplazo.precio_unitario) -
        Number(decision.anterior.precio_unitario)) *
        Number(decision.anterior.cantidad),
    );
    const costoDeltaUnitario = this.redondearMoneda(
      (Number(reemplazo.costo_unitario) -
        Number(decision.anterior.costo_unitario)) *
        Number(decision.anterior.cantidad),
    );

    if (decision.stock_descontado) {
      await this.inventario.ajustarStockComponenteCombo(client, {
        sucursalId: decision.sucursal_id,
        pedidoId: decision.pedido_id,
        pedidoItemIdOriginal: decision.pedido_item_id,
        decisionId: decision.decision_id,
        componenteIndice: decision.componente_indice,
        componenteId: decision.anterior.componente_id,
        tipoItem: decision.anterior.tipo_item,
        cantidad: cantidadComponente,
        evento: 'devolucion',
        motivo: 'Devolución del componente rechazado por indisponibilidad',
        usuarioId,
      });
      await this.inventario.ajustarStockComponenteCombo(client, {
        sucursalId: decision.sucursal_id,
        pedidoId: decision.pedido_id,
        pedidoItemIdOriginal: decision.pedido_item_id,
        decisionId: decision.decision_id,
        componenteIndice: decision.componente_indice,
        componenteId: reemplazo.componente_id,
        tipoItem: reemplazo.tipo_item,
        cantidad: cantidadComponente,
        evento: 'consumo',
        motivo: 'Consumo del componente sustituto aprobado por el cliente',
        usuarioId,
      });
    }

    const originalSnapshot = componentes[decision.componente_indice];
    componentes[decision.componente_indice] = {
      ...originalSnapshot,
      tipo_item: reemplazo.tipo_item,
      item_id: reemplazo.componente_id,
      nombre: reemplazo.nombre,
      cantidad: decision.anterior.cantidad,
      precio_unitario: reemplazo.precio_unitario,
      costo_unitario: reemplazo.costo_unitario,
      cocina_id: reemplazo.cocina_id ?? decision.anterior.cocina_id,
    };
    const cocinaId = reemplazo.cocina_id ?? decision.anterior.cocina_id;
    if (!cocinaId) {
      throw new ConflictException({
        error: 'COMBO_REEMPLAZO_SIN_COCINA',
        message:
          'Asigna una cocina al reemplazo antes de enviarlo a preparación.',
      });
    }

    await client.query(
      `UPDATE pedido_combo_selecciones
       SET componentes_snapshot = $1::jsonb,
           precio_combo = CASE WHEN $2 = 'producto'
             THEN GREATEST(0, precio_combo + $3) ELSE precio_combo END
       WHERE pedido_item_id = $4`,
      [
        JSON.stringify(componentes),
        decision.anterior.tipo_item,
        precioDeltaUnitario,
        decision.pedido_item_id,
      ],
    );
    await client.query(
      `UPDATE pedido_combo_tareas_cocina
       SET componente_id = $1,
           nombre_snapshot = $2,
           precio_unitario_snapshot = $3,
           costo_unitario_snapshot = $4,
           cocina_id = $5,
           estado = 'pendiente',
           estado_antes_pausa = NULL,
           motivo_no_disponible = NULL,
           updated_at = now()
       WHERE id = $6 AND pedido_item_id = $7`,
      [
        reemplazo.componente_id,
        reemplazo.nombre,
        reemplazo.precio_unitario,
        reemplazo.costo_unitario,
        cocinaId,
        decision.tarea_id,
        decision.pedido_item_id,
      ],
    );
    await client.query(
      `UPDATE pedido_combo_tareas_cocina
       SET estado = COALESCE(estado_antes_pausa, 'pendiente'),
           estado_antes_pausa = NULL,
           updated_at = now()
       WHERE pedido_item_id = $1 AND estado = 'pausada_decision_cliente'`,
      [decision.pedido_item_id],
    );

    if (decision.anterior.tipo_item === 'topping') {
      const updated = await client.query(
        `WITH objetivo AS (
           SELECT ctid FROM pedido_item_toppings
           WHERE pedido_item_id = $1 AND topping_id = $2
           LIMIT 1 FOR UPDATE
         )
         UPDATE pedido_item_toppings pit
         SET topping_id = $3, nombre_topping = $4, precio_topping = $5
         FROM objetivo WHERE pit.ctid = objetivo.ctid`,
        [
          decision.pedido_item_id,
          decision.anterior.componente_id,
          reemplazo.componente_id,
          reemplazo.nombre,
          reemplazo.precio_unitario,
        ],
      );
      if (updated.rowCount !== 1) {
        throw new ConflictException({
          error: 'COMBO_EXTRA_SNAPSHOT_INCONSISTENTE',
          message:
            'No se encontró el topping original del combo para sustituirlo.',
        });
      }
    } else if (decision.anterior.tipo_item === 'bebida') {
      const updated = await client.query(
        `WITH objetivo AS (
           SELECT ctid FROM pedido_item_bebidas
           WHERE pedido_item_id = $1 AND bebida_id = $2
           ORDER BY ctid LIMIT 1 FOR UPDATE
         )
         UPDATE pedido_item_bebidas pib
         SET bebida_id = $3, nombre_bebida = $4, precio_bebida = $5
         FROM objetivo WHERE pib.ctid = objetivo.ctid`,
        [
          decision.pedido_item_id,
          decision.anterior.componente_id,
          reemplazo.componente_id,
          reemplazo.nombre,
          reemplazo.precio_unitario,
        ],
      );
      if (updated.rowCount !== 1) {
        throw new ConflictException({
          error: 'COMBO_EXTRA_SNAPSHOT_INCONSISTENTE',
          message:
            'No se encontró la bebida original del combo para sustituirla.',
        });
      }
    }

    const deltaPrecioTotal = precioDeltaUnitario * cantidadLinea;
    const deltaCostoTotal = costoDeltaUnitario * cantidadLinea;
    const deltaPrecioEnLinea =
      decision.anterior.tipo_item === 'producto' ? precioDeltaUnitario : 0;
    const nuevoPrecioLinea = Number(decision.precio_linea) + deltaPrecioEnLinea;
    const nuevoCostoLinea = Number(decision.costo_linea) + costoDeltaUnitario;
    await client.query(
      `UPDATE pedido_items
       SET precio_unitario = $1, costo_unitario = $2
       WHERE id = $3 AND pedido_id = $4`,
      [
        nuevoPrecioLinea,
        nuevoCostoLinea,
        decision.pedido_item_id,
        decision.pedido_id,
      ],
    );
    await client.query(
      `UPDATE margenes_venta
       SET precio_venta = precio_venta + $1,
           costo_al_momento = GREATEST(0, costo_al_momento + $2),
           margen_porcentaje = CASE
             WHEN precio_venta + $1 > 0
             THEN ((precio_venta + $1 - GREATEST(0, costo_al_momento + $2)) /
                   (precio_venta + $1)) * 100
             ELSE 0 END
       WHERE pedido_item_id = $3 AND pedido_id = $4 AND sucursal_id = $5`,
      [
        deltaPrecioTotal,
        deltaCostoTotal,
        decision.pedido_item_id,
        decision.pedido_id,
        decision.sucursal_id,
      ],
    );
    const estadoAgregado = await client.query<{ estado: string }>(
      `SELECT CASE
         WHEN BOOL_OR(estado IN ('pendiente','pausada_decision_cliente','no_disponible')) THEN 'pendiente'
         WHEN BOOL_OR(estado = 'preparando') THEN 'preparando'
         ELSE 'listo' END AS estado
       FROM pedido_combo_tareas_cocina WHERE pedido_item_id = $1`,
      [decision.pedido_item_id],
    );
    await client.query(
      `UPDATE pedido_items SET estado_cocina = $1 WHERE id = $2`,
      [estadoAgregado.rows[0]?.estado ?? 'pendiente', decision.pedido_item_id],
    );
    await this.ajustarTotalesPedidoEnTransaccion(
      client,
      decision,
      deltaPrecioTotal,
      usuarioId,
      `Diferencia por sustitución de combo ${decision.numero_pedido}`,
    );
  }

  private async cancelarComboEnTransaccion(
    client: PoolClient,
    decision: DecisionCombo,
    usuarioId: string,
    motivo: string,
  ) {
    const tareas = await client.query<{
      componente_indice: number;
      componente_id: string;
      tipo_item: TipoComponenteCombo;
      cantidad: string;
      estado: string;
      estado_antes_pausa: string | null;
    }>(
      `SELECT componente_indice, componente_id, tipo_item, cantidad,
              estado, estado_antes_pausa
       FROM pedido_combo_tareas_cocina
       WHERE pedido_item_id = $1
       ORDER BY componente_indice
       FOR UPDATE`,
      [decision.pedido_item_id],
    );
    for (const tarea of tareas.rows) {
      const estadoEfectivo =
        tarea.estado === 'pausada_decision_cliente'
          ? (tarea.estado_antes_pausa ?? 'pendiente')
          : tarea.estado;
      const evento =
        estadoEfectivo === 'preparando' || estadoEfectivo === 'listo'
          ? 'merma'
          : 'devolucion';
      if (decision.stock_descontado) {
        await this.inventario.ajustarStockComponenteCombo(client, {
          sucursalId: decision.sucursal_id,
          pedidoId: decision.pedido_id,
          pedidoItemIdOriginal: decision.pedido_item_id,
          decisionId: decision.decision_id,
          componenteIndice: tarea.componente_indice,
          componenteId: tarea.componente_id,
          tipoItem: tarea.tipo_item,
          cantidad: Number(tarea.cantidad) * Number(decision.cantidad_combo),
          evento,
          motivo:
            evento === 'merma'
              ? `Cancelación de combo con preparación iniciada: ${motivo}`
              : `Cancelación de combo antes de preparar: ${motivo}`,
          usuarioId,
        });
      }
    }

    const snapshot = await client.query(
      `SELECT to_jsonb(pi) AS linea,
              (SELECT COALESCE(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
               FROM pedido_item_toppings x WHERE x.pedido_item_id = pi.id) AS toppings,
              (SELECT COALESCE(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
               FROM pedido_item_bebidas x WHERE x.pedido_item_id = pi.id) AS bebidas,
              (SELECT to_jsonb(x) FROM pedido_combo_selecciones x
               WHERE x.pedido_item_id = pi.id) AS combo,
              (SELECT COALESCE(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
               FROM pago_pedido_items x WHERE x.pedido_item_id = pi.id) AS vinculos_pago,
              (SELECT COALESCE(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
               FROM pedido_combo_tareas_cocina x WHERE x.pedido_item_id = pi.id) AS tareas
       FROM pedido_items pi
       WHERE pi.id = $1 AND pi.pedido_id = $2
       FOR UPDATE`,
      [decision.pedido_item_id, decision.pedido_id],
    );
    if (!snapshot.rows[0]) {
      throw new ConflictException({
        error: 'COMBO_LINEA_NO_ENCONTRADA',
        message: 'No se encontró la línea de combo que el cliente rechazó.',
      });
    }
    if (decision.decision_id) {
      await client.query(
        `UPDATE pedido_combo_decisiones_cliente
         SET linea_cancelada_snapshot = $1::jsonb
         WHERE id = $2`,
        [JSON.stringify(snapshot.rows[0]), decision.decision_id],
      );
    }
    await client.query(
      `UPDATE pedido_combo_tareas_cocina SET estado = 'cancelada',
         estado_antes_pausa = NULL, updated_at = now()
       WHERE pedido_item_id = $1`,
      [decision.pedido_item_id],
    );
    await client.query(
      `DELETE FROM pago_pedido_items WHERE pedido_item_id = $1`,
      [decision.pedido_item_id],
    );
    await client.query(
      `DELETE FROM pedido_item_toppings WHERE pedido_item_id = $1`,
      [decision.pedido_item_id],
    );
    await client.query(
      `DELETE FROM pedido_item_bebidas WHERE pedido_item_id = $1`,
      [decision.pedido_item_id],
    );
    await client.query(
      `DELETE FROM pedido_combo_selecciones WHERE pedido_item_id = $1`,
      [decision.pedido_item_id],
    );
    await client.query(`DELETE FROM margenes_venta WHERE pedido_item_id = $1`, [
      decision.pedido_item_id,
    ]);
    await client.query(`DELETE FROM pedido_items WHERE id = $1`, [
      decision.pedido_item_id,
    ]);

    const restantes = await client.query<{ cantidad: string }>(
      `SELECT COUNT(*)::text AS cantidad FROM pedido_items
       WHERE pedido_id = $1`,
      [decision.pedido_id],
    );
    const cancelarPedidoCompleto =
      Number(restantes.rows[0]?.cantidad ?? 0) === 0;
    // Subtract the canceled line's actual stored unit price and extras, preserving
    // order-level payments without guessing a payment allocation by line.
    const linea = (snapshot.rows[0] as { linea: Record<string, unknown> })
      .linea;
    const toppings = (
      snapshot.rows[0] as { toppings: Array<Record<string, unknown>> }
    ).toppings;
    const bebidas = (
      snapshot.rows[0] as { bebidas: Array<Record<string, unknown>> }
    ).bebidas;
    const addons = [
      ...toppings.map((x) => Number(x.precio_topping ?? 0)),
      ...bebidas.map(
        (x) => Number(x.precio_bebida ?? 0) * Number(x.cantidad ?? 1),
      ),
    ].reduce((sum, amount) => sum + amount, 0);
    const importeCancelado =
      (Number(linea.precio_unitario ?? 0) + addons) *
      Number(linea.cantidad ?? 1);
    const deltaSubtotal = -importeCancelado;
    const subtotalNuevo = cancelarPedidoCompleto
      ? 0
      : Math.max(0, Number(decision.subtotal) + deltaSubtotal);
    const domicilioNuevo = cancelarPedidoCompleto
      ? 0
      : Number(decision.costo_domicilio);
    await this.ajustarTotalesPedidoEnTransaccion(
      client,
      decision,
      cancelarPedidoCompleto ? -Number(decision.subtotal) : deltaSubtotal,
      usuarioId,
      `Devolución por combo rechazado ${decision.numero_pedido}`,
      { subtotal: subtotalNuevo, costoDomicilio: domicilioNuevo },
    );
    if (cancelarPedidoCompleto) {
      await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId: decision.pedido_id,
        sucursalId: decision.sucursal_id,
        nuevoEstado: 'cancelado',
        origen: 'sistema',
        usuarioId,
        motivo: `Pedido sin líneas después del rechazo de combo: ${motivo}`,
        estadoAnterior: decision.estado_pedido,
        tipo: decision.tipo_pedido,
      });
      if (decision.mesa_id) {
        await this.cuentaMesa.liberarMesaSiSinPedidosActivos(
          client,
          decision.mesa_id,
          decision.sucursal_id,
        );
      }
    }
    return snapshot.rows[0];
  }

  private async ajustarTotalesPedidoEnTransaccion(
    client: PoolClient,
    decision: DecisionCombo,
    deltaSubtotal: number,
    usuarioId: string,
    descripcion: string,
    reemplazos?: { subtotal: number; costoDomicilio: number },
  ) {
    const subtotal =
      reemplazos?.subtotal ??
      Math.max(0, Number(decision.subtotal) + deltaSubtotal);
    const costoDomicilio =
      reemplazos?.costoDomicilio ?? Number(decision.costo_domicilio);
    const descuento = await this.recalcularDescuento(
      client,
      decision.sucursal_id,
      decision.promocion_id,
      subtotal,
      Number(decision.descuento),
    );
    const total = this.redondearMoneda(
      Math.max(0, subtotal + costoDomicilio - descuento),
    );
    const pagadoAntes = Number(decision.monto_pagado);
    const pagadoNuevo = Math.min(pagadoAntes, total);
    const exceso = this.redondearMoneda(Math.max(0, pagadoAntes - pagadoNuevo));
    if (exceso > 0.01) {
      const cajaId = await this.caja.obtenerCajaAbiertaId(
        client,
        decision.sucursal_id,
      );
      if (!cajaId) {
        throw new BadRequestException({
          error: 'CAJA_NO_ABIERTA',
          message:
            'Abre la caja para registrar la devolución excedente antes de aplicar el cambio del combo.',
        });
      }
      await this.caja.insertar(client, {
        cajaId,
        sucursalId: decision.sucursal_id,
        pedidoId: decision.pedido_id,
        tipo: 'devolucion',
        monto: exceso,
        metodoPago: null,
        descripcion,
        usuarioId,
      });
    }
    const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(
      client,
      decision.sucursal_id,
      total,
    );
    await client.query(
      `UPDATE pedidos SET subtotal = $1, costo_domicilio = $2,
         descuento = $3, total = $4, monto_pagado = $5,
         iva_porcentaje = $6, iva_valor = $7
       WHERE id = $8 AND sucursal_id = $9`,
      [
        subtotal,
        costoDomicilio,
        descuento,
        total,
        pagadoNuevo,
        iva.iva_porcentaje,
        iva.iva_valor,
        decision.pedido_id,
        decision.sucursal_id,
      ],
    );
    await this.facturacion.sincronizarBorradorDesdePedidoEnTransaccion(
      client,
      decision.sucursal_id,
      decision.pedido_id,
    );
  }

  private async cargarDecisionBloqueada(
    client: PoolClient,
    pedidoId: string,
    decisionId: string,
    sucursalId: string,
  ): Promise<DecisionCombo> {
    const result = await client.query<{
      decision_id: string;
      pedido_id: string;
      pedido_item_id: string;
      pedido_item_vigente_id: string | null;
      tarea_id: string;
      tarea_vigente_id: string | null;
      sucursal_id: string;
      estado_decision: string;
      anterior: SnapshotComponente;
      reemplazo: SnapshotComponente | null;
      cotizacion_version: number;
      total_propuesto: string | null;
      diferencia_propuesta: string | null;
      total_aceptado: string | null;
      total_base_cotizacion: string | null;
      respuesta_accion: string | null;
      componente_indice: number;
      cantidad_combo: string;
      stock_descontado: boolean;
      mesa_id: string | null;
      precio_linea: string;
      costo_linea: string;
      tipo_pedido: string;
      estado_pedido: string;
      numero_pedido: string;
      subtotal: string;
      costo_domicilio: string;
      descuento: string;
      total: string;
      monto_pagado: string;
      promocion_id: string | null;
    }>(
      `SELECT d.id AS decision_id, d.pedido_id,
              COALESCE(d.pedido_item_id, d.pedido_item_id_original) AS pedido_item_id,
              pi.id AS pedido_item_vigente_id,
              COALESCE(d.tarea_no_disponible_id, d.tarea_id_original) AS tarea_id,
              t.id AS tarea_vigente_id,
              d.sucursal_id, d.estado AS estado_decision,
              d.componente_anterior_snapshot AS anterior,
              d.componente_reemplazo_snapshot AS reemplazo,
              d.cotizacion_version, d.total_propuesto,
              d.diferencia_propuesta, d.total_aceptado,
              d.total_base_cotizacion,
              d.respuesta_accion,
              t.componente_indice,
              pi.cantidad AS cantidad_combo,
              p.stock_descontado, p.mesa_id,
              pi.precio_unitario AS precio_linea,
              pi.costo_unitario AS costo_linea,
              p.tipo AS tipo_pedido, p.estado AS estado_pedido,
              p.numero_pedido, p.subtotal, p.costo_domicilio,
              p.descuento, p.total,
              COALESCE(p.monto_pagado, 0)::text AS monto_pagado,
              p.promocion_id
       FROM pedido_combo_decisiones_cliente d
       JOIN pedidos p ON p.id = d.pedido_id
       LEFT JOIN pedido_items pi ON pi.id = d.pedido_item_id
       LEFT JOIN pedido_combo_tareas_cocina t ON t.id = d.tarea_no_disponible_id
       WHERE d.id = $1 AND d.pedido_id = $2 AND d.sucursal_id = $3
         AND p.sucursal_id = $3
       FOR UPDATE OF p, d`,
      [decisionId, pedidoId, sucursalId],
    );
    const fila = result.rows[0];
    if (
      !fila ||
      (fila.estado_decision !== 'aplicada' &&
        (!fila.pedido_item_vigente_id || !fila.tarea_vigente_id))
    )
      throw new NotFoundException('Decisión pendiente de combo no encontrada');
    return {
      ...fila,
      anterior: this.snapshot(fila.anterior),
      reemplazo: fila.reemplazo ? this.snapshot(fila.reemplazo) : null,
      cotizacion_version: Number(fila.cotizacion_version),
    };
  }

  private async listarReemplazos(
    sucursalId: string,
    tipoPedido: string,
    anterior: SnapshotComponente,
  ) {
    if (anterior.tipo_item === 'producto') {
      const rows = await this.database.consultar<ReemplazoCatalogo>(
        `SELECT id, nombre,
                CASE WHEN $2 = 'para_llevar' AND precio_para_llevar IS NOT NULL
                     THEN precio_para_llevar ELSE precio END::text AS precio,
                costo_calculado::text AS costo_calculado, cocina_id
         FROM productos
         WHERE sucursal_id = $1 AND disponible = true AND id <> $3
         ORDER BY nombre
         LIMIT 200`,
        [sucursalId, tipoPedido, anterior.componente_id],
      );
      return rows.map((r) => this.mapaCandidato('producto', r));
    }
    if (anterior.tipo_item === 'bebida') {
      const rows = await this.database.consultar<ReemplazoCatalogo>(
        `SELECT b.id, b.nombre, b.precio::text AS precio,
                b.costo_calculado::text AS costo_calculado,
                (SELECT p.cocina_id FROM productos p
                 WHERE p.bebida_origen_id = b.id AND p.sucursal_id = b.sucursal_id
                 ORDER BY p.created_at DESC LIMIT 1) AS cocina_id
         FROM bebidas b
         WHERE b.sucursal_id = $1 AND b.disponible = true AND b.id <> $2
         ORDER BY b.nombre
         LIMIT 200`,
        [sucursalId, anterior.componente_id],
      );
      return rows.map((r) => this.mapaCandidato('bebida', r));
    }
    const rows = await this.database.consultar<ReemplazoCatalogo>(
      `SELECT t.id, t.nombre, t.precio::text AS precio,
              t.costo_calculado::text AS costo_calculado,
              $3::uuid AS cocina_id
       FROM toppings t
       JOIN producto_toppings pt ON pt.topping_id = t.id
       JOIN productos plato ON plato.id = pt.producto_id
       WHERE t.sucursal_id = $1 AND t.disponible = true AND t.id <> $2
         AND plato.sucursal_id = $1
         AND plato.id = $3::uuid
       ORDER BY t.nombre
       LIMIT 200`,
      [sucursalId, anterior.componente_id, anterior.producto_padre_id],
    );
    return rows.map((r) => this.mapaCandidato('topping', r));
  }

  private async obtenerReemplazoDisponible(
    client: PoolClient,
    sucursalId: string,
    tipoPedido: string,
    anterior: SnapshotComponente,
    reemplazoId: string,
  ): Promise<ReemplazoCatalogo> {
    let query: string;
    let values: unknown[];
    if (anterior.tipo_item === 'producto') {
      query = `SELECT id, nombre,
                      CASE WHEN $3 = 'para_llevar' AND precio_para_llevar IS NOT NULL
                           THEN precio_para_llevar ELSE precio END::text AS precio,
                      costo_calculado::text AS costo_calculado, cocina_id
               FROM productos
               WHERE id = $1 AND sucursal_id = $2 AND disponible = true`;
      values = [reemplazoId, sucursalId, tipoPedido];
    } else if (anterior.tipo_item === 'bebida') {
      query = `SELECT b.id, b.nombre, b.precio::text AS precio,
                      b.costo_calculado::text AS costo_calculado,
                      (SELECT p.cocina_id FROM productos p
                       WHERE p.bebida_origen_id = b.id AND p.sucursal_id = b.sucursal_id
                       ORDER BY p.created_at DESC LIMIT 1) AS cocina_id
               FROM bebidas b
               WHERE b.id = $1 AND b.sucursal_id = $2 AND b.disponible = true`;
      values = [reemplazoId, sucursalId];
    } else {
      if (!anterior.producto_padre_id) {
        throw new ConflictException({
          error: 'COMBO_TOPPING_SIN_PLATO',
          message:
            'No se puede sustituir este topping porque el snapshot no identifica el plato asociado.',
        });
      }
      query = `SELECT t.id, t.nombre, t.precio::text AS precio,
                      t.costo_calculado::text AS costo_calculado,
                      $4::uuid AS cocina_id
               FROM toppings t
               JOIN producto_toppings pt ON pt.topping_id = t.id
               JOIN productos plato ON plato.id = pt.producto_id
               WHERE t.id = $1 AND t.sucursal_id = $2 AND t.disponible = true
                 AND plato.sucursal_id = $2 AND plato.id = $3::uuid`;
      values = [
        reemplazoId,
        sucursalId,
        anterior.producto_padre_id,
        anterior.cocina_id,
      ];
    }
    const result = await client.query<ReemplazoCatalogo>(query, values);
    const row = result.rows[0];
    if (!row) {
      throw new ConflictException({
        error: 'COMBO_REEMPLAZO_NO_DISPONIBLE',
        message:
          'El reemplazo ya no está disponible o no pertenece a este establecimiento/plato.',
      });
    }
    return row;
  }

  private async recalcularDescuento(
    client: PoolClient,
    sucursalId: string,
    promocionId: string | null,
    subtotalNuevo: number,
    descuentoActual: number,
  ) {
    if (!promocionId)
      return Math.min(Math.max(0, descuentoActual), subtotalNuevo);
    const result = await client.query<{
      descuento_porcentaje: string | null;
      descuento_monto: string | null;
    }>(
      `SELECT descuento_porcentaje, descuento_monto
       FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`,
      [promocionId, sucursalId],
    );
    const promo = result.rows[0];
    if (!promo) return Math.min(Math.max(0, descuentoActual), subtotalNuevo);
    const porcentaje = Number(promo.descuento_porcentaje ?? 0);
    const monto = Number(promo.descuento_monto ?? 0);
    if (porcentaje > 0)
      return Math.min(
        Math.round((subtotalNuevo * porcentaje) / 100),
        subtotalNuevo,
      );
    if (monto > 0) return Math.min(Math.round(monto), subtotalNuevo);
    return Math.min(Math.max(0, descuentoActual), subtotalNuevo);
  }

  private mapaCandidato(tipo: TipoComponenteCombo, row: ReemplazoCatalogo) {
    return {
      id: row.id,
      tipo_item: tipo,
      nombre: row.nombre,
      precio_unitario: Number(row.precio),
      cocina_id: row.cocina_id,
    };
  }

  private snapshot(raw: SnapshotComponente | string): SnapshotComponente {
    const value = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return {
      tipo_item: value.tipo_item,
      componente_id: value.componente_id ?? value.item_id ?? '',
      nombre: value.nombre ?? '',
      cantidad: Number(value.cantidad ?? 0),
      precio_unitario:
        value.precio_unitario == null ? null : Number(value.precio_unitario),
      costo_unitario: Number(value.costo_unitario ?? 0),
      cocina_id: value.cocina_id ?? null,
      producto_padre_id: value.producto_padre_id ?? null,
      producto_padre:
        value.producto_padre ?? value.producto_padre_nombre_snapshot ?? null,
    };
  }

  private exigirPendiente(decision: DecisionCombo) {
    if (decision.estado_decision !== 'pendiente_cliente') {
      throw new ConflictException({
        error: 'COMBO_DECISION_NO_PENDIENTE',
        message: 'Esta decisión ya no está pendiente de respuesta.',
      });
    }
  }

  private exigirPedidoEditable(estado: string) {
    if (['cancelado', 'rechazado', 'entregado', 'pagado'].includes(estado)) {
      throw new ConflictException({
        error: 'PEDIDO_CERRADO',
        message: 'No se puede decidir sobre un combo de un pedido cerrado.',
      });
    }
  }

  private mismaMoneda(actual: string | number | null, solicitado?: number) {
    return (
      actual != null &&
      solicitado != null &&
      Math.abs(Number(actual) - Number(solicitado)) < 0.01
    );
  }

  private redondearMoneda(valor: number) {
    return Math.round((valor + Number.EPSILON) * 100) / 100;
  }

  private async notificarDecision(pedidoId: string, sucursalId: string) {
    try {
      await this.realtime.pedidoActualizado({
        pedido_id: pedidoId,
        sucursal_id: sucursalId,
      });
    } catch {
      // La respuesta transaccional no debe fallar por un problema de realtime.
    }
  }
}
