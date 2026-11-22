import { PoolClient } from 'pg';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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

const ESTADOS_PEDIDO_CERRADO = [
  'entregado',
  'cancelado',
  'rechazado',
  'pagado',
] as const;

/** Subdominio: agregar y eliminar ?tems en pedidos abiertos. */
@Injectable()
export class PedidosItemsService {
  constructor(
    private readonly database: DatabaseService,
    private readonly facturacion: FacturacionService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly costeo: CosteoService,
    private readonly soporte: PedidosSoporteService,
    private readonly inventario: PedidosInventarioService,
    private readonly auditoria: AuditoriaService,
    private readonly pedidosEstadoCommand: PedidosEstadoCommandService,
  ) {}

  /**
   * CONS-PROMO-ADD-01: con promo % el descuento debe seguir al subtotal;
   * con monto fijo se acota al subtotal; sin promocion_id se conserva el absoluto.
   */
  private async recalcularDescuentoTrasCambioSubtotal(
    client: PoolClient,
    sucursalId: string,
    promocionId: string | null,
    subtotalNuevo: number,
    descuentoActual: number,
  ): Promise<number> {
    if (!promocionId) {
      return Math.min(Math.max(0, descuentoActual), subtotalNuevo);
    }
    const promo = await client.query<{
      descuento_porcentaje: string | null;
      descuento_monto: string | null;
    }>(
      `SELECT descuento_porcentaje, descuento_monto
       FROM estados_promociones
       WHERE id = $1 AND sucursal_id = $2`,
      [promocionId, sucursalId],
    );
    const fila = promo.rows[0];
    if (!fila) {
      return Math.min(Math.max(0, descuentoActual), subtotalNuevo);
    }
    const pct =
      fila.descuento_porcentaje != null
        ? Number(fila.descuento_porcentaje)
        : 0;
    const fijo =
      fila.descuento_monto != null ? Number(fila.descuento_monto) : 0;
    if (pct > 0) {
      return Math.min(Math.round((subtotalNuevo * pct) / 100), subtotalNuevo);
    }
    if (fijo > 0) {
      return Math.min(Math.round(fijo), subtotalNuevo);
    }
    return Math.min(Math.max(0, descuentoActual), subtotalNuevo);
  }

  async agregarItems(
    pedidoId: string,
    sucursalId: string,
    dto: AgregarItemsPedidoDto,
    opciones: OpcionesStaffPedido = {},
  ) {
    const items = dto.items ?? [];
    const combos = dto.combos ?? [];
    if (!items.length && !combos.length) {
      throw new BadRequestException('Debes incluir al menos un ?tem o combo');
    }

    const resultado = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        numero_pedido: string;
        tipo: string;
        estado: string;
        mesa_id: string | null;
        subtotal: string;
        costo_domicilio: string;
        descuento: string;
        total: string;
        metodo_pago: string | null;
        stock_descontado: boolean;
        promocion_id: string | null;
      }>(
        client,
        `SELECT id, numero_pedido, tipo, estado, mesa_id, subtotal, costo_domicilio,
                descuento, total, metodo_pago, stock_descontado, promocion_id
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (
        (ESTADOS_PEDIDO_CERRADO as readonly string[]).includes(pedido.estado)
      ) {
        throw new ConflictException({
          error: 'PEDIDO_CERRADO',
          message: 'No se pueden agregar ?tems a un pedido cerrado',
        });
      }

      if (
        pedido.mesa_id &&
        opciones.creadoPorStaff &&
        opciones.usuarioId &&
        this.soporte.esRolMesero(opciones.rol)
      ) {
        await this.soporte.assertMeseraPuedeTomarMesa(
          client,
          sucursalId,
          pedido.mesa_id,
          opciones.usuarioId,
        );
      }

      let deltaSubtotal = 0;
      const lineasInventario: {
        productoId: string;
        cantidad: number;
        precioVentaLinea: number;
        nombreProducto?: string;
        extras?: {
          tipo: 'bebida' | 'topping';
          id: string;
          cantidad: number;
        }[];
      }[] = [];
      const lineasPreparadas: {
        productoId: string;
        cantidad: number;
        precioUnitario: number;
        precioVentaLinea: number;
        costoUnitario: number;
        cocinaId: string | null;
        observaciones: string | null;
        toppings: {
          id: string;
          nombre: string;
          precio: number;
          costo: number;
        }[];
        bebidas: {
          id: string;
          nombre: string;
          precio: number;
          cantidad: number;
          costo: number;
        }[];
      }[] = [];
      const combosPreparados: {
        comboId: string;
        nombre: string;
        cantidad: number;
        precioFijo: number;
        productoPrincipalId: string;
        cocinaId: string | null;
        costoUnitario: number;
        productosCombo: { productoId: string; cantidad: number }[];
        toppings: {
          id: string;
          nombre: string;
          precio: number;
          costo: number;
        }[];
        bebidas: {
          id: string;
          nombre: string;
          precio: number;
          cantidad: number;
          costo: number;
        }[];
        extrasUnitario: number;
      }[] = [];

      for (const item of items) {
        const producto = await this.soporte.consultarUnoCliente<{
          id: string;
          nombre: string;
          precio: string;
          precio_para_llevar: string | null;
          disponible: boolean;
          cocina_id: string | null;
          costo_calculado: string | null;
        }>(
          client,
          `SELECT id, nombre, precio, precio_para_llevar, disponible, cocina_id, costo_calculado
           FROM productos WHERE id = $1 AND sucursal_id = $2`,
          [item.producto_id, sucursalId],
        );
        if (!producto?.disponible) {
          throw new BadRequestException('PRODUCTO_NO_DISPONIBLE');
        }
        const precioUnit = this.soporte.precioVentaProducto(producto, pedido.tipo);
        let lineaTotal = precioUnit * item.cantidad;
        const toppings: {
          id: string;
          nombre: string;
          precio: number;
          costo: number;
        }[] = [];
        for (const t of item.toppings ?? []) {
          const top = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
            costo_calculado: string | null;
          }>(
            client,
            `SELECT id, nombre, precio, costo_calculado FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [t.topping_id, sucursalId],
          );
          if (!top) throw new BadRequestException('TOPPING_NO_DISPONIBLE');
          const p = Number(top.precio);
          toppings.push({
            id: top.id,
            nombre: top.nombre,
            precio: p,
            costo: Number(top.costo_calculado ?? 0),
          });
          lineaTotal += p * item.cantidad;
        }
        const bebidas: {
          id: string;
          nombre: string;
          precio: number;
          cantidad: number;
          costo: number;
        }[] = [];
        for (const b of item.bebidas ?? []) {
          const beb = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
            costo_calculado: string | null;
          }>(
            client,
            `SELECT id, nombre, precio, costo_calculado FROM bebidas
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [b.bebida_id, sucursalId],
          );
          if (!beb) throw new BadRequestException('BEBIDA_NO_DISPONIBLE');
          const p = Number(beb.precio);
          bebidas.push({
            id: beb.id,
            nombre: beb.nombre,
            precio: p,
            cantidad: b.cantidad,
            costo: Number(beb.costo_calculado ?? 0),
          });
          lineaTotal += p * b.cantidad;
        }
        deltaSubtotal += lineaTotal;
        const costoExtras =
          toppings.reduce((s, t) => s + t.costo * item.cantidad, 0) +
          bebidas.reduce((s, b) => s + b.costo * b.cantidad, 0);
        const costoProductoUnit = Number(producto.costo_calculado ?? 0);
        const costoUnitarioExtra =
          item.cantidad > 0 ? costoExtras / item.cantidad : 0;
        lineasPreparadas.push({
          productoId: producto.id,
          cantidad: item.cantidad,
          precioUnitario: precioUnit,
          precioVentaLinea: lineaTotal,
          costoUnitario: costoProductoUnit + costoUnitarioExtra,
          cocinaId: producto.cocina_id,
          observaciones: item.observaciones ?? null,
          toppings,
          bebidas,
        });
        lineasInventario.push({
          productoId: producto.id,
          cantidad: item.cantidad,
          precioVentaLinea: lineaTotal,
          nombreProducto: producto.nombre,
          extras: [
            ...toppings.map((t) => ({
              tipo: 'topping' as const,
              id: t.id,
              cantidad: item.cantidad,
            })),
            ...bebidas.map((b) => ({
              tipo: 'bebida' as const,
              id: b.id,
              cantidad: b.cantidad,
            })),
          ],
        });
      }

      for (const comboDto of combos) {
        const combo = await this.soporte.consultarUnoCliente<{
          id: string;
          nombre: string;
          precio_fijo: string;
          disponible: boolean;
        }>(
          client,
          `SELECT id, nombre, precio_fijo, disponible FROM combos
           WHERE id = $1 AND sucursal_id = $2`,
          [comboDto.combo_id, sucursalId],
        );
        if (!combo?.disponible) {
          throw new BadRequestException('COMBO_NO_DISPONIBLE');
        }
        const precioFijo = Number(combo.precio_fijo);
        const comboItems = await client.query<{
          tipo_item: string;
          item_id: string;
          cantidad: number;
        }>(
          `SELECT tipo_item, item_id, cantidad FROM combo_items WHERE combo_id = $1`,
          [combo.id],
        );
        const productoItem = comboItems.rows.find(
          (ci) => ci.tipo_item === 'producto',
        );
        if (!productoItem) {
          throw new BadRequestException('COMBO_SIN_PRODUCTO');
        }
        const producto = await this.soporte.consultarUnoCliente<{
          id: string;
          cocina_id: string | null;
          costo_calculado: string | null;
        }>(
          client,
          `SELECT id, cocina_id, costo_calculado FROM productos
           WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
          [productoItem.item_id, sucursalId],
        );
        if (!producto) {
          throw new BadRequestException('PRODUCTO_NO_DISPONIBLE');
        }
        const productosCombo = comboItems.rows
          .filter((ci) => ci.tipo_item === 'producto')
          .map((ci) => ({ productoId: ci.item_id, cantidad: ci.cantidad }));

        const toppings: {
          id: string;
          nombre: string;
          precio: number;
          costo: number;
        }[] = [];
        for (const t of comboDto.toppings ?? []) {
          const top = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
            costo_calculado: string | null;
          }>(
            client,
            `SELECT id, nombre, precio, costo_calculado FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [t.topping_id, sucursalId],
          );
          if (!top) throw new BadRequestException('TOPPING_NO_DISPONIBLE');
          toppings.push({
            id: top.id,
            nombre: top.nombre,
            precio: Number(top.precio),
            costo: Number(top.costo_calculado ?? 0),
          });
        }
        const bebidas: {
          id: string;
          nombre: string;
          precio: number;
          cantidad: number;
          costo: number;
        }[] = [];
        for (const b of comboDto.bebidas ?? []) {
          const beb = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
            costo_calculado: string | null;
          }>(
            client,
            `SELECT id, nombre, precio, costo_calculado FROM bebidas
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [b.bebida_id, sucursalId],
          );
          if (!beb) throw new BadRequestException('BEBIDA_NO_DISPONIBLE');
          bebidas.push({
            id: beb.id,
            nombre: beb.nombre,
            precio: Number(beb.precio),
            cantidad: b.cantidad,
            costo: Number(beb.costo_calculado ?? 0),
          });
        }
        const extrasUnitario =
          toppings.reduce((s, t) => s + t.precio, 0) +
          bebidas.reduce((s, b) => s + b.precio * b.cantidad, 0);

        deltaSubtotal += (precioFijo + extrasUnitario) * comboDto.cantidad;
        combosPreparados.push({
          comboId: combo.id,
          nombre: combo.nombre,
          cantidad: comboDto.cantidad,
          precioFijo,
          productoPrincipalId: producto.id,
          cocinaId: producto.cocina_id,
          costoUnitario: 0,
          productosCombo,
          toppings,
          bebidas,
          extrasUnitario,
        });
        for (const pc of productosCombo) {
          lineasInventario.push({
            productoId: pc.productoId,
            cantidad: pc.cantidad * comboDto.cantidad,
            precioVentaLinea: 1,
          });
        }
      }

      const opcionesStock = { incluirEmpaques: pedido.tipo === 'domicilio' };
      await this.inventario.validarStockDisponible(
        client,
        sucursalId,
        lineasInventario,
        opcionesStock,
        { origen: opciones.creadoPorStaff ? 'staff' : 'mesa' },
      );

      let costosRecalculados = new Map<string, number>();
      const catalogoCambios: { producto_id: string; disponible: boolean }[] =
        [];
      if (pedido.stock_descontado) {
        const stock = await this.inventario.descontarStockPedido(
          client,
          sucursalId,
          pedidoId,
          lineasInventario,
          opcionesStock,
        );
        costosRecalculados = stock.costos;
        catalogoCambios.push(...stock.catalogo);
      } else {
        for (const l of lineasPreparadas) {
          costosRecalculados.set(l.productoId, l.costoUnitario);
        }
      }

      for (const combo of combosPreparados) {
        let costoUnit = 0;
        for (const pc of combo.productosCombo) {
          const unit = costosRecalculados.get(pc.productoId) ?? 0;
          costoUnit += unit * pc.cantidad;
        }
        combo.costoUnitario = costoUnit;
      }

      for (const linea of lineasPreparadas) {
        const costoUnit =
          costosRecalculados.get(linea.productoId) ?? linea.costoUnitario;
        const itemRes = await client.query<{ id: string }>(
          `INSERT INTO pedido_items (
             pedido_id, producto_id, cocina_id, cantidad, precio_unitario,
             costo_unitario, observaciones
           ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
          [
            pedidoId,
            linea.productoId,
            linea.cocinaId,
            linea.cantidad,
            linea.precioUnitario,
            costoUnit,
            linea.observaciones,
          ],
        );
        const itemId = itemRes.rows[0].id;
        const precioVenta = linea.precioVentaLinea;
        const costoTotal = costoUnit * linea.cantidad;
        const margenPct =
          precioVenta > 0
            ? ((precioVenta - costoTotal) / precioVenta) * 100
            : 0;
        await client.query(
          `INSERT INTO margenes_venta (
             pedido_id, pedido_item_id, sucursal_id,
             precio_venta, costo_al_momento, margen_porcentaje
           ) VALUES ($1,$2,$3,$4,$5,$6)`,
          [
            pedidoId,
            itemId,
            sucursalId,
            precioVenta,
            costoTotal,
            margenPct,
          ],
        );
        for (const t of linea.toppings) {
          await client.query(
            `INSERT INTO pedido_item_toppings (pedido_item_id, topping_id, nombre_topping, precio_topping)
             VALUES ($1,$2,$3,$4)`,
            [itemId, t.id, t.nombre, t.precio],
          );
        }
        for (const b of linea.bebidas) {
          await client.query(
            `INSERT INTO pedido_item_bebidas (pedido_item_id, bebida_id, nombre_bebida, precio_bebida, cantidad)
             VALUES ($1,$2,$3,$4,$5)`,
            [itemId, b.id, b.nombre, b.precio, b.cantidad],
          );
        }
      }

      for (const combo of combosPreparados) {
        for (let u = 0; u < combo.cantidad; u++) {
          const costoExtras =
            combo.toppings.reduce((s, t) => s + t.costo, 0) +
            combo.bebidas.reduce((s, b) => s + b.costo * b.cantidad, 0);
          const costoUnit = combo.costoUnitario + costoExtras;
          const precioVenta = combo.precioFijo + combo.extrasUnitario;
          const itemRes = await client.query<{ id: string }>(
            `INSERT INTO pedido_items (
               pedido_id, producto_id, cocina_id, cantidad, precio_unitario,
               costo_unitario, observaciones
             ) VALUES ($1,$2,$3,1,$4,$5,$6) RETURNING id`,
            [
              pedidoId,
              combo.productoPrincipalId,
              combo.cocinaId,
              combo.precioFijo,
              costoUnit,
              `Combo: ${combo.nombre}`,
            ],
          );
          const itemId = itemRes.rows[0].id;
          await client.query(
            `INSERT INTO pedido_combo_selecciones (
               pedido_item_id, combo_id, nombre_combo, precio_combo
             ) VALUES ($1,$2,$3,$4)`,
            [itemId, combo.comboId, combo.nombre, combo.precioFijo],
          );
          for (const t of combo.toppings) {
            await client.query(
              `INSERT INTO pedido_item_toppings (pedido_item_id, topping_id, nombre_topping, precio_topping)
               VALUES ($1,$2,$3,$4)`,
              [itemId, t.id, t.nombre, t.precio],
            );
          }
          for (const b of combo.bebidas) {
            await client.query(
              `INSERT INTO pedido_item_bebidas (pedido_item_id, bebida_id, nombre_bebida, precio_bebida, cantidad)
               VALUES ($1,$2,$3,$4,$5)`,
              [itemId, b.id, b.nombre, b.precio, b.cantidad],
            );
          }
          const margenPct =
            precioVenta > 0
              ? ((precioVenta - costoUnit) / precioVenta) * 100
              : 0;
          await client.query(
            `INSERT INTO margenes_venta (
               pedido_id, pedido_item_id, sucursal_id,
               precio_venta, costo_al_momento, margen_porcentaje
             ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [
              pedidoId,
              itemId,
              sucursalId,
              precioVenta,
              costoUnit,
              margenPct,
            ],
          );
        }
      }

      const subtotalAnterior = Number(pedido.subtotal);
      const subtotalNuevo = subtotalAnterior + deltaSubtotal;
      const costoDomicilio = Number(pedido.costo_domicilio);
      // CONS-PROMO-ADD-01: si hay promo %, recalcular sobre el nuevo subtotal.
      let descuento = await this.recalcularDescuentoTrasCambioSubtotal(
        client,
        sucursalId,
        pedido.promocion_id,
        subtotalNuevo,
        Number(pedido.descuento),
      );
      const totalNuevo = Math.max(0, subtotalNuevo + costoDomicilio - descuento);
      const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(
        client,
        sucursalId,
        totalNuevo,
      );

      await client.query(
        `UPDATE pedidos SET
           subtotal = $1, descuento = $2, total = $3,
           iva_porcentaje = $4, iva_valor = $5
         WHERE id = $6`,
        [
          subtotalNuevo,
          descuento,
          totalNuevo,
          iva.iva_porcentaje,
          iva.iva_valor,
          pedidoId,
        ],
      );

      await this.facturacion.sincronizarBorradorDesdePedidoEnTransaccion(
        client,
        sucursalId,
        pedidoId,
      );

      // VIE-01: ítems nuevos tras listo/pagando vuelven el pedido a cocina
      let estadoFinal = pedido.estado;
      if (['listo', 'pagando'].includes(pedido.estado)) {
        await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
          pedidoId,
          sucursalId,
          nuevoEstado: 'en_cocina',
          origen: 'sistema',
          usuarioId: opciones.usuarioId ?? null,
          motivo: 'Ítems agregados — vuelve a cocina',
          estadoAnterior: pedido.estado,
          tipo: pedido.tipo,
        });
        estadoFinal = 'en_cocina';
      }

      return {
        pedido_id: pedidoId,
        numero_pedido: pedido.numero_pedido,
        subtotal: subtotalNuevo,
        delta_subtotal: deltaSubtotal,
        total: totalNuevo,
        estado: estadoFinal,
        mesa_id: pedido.mesa_id,
        catalogo_cambios: catalogoCambios,
      };
    });

    this.soporte.notificarPedidoRealtime(
      sucursalId,
      resultado.pedido_id,
      resultado.estado,
      resultado.numero_pedido,
    );
    this.soporte.notificarCatalogoDisponibilidad(
      sucursalId,
      resultado.catalogo_cambios ?? [],
    );
    if (resultado.mesa_id) {
      void this.realtime.mesasActualizadas(sucursalId);
    }
    void this.soporte.notificarCocinasPorPedido(resultado.pedido_id, sucursalId);
    return resultado;
  }

  async eliminarItemPedido(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    usuarioId: string,
    motivo?: string,
  ) {
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        tipo: string;
        mesa_id: string | null;
        stock_descontado: boolean;
        subtotal: string;
        costo_domicilio: string;
        descuento: string;
        numero_pedido: string;
        promocion_id: string | null;
      }>(
        client,
        `SELECT id, estado, tipo, mesa_id, stock_descontado,
                subtotal, costo_domicilio, descuento, numero_pedido, promocion_id
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (
        (ESTADOS_PEDIDO_CERRADO as readonly string[]).includes(pedido.estado)
      ) {
        throw new ConflictException({
          error: 'PEDIDO_CERRADO',
          message: 'No se pueden eliminar ?tems de un pedido cerrado',
        });
      }

      const item = await this.soporte.consultarUnoCliente<{
        id: string;
        producto_id: string;
        cantidad: number;
        precio_unitario: string;
        estado_cocina: string;
        cocina_id: string | null;
        nombre_producto: string;
      }>(
        client,
        `SELECT pi.id, pi.producto_id, pi.cantidad, pi.precio_unitario,
                pi.estado_cocina, pi.cocina_id, pr.nombre AS nombre_producto
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         WHERE pi.id = $1 AND pi.pedido_id = $2`,
        [itemId, pedidoId],
      );
      if (!item) throw new NotFoundException('?tem de pedido no encontrado');

      const conteoItems = await client.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM pedido_items WHERE pedido_id = $1`,
        [pedidoId],
      );
      if (Number(conteoItems.rows[0]?.n ?? 0) <= 1) {
        throw new BadRequestException({
          error: 'PEDIDO_SIN_ITEMS',
          message:
            'No puedes eliminar el ?ltimo ?tem. Cancela el pedido completo.',
        });
      }

      const enCocina = ['preparando', 'listo'].includes(item.estado_cocina);
      if (enCocina) {
        await this.alertasRiesgo.registrarEnTransaccion(client, {
          sucursalId,
          tipo: 'item_eliminado_post_cocina',
          nivel: 'alto',
          descripcion: `${pedido.numero_pedido}: se elimin? ?${item.nombre_producto}? (estado cocina: ${item.estado_cocina}). Motivo: ${motivo?.trim() || 'Sin motivo'}`,
          referenciaId: itemId,
          referenciaTipo: 'pedido_item',
        });
      }

      if (pedido.stock_descontado) {
        if (enCocina) {
          await this.inventario.registrarMermaLineaProducto(
            client,
            sucursalId,
            pedidoId,
            item.producto_id,
            item.cantidad,
            motivo ?? `?tem eliminado en cocina (${item.estado_cocina})`,
          );
        } else {
          await this.inventario.restaurarStockLineaProducto(
            client,
            sucursalId,
            pedidoId,
            item.producto_id,
            item.cantidad,
            { incluirEmpaques: pedido.tipo === 'domicilio' },
          );
        }
      }

      const lineaRow = await client.query<{ linea: string }>(
        `SELECT (
           pi.cantidad * pi.precio_unitario
           + COALESCE((
               SELECT SUM(pit.precio_topping)
               FROM pedido_item_toppings pit WHERE pit.pedido_item_id = pi.id
             ), 0) * pi.cantidad
           + COALESCE((
               SELECT SUM(pib.precio_bebida * pib.cantidad)
               FROM pedido_item_bebidas pib WHERE pib.pedido_item_id = pi.id
             ), 0)
         )::text AS linea
         FROM pedido_items pi WHERE pi.id = $1`,
        [itemId],
      );
      const lineaTotal = Number(lineaRow.rows[0]?.linea ?? 0);
      await client.query(
        `DELETE FROM pedido_item_toppings WHERE pedido_item_id = $1`,
        [itemId],
      );
      await client.query(
        `DELETE FROM pedido_item_bebidas WHERE pedido_item_id = $1`,
        [itemId],
      );
      await client.query(
        `DELETE FROM pedido_combo_selecciones WHERE pedido_item_id = $1`,
        [itemId],
      );
      await client.query(
        `DELETE FROM margenes_venta WHERE pedido_item_id = $1`,
        [itemId],
      );
      await client.query(
        `DELETE FROM pago_pedido_items WHERE pedido_item_id = $1`,
        [itemId],
      );
      await client.query(`DELETE FROM pedido_items WHERE id = $1`, [itemId]);

      const subtotalNuevo = Math.max(0, Number(pedido.subtotal) - lineaTotal);
      const descuento = await this.recalcularDescuentoTrasCambioSubtotal(
        client,
        sucursalId,
        pedido.promocion_id,
        subtotalNuevo,
        Number(pedido.descuento),
      );
      const totalNuevo = Math.max(
        0,
        subtotalNuevo + Number(pedido.costo_domicilio) - descuento,
      );
      const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(
        client,
        sucursalId,
        totalNuevo,
      );

      await client.query(
        `UPDATE pedidos SET
           subtotal = $1, descuento = $2, total = $3,
           iva_porcentaje = $4, iva_valor = $5
         WHERE id = $6`,
        [
          subtotalNuevo,
          descuento,
          totalNuevo,
          iva.iva_porcentaje,
          iva.iva_valor,
          pedidoId,
        ],
      );

      await this.facturacion.sincronizarBorradorDesdePedidoEnTransaccion(
        client,
        sucursalId,
        pedidoId,
      );

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'ELIMINAR_ITEM_PEDIDO',
        tablaAfectada: 'pedido_items',
        registroId: itemId,
        usuarioId,
        datosDespues: {
          pedido_id: pedidoId,
          numero_pedido: pedido.numero_pedido,
          producto: item.nombre_producto,
          estado_cocina: item.estado_cocina,
          motivo: motivo?.trim() || null,
        },
      });

      return {
        pedido_id: pedidoId,
        item_id: itemId,
        estado: pedido.estado,
        numero_pedido: pedido.numero_pedido,
        subtotal: subtotalNuevo,
        total: totalNuevo,
        cocina_id: item.cocina_id,
        mesa_id: pedido.mesa_id,
      };
    });

    this.soporte.notificarPedidoRealtime(
      sucursalId,
      result.pedido_id,
      result.estado,
      result.numero_pedido,
    );
    if (result.cocina_id) {
      void this.realtime.cocinaActualizada(result.cocina_id, {
        pedido_id: result.pedido_id,
        sucursal_id: sucursalId,
        accion: 'item_eliminado',
      });
    }
    if (result.mesa_id) {
      void this.realtime.mesasActualizadas(sucursalId);
    }
    void this.soporte.notificarCocinasPorPedido(result.pedido_id, sucursalId);
    return result;
  }

  /**
   * Edita cantidad / nota / toppings de una línea (totales y stock en backend).
   * Reimprime comanda (Copia N) si el pedido ya está en cocina o se altera la línea.
   */
  async actualizarItemPedido(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    usuarioId: string,
    dto: ActualizarItemPedidoDto,
  ) {
    if (
      dto.cantidad === undefined &&
      dto.observaciones === undefined &&
      dto.toppings === undefined
    ) {
      throw new BadRequestException('Nada que actualizar');
    }

    const resultado = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        tipo: string;
        mesa_id: string | null;
        stock_descontado: boolean;
        costo_domicilio: string;
        descuento: string;
        numero_pedido: string;
        promocion_id: string | null;
      }>(
        client,
        `SELECT id, estado, tipo, mesa_id, stock_descontado,
                costo_domicilio, descuento, numero_pedido, promocion_id
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
      if (
        (ESTADOS_PEDIDO_CERRADO as readonly string[]).includes(pedido.estado)
      ) {
        throw new ConflictException({
          error: 'PEDIDO_CERRADO',
          message: 'No se pueden editar ítems de un pedido cerrado',
        });
      }

      const item = await this.soporte.consultarUnoCliente<{
        id: string;
        producto_id: string;
        cantidad: number;
        precio_unitario: string;
        costo_unitario: string | null;
        estado_cocina: string;
        cocina_id: string | null;
        observaciones: string | null;
        nombre_producto: string;
      }>(
        client,
        `SELECT pi.id, pi.producto_id, pi.cantidad, pi.precio_unitario,
                pi.costo_unitario, pi.estado_cocina, pi.cocina_id, pi.observaciones,
                pr.nombre AS nombre_producto
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         WHERE pi.id = $1 AND pi.pedido_id = $2`,
        [itemId, pedidoId],
      );
      if (!item) throw new NotFoundException('Ítem de pedido no encontrado');

      const cantidadNueva = dto.cantidad ?? item.cantidad;
      const obsNueva =
        dto.observaciones !== undefined
          ? dto.observaciones?.trim() || null
          : item.observaciones;

      let toppingsNuevos: {
        id: string;
        nombre: string;
        precio: number;
        costo: number;
      }[] | null = null;

      if (dto.toppings !== undefined) {
        toppingsNuevos = [];
        for (const t of dto.toppings) {
          const top = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
            costo_calculado: string | null;
          }>(
            client,
            `SELECT id, nombre, precio, costo_calculado FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [t.topping_id, sucursalId],
          );
          if (!top) throw new BadRequestException('TOPPING_NO_DISPONIBLE');
          toppingsNuevos.push({
            id: top.id,
            nombre: top.nombre,
            precio: Number(top.precio),
            costo: Number(top.costo_calculado ?? 0),
          });
        }
      }

      const deltaQty = cantidadNueva - item.cantidad;
      const cambiaCocina =
        deltaQty !== 0 || dto.toppings !== undefined;

      // VIE-QTY-01 C: no bajar qty si ya en cocina (solo DELETE + motivo)
      if (
        deltaQty < 0 &&
        ['preparando', 'listo'].includes(item.estado_cocina)
      ) {
        throw new BadRequestException({
          error: 'CANTIDAD_COCINA_INMUTABLE',
          message:
            'No se puede bajar la cantidad de un ítem en preparación o listo. Elimínalo con motivo (merma).',
        });
      }

      if (pedido.stock_descontado && deltaQty !== 0) {
        if (deltaQty > 0) {
          const extras =
            toppingsNuevos?.map((t) => ({
              tipo: 'topping' as const,
              id: t.id,
              cantidad: deltaQty,
            })) ??
            (
              await client.query<{ topping_id: string }>(
                `SELECT topping_id FROM pedido_item_toppings WHERE pedido_item_id = $1`,
                [itemId],
              )
            ).rows.map((r) => ({
              tipo: 'topping' as const,
              id: r.topping_id,
              cantidad: deltaQty,
            }));
          await this.inventario.descontarStockPedido(
            client,
            sucursalId,
            pedidoId,
            [
              {
                productoId: item.producto_id,
                cantidad: deltaQty,
                precioVentaLinea:
                  Number(item.precio_unitario) * deltaQty,
                nombreProducto: item.nombre_producto,
                extras,
              },
            ],
            { incluirEmpaques: pedido.tipo === 'domicilio' },
          );
        } else {
          await this.inventario.restaurarStockLineaProducto(
            client,
            sucursalId,
            pedidoId,
            item.producto_id,
            Math.abs(deltaQty),
            { incluirEmpaques: pedido.tipo === 'domicilio' },
          );
        }
      }

      const estadoCocinaNuevo = cambiaCocina
        ? 'pendiente'
        : item.estado_cocina;

      await client.query(
        `UPDATE pedido_items SET
           cantidad = $1,
           observaciones = $2,
           estado_cocina = $3
         WHERE id = $4`,
        [cantidadNueva, obsNueva, estadoCocinaNuevo, itemId],
      );

      if (toppingsNuevos !== null) {
        await client.query(
          `DELETE FROM pedido_item_toppings WHERE pedido_item_id = $1`,
          [itemId],
        );
        for (const t of toppingsNuevos) {
          await client.query(
            `INSERT INTO pedido_item_toppings
               (pedido_item_id, topping_id, nombre_topping, precio_topping)
             VALUES ($1,$2,$3,$4)`,
            [itemId, t.id, t.nombre, t.precio],
          );
        }
      }

      const productoCosto = await this.soporte.consultarUnoCliente<{
        costo_calculado: string | null;
      }>(
        client,
        `SELECT costo_calculado FROM productos WHERE id = $1`,
        [item.producto_id],
      );
      const topsCosto = await client.query<{ s: string }>(
        `SELECT COALESCE(SUM(t.costo_calculado), 0)::text AS s
         FROM pedido_item_toppings pit
         INNER JOIN toppings t ON t.id = pit.topping_id
         WHERE pit.pedido_item_id = $1`,
        [itemId],
      );
      const costoUnit =
        Number(productoCosto?.costo_calculado ?? 0) +
        Number(topsCosto.rows[0]?.s ?? 0);
      await client.query(
        `UPDATE pedido_items SET costo_unitario = $1 WHERE id = $2`,
        [costoUnit, itemId],
      );

      // CONS-MARGEN-STALE-01 / CONS-COSTO-SNAPSHOT: ledger alineado al snapshot de línea.
      const precioLineaRow = await client.query<{ precio: string }>(
        `SELECT (
           $1::numeric * pi.precio_unitario
           + COALESCE((
               SELECT SUM(pit.precio_topping) FROM pedido_item_toppings pit
               WHERE pit.pedido_item_id = pi.id
             ), 0) * $1::numeric
           + COALESCE((
               SELECT SUM(pib.precio_bebida * pib.cantidad)
               FROM pedido_item_bebidas pib
               WHERE pib.pedido_item_id = pi.id
             ), 0)
         )::text AS precio
         FROM pedido_items pi WHERE pi.id = $2`,
        [cantidadNueva, itemId],
      );
      const precioVenta = Number(precioLineaRow.rows[0]?.precio ?? 0);
      const costoTotal = costoUnit * cantidadNueva;
      const margenPct =
        precioVenta > 0
          ? ((precioVenta - costoTotal) / precioVenta) * 100
          : 0;
      await client.query(
        `UPDATE margenes_venta
         SET precio_venta = $1,
             costo_al_momento = $2,
             margen_porcentaje = $3
         WHERE pedido_item_id = $4`,
        [precioVenta, costoTotal, margenPct, itemId],
      );

      const subtotalRow = await client.query<{ subtotal: string }>(
        `SELECT COALESCE(SUM(
           pi.cantidad * pi.precio_unitario
           + COALESCE((
               SELECT SUM(pit.precio_topping)
               FROM pedido_item_toppings pit
               WHERE pit.pedido_item_id = pi.id
             ), 0) * pi.cantidad
           + COALESCE((
               SELECT SUM(pib.precio_bebida * pib.cantidad)
               FROM pedido_item_bebidas pib
               WHERE pib.pedido_item_id = pi.id
             ), 0)
         ), 0) AS subtotal
         FROM pedido_items pi
         WHERE pi.pedido_id = $1`,
        [pedidoId],
      );
      const subtotalNuevo = Number(subtotalRow.rows[0]?.subtotal ?? 0);
      const descuento = await this.recalcularDescuentoTrasCambioSubtotal(
        client,
        sucursalId,
        pedido.promocion_id,
        subtotalNuevo,
        Number(pedido.descuento),
      );
      const totalNuevo = Math.max(
        0,
        subtotalNuevo + Number(pedido.costo_domicilio) - descuento,
      );
      const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(
        client,
        sucursalId,
        totalNuevo,
      );
      await client.query(
        `UPDATE pedidos SET
           subtotal = $1, descuento = $2, total = $3,
           iva_porcentaje = $4, iva_valor = $5
         WHERE id = $6`,
        [
          subtotalNuevo,
          descuento,
          totalNuevo,
          iva.iva_porcentaje,
          iva.iva_valor,
          pedidoId,
        ],
      );

      await this.facturacion.sincronizarBorradorDesdePedidoEnTransaccion(
        client,
        sucursalId,
        pedidoId,
      );

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'ACTUALIZAR_ITEM_PEDIDO',
        tablaAfectada: 'pedido_items',
        registroId: itemId,
        usuarioId,
        datosAntes: {
          cantidad: item.cantidad,
          observaciones: item.observaciones,
          estado_cocina: item.estado_cocina,
        },
        datosDespues: {
          cantidad: cantidadNueva,
          observaciones: obsNueva,
          toppings: toppingsNuevos?.map((t) => t.id) ?? null,
          estado_cocina: estadoCocinaNuevo,
        },
      });

      return {
        pedido_id: pedidoId,
        item_id: itemId,
        estado: pedido.estado,
        numero_pedido: pedido.numero_pedido,
        subtotal: subtotalNuevo,
        total: totalNuevo,
        cocina_id: item.cocina_id,
        mesa_id: pedido.mesa_id,
        reimprimir: cambiaCocina ||
          ['en_cocina', 'listo', 'confirmado'].includes(pedido.estado),
      };
    });

    this.soporte.notificarPedidoRealtime(
      sucursalId,
      resultado.pedido_id,
      resultado.estado,
      resultado.numero_pedido,
    );
    if (resultado.cocina_id) {
      void this.realtime.cocinaActualizada(resultado.cocina_id, {
        pedido_id: resultado.pedido_id,
        sucursal_id: sucursalId,
        accion: 'item_actualizado',
      });
    }
    if (resultado.mesa_id) {
      void this.realtime.mesasActualizadas(sucursalId);
    }
    if (resultado.reimprimir) {
      void this.soporte.notificarCocinasPorPedido(
        resultado.pedido_id,
        sucursalId,
      );
    }
    return resultado;
  }

  async actualizarComensalEtiqueta(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    comensalEtiqueta: string | null,
  ) {
    const res = await this.database.consultarUno<{ id: string }>(
      `UPDATE pedido_items pi
       SET comensal_etiqueta = $4
       FROM pedidos p
       WHERE pi.id = $1 AND pi.pedido_id = $2 AND p.id = $2
         AND p.sucursal_id = $3 AND p.estado NOT IN ('cancelado','rechazado','pagado')
       RETURNING pi.id`,
      [itemId, pedidoId, sucursalId, comensalEtiqueta?.trim() || null],
    );
    if (!res) {
      throw new NotFoundException('Ítem no encontrado o pedido cerrado');
    }
    return { item_id: itemId, comensal_etiqueta: comensalEtiqueta?.trim() || null };
  }

}
