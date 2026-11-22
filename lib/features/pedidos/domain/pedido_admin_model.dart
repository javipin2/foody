import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_item_resumen.dart';

class PedidoAdminModel {
  const PedidoAdminModel({
    required this.id,
    required this.numeroPedido,
    required this.tipo,
    required this.estado,
    this.clienteNombre,
    this.clienteTelefono,
    this.mesaNombre,
    this.mesaId,
    this.meseraId,
    this.meseraNombre,
    this.meseraMesaId,
    this.direccionEntrega,
    this.domiciliarioNombre,
    required this.total,
    this.montoPagado = 0,
    this.metodoPago,
    required this.creadoEn,
    required this.estadoDesde,
    this.itemsResumen = const [],
  });

  final String id;
  final String numeroPedido;
  final String tipo;
  final String estado;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? mesaNombre;
  final String? mesaId;
  final String? meseraId;
  final String? meseraNombre;
  /// Mesera ya asignada a la mesa (turno), para preselección al confirmar QR.
  final String? meseraMesaId;
  final String? direccionEntrega;
  final String? domiciliarioNombre;
  final num total;
  final num montoPagado;
  final String? metodoPago;
  final DateTime creadoEn;
  final DateTime estadoDesde;
  final List<PedidoItemResumen> itemsResumen;

  num get saldoPendiente =>
      (total - montoPagado).clamp(0, double.infinity).toDouble();

  bool get requiereCobroCaja =>
      tipo == 'para_llevar' &&
      saldoPendiente > 0.01 &&
      !['cancelado', 'rechazado', 'entregado', 'pagado'].contains(estado);

  bool get esTerminal =>
      const {'pagado', 'entregado', 'cancelado', 'rechazado'}
          .contains(estado);

  factory PedidoAdminModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items_resumen'] as List<dynamic>? ?? [];
    return PedidoAdminModel(
      id: json['id'] as String,
      numeroPedido: json['numero_pedido'] as String,
      tipo: json['tipo'] as String,
      estado: json['estado'] as String,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteTelefono: json['cliente_telefono'] as String?,
      mesaNombre: json['mesa_nombre'] as String?,
      mesaId: json['mesa_id'] as String?,
      meseraId: json['mesera_id'] as String?,
      meseraNombre: json['mesera_nombre'] as String?,
      meseraMesaId: json['mesera_asignada_id'] as String?,
      direccionEntrega: json['direccion_entrega'] as String?,
      domiciliarioNombre: json['domiciliario_nombre'] as String?,
      total: parsearNumero(json['total']),
      montoPagado: parsearNumero(json['monto_pagado'] ?? 0),
      metodoPago: json['metodo_pago'] as String?,
      creadoEn: DateTime.parse(json['created_at'].toString()),
      estadoDesde: DateTime.parse(
        (json['estado_desde'] ?? json['created_at']).toString(),
      ),
      itemsResumen: rawItems
          .map((e) => PedidoItemResumen.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  String get etiquetaCliente {
    if (mesaNombre != null && mesaNombre!.isNotEmpty) {
      return 'Mesa $mesaNombre';
    }
    if (tipo == 'domicilio' && direccionEntrega?.trim().isNotEmpty == true) {
      return direccionEntrega!;
    }
    if (clienteNombre?.trim().isNotEmpty == true) {
      return clienteNombre!;
    }
    return 'Sin nombre';
  }

  String get etiquetaAtribucion {
    final partes = <String>[];
    if (tipo == 'mesa' && mesaNombre != null) {
      partes.add('Mesa $mesaNombre');
    } else if (tipo == 'domicilio') {
      partes.add('Domicilio');
    } else if (tipo == 'para_llevar') {
      partes.add('Para llevar');
    }
    if (meseraNombre?.trim().isNotEmpty == true) {
      partes.add('Mesera: ${meseraNombre!.trim()}');
    }
    if (clienteNombre?.trim().isNotEmpty == true &&
        tipo != 'mesa') {
      partes.add('Cliente: ${clienteNombre!.trim()}');
    }
    if (domiciliarioNombre?.trim().isNotEmpty == true) {
      partes.add('Domiciliario: ${domiciliarioNombre!.trim()}');
    }
    return partes.isEmpty ? etiquetaCliente : partes.join(' · ');
  }

  String? get accionRapida {
    switch (estado) {
      case 'pendiente_aprobacion':
        return 'aprobar';
      case 'pendiente':
      case 'confirmado':
        return 'en_cocina';
      case 'en_cocina':
        return 'listo';
      case 'listo':
        return tipo == 'domicilio' ? null : 'pagando';
      case 'pagando':
        return null;
      case 'asignado':
        return tipo == 'domicilio' ? 'en_camino' : null;
      case 'en_camino':
        return tipo == 'domicilio' ? 'entregado' : null;
      default:
        return null;
    }
  }

  /// Columna Kanban (legacy `confirmado` → en cocina).
  String get estadoKanban {
    if (estado == 'confirmado') return 'en_cocina';
    return estado;
  }

  String get etiquetaAccionRapida {
    switch (accionRapida) {
      case 'aprobar':
        return 'Confirmar';
      case 'en_cocina':
        return 'A cocina';
      case 'listo':
        return 'Listo';
      case 'pagando':
        return 'A cobrar';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      default:
        return 'Avanzar';
    }
  }
}
