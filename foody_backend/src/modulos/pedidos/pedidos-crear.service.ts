import { BadRequestException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { ZonasService } from '../zonas/zonas.service';
import { PromocionesService } from '../promociones/promociones.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosSoporteService, OpcionesStaffPedido } from './pedidos-soporte.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import {
  ContextoAlertaStock,
  PedidosInventarioService,
} from './pedidos-inventario.service';
import { estadoActivaCocina } from './pedido-estados';

/** Subdominio: creaci?n de pedidos (cliente y staff). */
@Injectable()
export class PedidosCrearService {
  private readonly inventario: PedidosInventarioService;

  constructor(
    private readonly database: DatabaseService,
    private readonly facturacion: FacturacionService,
    private readonly zonas: ZonasService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly costeo: CosteoService,
    private readonly promociones: PromocionesService,
    private readonly cajaAuditoria: PedidosCajaAuditoriaService,
    private readonly soporte: PedidosSoporteService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
  ) {
    this.inventario = new PedidosInventarioService(
      this.costeo,
      this.alertasRiesgo,
    );
  }
  async crear(
    dto: CrearPedidoDto,
    opciones: OpcionesStaffPedido = {},
  ) {
    const items = dto.items ?? [];
    const combos = dto.combos ?? [];
    if (!items.length && !combos.length) {
      throw new BadRequestException('El pedido debe incluir al menos un ?tem');
    }

    const totalLineas =
      items.reduce((s, i) => s + (i.cantidad ?? 1), 0) +
      combos.reduce((s, c) => s + (c.cantidad ?? 1), 0);
    if (totalLineas > 50) {
      throw new BadRequestException({
        error: 'LIMITE_ITEMS',
        message: 'El pedido no puede superar 50 ?tems',
      });
    }

    if (dto.idempotency_key?.trim()) {
      const existente = await this.database.consultarUno<{ pedido_id: string }>(
        `SELECT pedido_id FROM pedidos_idempotencia WHERE clave = $1`,
        [dto.idempotency_key.trim()],
      );
      if (existente) {
        const pedido = await this.database.consultarUno(
          `SELECT id, numero_pedido, estado, total FROM pedidos WHERE id = $1`,
          [existente.pedido_id],
        );
        return { ...pedido, idempotente: true };
      }
    }

    if (dto.requiere_factura) {
      if (
        !dto.nit_cliente?.trim() ||
        !dto.nombre_fiscal_cliente?.trim() ||
        !dto.email_cliente?.trim()
      ) {
        throw new BadRequestException({
          error: 'DATOS_FACTURA_REQUERIDOS',
          message: 'Indica NIT, nombre fiscal y email para la factura',
        });
      }
    }

    let catalogoCambios: { producto_id: string; disponible: boolean }[] = [];
    const resultado = await this.database.enTransaccion(async (client) => {
      const sucursal = await this.soporte.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM sucursales WHERE id = $1 AND activa = true`,
        [dto.sucursal_id],
      );
      if (!sucursal) {
        throw new BadRequestException('Sucursal no disponible');
      }

      const horario = await this.soporte.consultarUnoCliente<{ activo: boolean }>(
        client,
        `SELECT CASE
           WHEN NOT EXISTS (
             SELECT 1 FROM horarios_sucursal h
             WHERE h.sucursal_id = $1 AND h.activo = true
           ) THEN true
           ELSE EXISTS (
             SELECT 1 FROM horarios_sucursal h
             WHERE h.sucursal_id = $1 AND h.activo = true
               AND h.dia_semana = EXTRACT(DOW FROM NOW() AT TIME ZONE 'America/Bogota')::int
               AND (NOW() AT TIME ZONE 'America/Bogota')::time
                 BETWEEN h.hora_apertura AND h.hora_cierre
           )
         END AS activo`,
        [dto.sucursal_id],
      );
      if (!horario?.activo) {
        throw new BadRequestException('RESTAURANTE_CERRADO');
      }

      let mesaNombre: string | null = null;
      if (dto.mesa_id) {
        const mesa = await this.soporte.consultarUnoCliente<{ id: string; nombre: string }>(
          client,
          `SELECT id, nombre FROM mesas
           WHERE id = $1 AND sucursal_id = $2 AND activa = true`,
          [dto.mesa_id, dto.sucursal_id],
        );
        if (!mesa) {
          throw new BadRequestException('MESA_NO_ENCONTRADA');
        }
        mesaNombre = mesa.nombre;
        if (
          opciones.creadoPorStaff &&
          opciones.usuarioId &&
          this.soporte.esRolMesero(opciones.rol)
        ) {
          await this.soporte.assertMeseraPuedeTomarMesa(
            client,
            dto.sucursal_id,
            dto.mesa_id,
            opciones.usuarioId,
          );
        }
      }

      let subtotal = 0;
      const lineasInventario: {
        productoId: string;
        cantidad: number;
        precioVentaLinea: number;
        nombreProducto?: string;
      }[] = [];
      const lineasPreparadas: {
        productoId: string;
        cantidad: number;
        precioUnitario: number;
        precioVentaLinea: number;
        costoUnitario: number;
        cocinaId: string | null;
        observaciones: string | null;
        toppings: { id: string; nombre: string; precio: number }[];
        bebidas: { id: string; nombre: string; precio: number; cantidad: number }[];
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
           FROM productos
           WHERE id = $1 AND sucursal_id = $2`,
          [item.producto_id, dto.sucursal_id],
        );
        if (!producto?.disponible) {
          throw new BadRequestException('PRODUCTO_NO_DISPONIBLE');
        }
        // Precio autoritativo del servidor (Flutter solo muestra; no validamos tampering estricto).
        const precioUnit = this.soporte.precioVentaProducto(producto, dto.tipo);

        let lineaTotal = precioUnit * item.cantidad;
        const toppings: { id: string; nombre: string; precio: number }[] = [];
        for (const t of item.toppings ?? []) {
          const top = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
          }>(
            client,
            `SELECT id, nombre, precio FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [t.topping_id, dto.sucursal_id],
          );
          if (!top) throw new BadRequestException('TOPPING_NO_DISPONIBLE');
          const p = Number(top.precio);
          toppings.push({ id: top.id, nombre: top.nombre, precio: p });
          lineaTotal += p * item.cantidad;
        }

        const bebidas: { id: string; nombre: string; precio: number; cantidad: number }[] = [];
        for (const b of item.bebidas ?? []) {
          const beb = await this.soporte.consultarUnoCliente<{
            id: string;
            nombre: string;
            precio: string;
          }>(
            client,
            `SELECT id, nombre, precio FROM bebidas
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
            [b.bebida_id, dto.sucursal_id],
          );
          if (!beb) throw new BadRequestException('BEBIDA_NO_DISPONIBLE');
          const p = Number(beb.precio);
          bebidas.push({
            id: beb.id,
            nombre: beb.nombre,
            precio: p,
            cantidad: b.cantidad,
          });
          lineaTotal += p * b.cantidad;
        }

        subtotal += lineaTotal;
        lineasPreparadas.push({
          productoId: producto.id,
          cantidad: item.cantidad,
          precioUnitario: precioUnit,
          precioVentaLinea: lineaTotal,
          costoUnitario: Number(producto.costo_calculado ?? 0),
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
          [comboDto.combo_id, dto.sucursal_id],
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
          [productoItem.item_id, dto.sucursal_id],
        );
        if (!producto) {
          throw new BadRequestException('PRODUCTO_NO_DISPONIBLE');
        }

        const productosCombo = comboItems.rows
          .filter((ci) => ci.tipo_item === 'producto')
          .map((ci) => ({ productoId: ci.item_id, cantidad: ci.cantidad }));

        subtotal += precioFijo * comboDto.cantidad;
        combosPreparados.push({
          comboId: combo.id,
          nombre: combo.nombre,
          cantidad: comboDto.cantidad,
          precioFijo,
          productoPrincipalId: producto.id,
          cocinaId: producto.cocina_id,
          costoUnitario: 0,
          productosCombo,
        });

        for (const pc of productosCombo) {
          lineasInventario.push({
            productoId: pc.productoId,
            cantidad: pc.cantidad * comboDto.cantidad,
            precioVentaLinea: 1,
          });
        }
      }

      const costoDomicilio =
        dto.tipo === 'domicilio'
          ? (
              await this.zonas.calcularCostoDomicilio(
                client,
                dto.sucursal_id,
                dto.lat ?? null,
                dto.lng ?? null,
              )
            ).costo
          : 0;

      let descuentoPromo = 0;
      let promocionId: string | null = null;
      let motivoDescuento: string | null = null;
      if (dto.codigo_promocion?.trim()) {
        const promo = await this.promociones.resolverDescuentoPorCodigo(
          client,
          dto.sucursal_id,
          dto.codigo_promocion,
          subtotal,
        );
        descuentoPromo = promo.monto;
        promocionId = promo.promocion_id;
        motivoDescuento = promo.motivo;
      } else {
        const auto = await this.promociones.resolverMejorAutomatica(
          client,
          dto.sucursal_id,
          subtotal,
        );
        if (auto) {
          descuentoPromo = auto.monto;
          promocionId = auto.promocion_id;
          motivoDescuento = auto.motivo;
        }
      }

      const total = subtotal + costoDomicilio - descuentoPromo;
      const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(
        client,
        dto.sucursal_id,
        total,
      );
      const estadoInicial = this.soporte.resolverEstadoInicial(dto, opciones.creadoPorStaff);
      const metodoPago = dto.metodo_pago ?? 'pendiente';
      const numeroPedido = await this.soporte.generarNumeroPedido(client, dto.sucursal_id);

      await client.query(
        `INSERT INTO dispositivos_cliente (device_id, ultimo_acceso, plataforma)
         VALUES ($1, now(), 'android')
         ON CONFLICT (device_id) DO UPDATE SET ultimo_acceso = now()`,
        [dto.device_id],
      );

      const insertPedido = await client.query<{ id: string }>(
        `INSERT INTO pedidos (
           sucursal_id, mesa_id, device_id, numero_pedido, tipo, estado,
           cliente_nombre, cliente_telefono, direccion_entrega, lat, lng,
           metodo_pago, subtotal, costo_domicilio, descuento, motivo_descuento,
           promocion_id, total, requiere_factura,
           observaciones, tiempo_estimado_minutos, iva_porcentaje, iva_valor
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23)
         RETURNING id`,
        [
          dto.sucursal_id,
          dto.mesa_id ?? null,
          dto.device_id,
          numeroPedido,
          dto.tipo,
          estadoInicial,
          dto.cliente_nombre ?? null,
          dto.cliente_telefono ?? null,
          dto.direccion_entrega ?? null,
          dto.lat ?? null,
          dto.lng ?? null,
          metodoPago,
          subtotal,
          costoDomicilio,
          descuentoPromo,
          motivoDescuento,
          promocionId,
          total,
          dto.requiere_factura ?? false,
          dto.observaciones ?? null,
          25,
          iva.iva_porcentaje,
          iva.iva_valor,
        ],
      );
      const pedidoId = insertPedido.rows[0].id;

      const opcionesStock = { incluirEmpaques: dto.tipo === 'domicilio' };
      const contextoStock: ContextoAlertaStock = {
        origen: opciones.creadoPorStaff
          ? 'staff'
          : dto.tipo === 'domicilio'
            ? 'domicilio'
            : dto.tipo === 'para_llevar'
              ? 'para_llevar'
              : 'mesa',
        clienteNombre: dto.cliente_nombre,
        mesaNombre,
      };
      await this.inventario.validarStockDisponible(
        client,
        dto.sucursal_id,
        lineasInventario,
        opcionesStock,
        contextoStock,
      );

      const debeDescontarAhora = estadoActivaCocina(estadoInicial);
      let costosRecalculados = new Map<string, number>();

      if (debeDescontarAhora) {
        const stock = await this.inventario.descontarStockPedido(
          client,
          dto.sucursal_id,
          pedidoId,
          lineasInventario,
          opcionesStock,
        );
        costosRecalculados = stock.costos;
        catalogoCambios.push(...stock.catalogo);
        await client.query(
          `UPDATE pedidos SET stock_descontado = true WHERE id = $1`,
          [pedidoId],
        );
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
            dto.sucursal_id,
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
          const costoUnit = combo.costoUnitario;
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

          const margenPct =
            combo.precioFijo > 0
              ? ((combo.precioFijo - costoUnit) / combo.precioFijo) * 100
              : 0;
          await client.query(
            `INSERT INTO margenes_venta (
               pedido_id, pedido_item_id, sucursal_id,
               precio_venta, costo_al_momento, margen_porcentaje
             ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [
              pedidoId,
              itemId,
              dto.sucursal_id,
              combo.precioFijo,
              costoUnit,
              margenPct,
            ],
          );
        }
      }

      if (dto.pagos?.length) {
        const sumaPagos = dto.pagos.reduce((s, p) => s + p.monto, 0);
        if (Math.abs(sumaPagos - total) > 0.01) {
          throw new BadRequestException({
            error: 'PAGOS_NO_COINCIDEN',
            message: `La suma de pagos (${sumaPagos}) debe ser ${total}`,
          });
        }
        const propinaCaja = dto.propina ?? 0;
        for (const pago of dto.pagos) {
          await this.cajaAuditoria.registrarVentaEnCaja(
            client,
            dto.sucursal_id,
            pedidoId,
            pago.monto,
            pago.metodo_pago,
            { exigirCaja: true, descripcion: `Venta ${numeroPedido}` },
          );
          await client.query(
            `INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, referencia
             ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [
              dto.sucursal_id,
              pedidoId,
              pago.monto,
              total > 0 ? propinaCaja * (pago.monto / total) : 0,
              pago.metodo_pago,
              'Cobro al crear pedido',
            ],
          );
        }
        await client.query(
          `UPDATE pedidos SET monto_pagado = $2, propina_acumulada = $3, metodo_pago = $4 WHERE id = $1`,
          [pedidoId, total, propinaCaja, dto.pagos[0].metodo_pago],
        );
      } else if (
        this.cajaAuditoria.debeRegistrarVentaAlCrear(
          estadoInicial,
          dto.tipo,
          dto.mesa_id,
          metodoPago,
        )
      ) {
        await this.cajaAuditoria.registrarVentaEnCaja(
          client,
          dto.sucursal_id,
          pedidoId,
          total,
          metodoPago,
        );
      }

      await this.cajaAuditoria.registrarAuditoria(client, dto.sucursal_id, pedidoId, {
        numero_pedido: numeroPedido,
        tipo: dto.tipo,
        total,
        subtotal,
        costo_domicilio: costoDomicilio,
        items: items.length + combos.length,
        device_id: dto.device_id,
      });

      await client.query(
        `INSERT INTO estados_pedido_historial (pedido_id, estado_anterior, estado_nuevo)
         VALUES ($1, NULL, $2)`,
        [pedidoId, estadoInicial],
      );

      if (dto.mesa_id) {
        await this.cuentaMesa.marcarEstadoOperativoMesa(
          client,
          dto.mesa_id,
          dto.sucursal_id,
          'ocupada',
        );
      }

      if (
        opciones.creadoPorStaff &&
        opciones.usuarioId &&
        dto.mesa_id &&
        estadoInicial === 'en_cocina' &&
        this.soporte.esRolMesero(opciones.rol)
      ) {
        await client.query(
          `UPDATE pedidos SET mesera_id = $1, aprobado_at = now() WHERE id = $2`,
          [opciones.usuarioId, pedidoId],
        );
        await this.soporte.asignarMeseraAMesa(
          client,
          dto.sucursal_id,
          dto.mesa_id,
          opciones.usuarioId,
        );
      } else if (
        opciones.creadoPorStaff &&
        dto.mesa_id &&
        estadoInicial === 'confirmado'
      ) {
        await client.query(
          `UPDATE pedidos SET aprobado_at = now() WHERE id = $1`,
          [pedidoId],
        );
      }

      let facturaId: string | null = null;
      if (dto.requiere_factura) {
        facturaId = await this.facturacion.crearBorradorEnTransaccion(client, {
          sucursalId: dto.sucursal_id,
          pedidoId,
          total,
          nitCliente: dto.nit_cliente!.trim(),
          nombreFiscalCliente: dto.nombre_fiscal_cliente!.trim(),
          emailCliente: dto.email_cliente!.trim(),
        });
      }

      if (dto.idempotency_key?.trim()) {
        await client.query(
          `INSERT INTO pedidos_idempotencia (clave, pedido_id) VALUES ($1, $2)
           ON CONFLICT (clave) DO NOTHING`,
          [dto.idempotency_key.trim(), pedidoId],
        );
      }

      return {
        pedido_id: pedidoId,
        numero_pedido: numeroPedido,
        subtotal,
        costo_domicilio: costoDomicilio,
        total,
        estado: estadoInicial,
        tiempo_estimado_minutos: 25,
        factura_id: facturaId,
      };
    });
    this.soporte.notificarPedidoRealtime(
      dto.sucursal_id,
      resultado.pedido_id,
      resultado.estado,
      resultado.numero_pedido,
      { mesaId: dto.mesa_id ?? null },
    );
    if (dto.mesa_id) {
      void this.realtime.mesasActualizadas(dto.sucursal_id);
    }
    this.soporte.notificarCatalogoDisponibilidad(
      dto.sucursal_id,
      catalogoCambios,
    );
    if (estadoActivaCocina(resultado.estado)) {
      void this.soporte.notificarCocinasPorPedido(resultado.pedido_id, dto.sucursal_id);
    }
    if (
      this.cajaAuditoria.debeRegistrarVentaAlCrear(
        resultado.estado,
        dto.tipo,
        dto.mesa_id,
        dto.metodo_pago ?? 'pendiente',
      )
    ) {
      void this.realtime.cajaMovimiento(dto.sucursal_id, {
        pedido_id: resultado.pedido_id,
      });
    }
    return resultado;
  }

}
