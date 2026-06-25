import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosCrearService } from './pedidos-crear.service';
import { PedidosDescuentoService } from './pedidos-descuento.service';
import { PedidosEstadoService } from './pedidos-estado.service';
import { PedidosItemsService } from './pedidos-items.service';
import { PedidosPagosService } from './pedidos-pagos.service';
import { OpcionesStaffPedido } from './pedidos-soporte.service';

@Injectable()
export class PedidosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
    private readonly estado: PedidosEstadoService,
    private readonly crearPedido: PedidosCrearService,
    private readonly items: PedidosItemsService,
    private readonly descuento: PedidosDescuentoService,
    private readonly pagos: PedidosPagosService,
  ) {}

  async listarPorSucursal(
    sucursalId: string,
    opciones: { soloActivos?: boolean; limite?: number } = {},
  ) {
    const limite = opciones.limite ?? 100;
    const filtroActivos = opciones.soloActivos
      ? `AND p.estado IN ('pendiente', 'pendiente_aprobacion', 'confirmado', 'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino')`
      : '';

    return this.database.consultar(
      `SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.cliente_nombre,
              p.cliente_telefono, p.direccion_entrega, p.total, p.created_at, p.mesa_id,
              m.nombre AS mesa_nombre,
              u_dom.nombre AS domiciliario_nombre,
              COALESCE(h.fecha, p.created_at) AS estado_desde
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       LEFT JOIN LATERAL (
         SELECT ad.domiciliario_planta_id
         FROM asignaciones_domicilio ad
         WHERE ad.pedido_id = p.id
           AND ad.estado IN ('asignado', 'en_camino', 'entregado')
         ORDER BY ad.asignado_at DESC
         LIMIT 1
       ) ad ON true
       LEFT JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
       LEFT JOIN usuarios u_dom ON u_dom.id = dp.usuario_id
       LEFT JOIN LATERAL (
         SELECT fecha FROM estados_pedido_historial
         WHERE pedido_id = p.id AND estado_nuevo = p.estado
         ORDER BY fecha DESC
         LIMIT 1
       ) h ON true
       WHERE p.sucursal_id = $1 ${filtroActivos}
       ORDER BY p.created_at DESC
       LIMIT $2`,
      [sucursalId, limite],
    );
  }

  /** Pedidos activos de una mesa con ítems y estado de cocina (A-MES-3). */
  async listarActivosPorMesa(sucursalId: string, mesaId: string) {
    return this.cuentaMesa.listarActivosPorMesa(sucursalId, mesaId);
  }

  async cambiarEstado(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    nuevoEstado: string,
    motivo?: string,
    contexto?: { rol: string; permisos: string[] },
  ) {
    return this.estado.cambiarEstado(
      pedidoId,
      sucursalId,
      usuarioId,
      nuevoEstado,
      motivo,
      contexto,
    );
  }

  async crear(
    dto: CrearPedidoDto,
    opciones: OpcionesStaffPedido = {},
  ) {
    return this.crearPedido.crear(dto, opciones);
  }

  async agregarItems(
    pedidoId: string,
    sucursalId: string,
    dto: AgregarItemsPedidoDto,
    opciones: OpcionesStaffPedido = {},
  ) {
    return this.items.agregarItems(pedidoId, sucursalId, dto, opciones);
  }

  /** Marca todos los pedidos activos de la mesa como pagados y libera la mesa. */
  async cobrarCuentaMesa(
    sucursalId: string,
    mesaId: string,
    usuarioId: string,
    dto: CobrarMesaDto = {},
  ) {
    return this.pagos.cobrarCuentaMesa(
      sucursalId,
      mesaId,
      usuarioId,
      dto,
    );
  }

  async cobrarPedidoCaja(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    dto: CobrarMesaDto = {},
  ) {
    return this.pagos.cobrarPedidoCaja(sucursalId, pedidoId, usuarioId, dto);
  }

  async actualizarComensalItem(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    comensalEtiqueta: string | null,
  ) {
    return this.items.actualizarComensalEtiqueta(
      pedidoId,
      itemId,
      sucursalId,
      comensalEtiqueta,
    );
  }

  async listarPorDevice(deviceId: string) {
    return this.database.consultar(
      `SELECT p.id, p.numero_pedido, p.estado, p.tipo, p.total,
              p.created_at, s.nombre AS sucursal_nombre
       FROM pedidos p
       INNER JOIN sucursales s ON s.id = p.sucursal_id
       WHERE p.device_id = $1
       ORDER BY p.created_at DESC
       LIMIT 50`,
      [deviceId],
    );
  }

  async obtenerEstadoPublico(pedidoId: string) {
    const pedido = await this.database.consultarUno<{
      id: string;
      numero_pedido: string;
      estado: string;
      total: string;
      tipo: string;
      lat: string | null;
      lng: string | null;
      direccion_entrega: string | null;
      tiempo_estimado_minutos: number | null;
      created_at: Date;
    }>(
      `SELECT id, numero_pedido, estado, total, tipo, lat, lng, direccion_entrega,
              tiempo_estimado_minutos, created_at
       FROM pedidos WHERE id = $1`,
      [pedidoId],
    );
    if (!pedido) throw new NotFoundException('Pedido no encontrado');

    const historial = await this.database.consultar<{
      estado_nuevo: string;
      fecha: Date;
    }>(
      `SELECT estado_nuevo, fecha FROM estados_pedido_historial
       WHERE pedido_id = $1 ORDER BY fecha ASC`,
      [pedidoId],
    );

    return {
      pedido_id: pedido.id,
      numero_pedido: pedido.numero_pedido,
      estado_actual: pedido.estado,
      tipo: pedido.tipo,
      total: Number(pedido.total),
      lat: pedido.lat != null ? Number(pedido.lat) : null,
      lng: pedido.lng != null ? Number(pedido.lng) : null,
      direccion_entrega: pedido.direccion_entrega,
      tiempo_estimado_minutos: pedido.tiempo_estimado_minutos,
      historial: historial.map((h) => ({
        estado: h.estado_nuevo,
        fecha: h.fecha,
      })),
    };
  }

  async aprobarMesa(pedidoId: string, sucursalId: string, usuarioId: string) {
    return this.estado.aprobarMesa(pedidoId, sucursalId, usuarioId);
  }

  async rechazarMesa(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    motivo: string,
  ) {
    return this.estado.rechazarMesa(pedidoId, sucursalId, usuarioId, motivo);
  }

  async aplicarDescuento(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    dto: AplicarDescuentoDto,
    contexto: { rol: string; permisos: string[] },
  ) {
    return this.descuento.aplicarDescuento(
      pedidoId,
      sucursalId,
      usuarioId,
      dto,
      contexto,
    );
  }

  async eliminarItemPedido(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    usuarioId: string,
    motivo?: string,
  ) {
    return this.items.eliminarItemPedido(
      pedidoId,
      itemId,
      sucursalId,
      usuarioId,
      motivo,
    );
  }
}
