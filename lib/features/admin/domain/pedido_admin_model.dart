import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';

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
    this.direccionEntrega,
    this.domiciliarioNombre,
    required this.total,
    required this.creadoEn,
    required this.estadoDesde,
  });

  final String id;
  final String numeroPedido;
  final String tipo;
  final String estado;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String? mesaNombre;
  final String? mesaId;
  final String? direccionEntrega;
  final String? domiciliarioNombre;
  final num total;
  final DateTime creadoEn;
  final DateTime estadoDesde;

  factory PedidoAdminModel.fromJson(Map<String, dynamic> json) {
    return PedidoAdminModel(
      id: json['id'] as String,
      numeroPedido: json['numero_pedido'] as String,
      tipo: json['tipo'] as String,
      estado: json['estado'] as String,
      clienteNombre: json['cliente_nombre'] as String?,
      clienteTelefono: json['cliente_telefono'] as String?,
      mesaNombre: json['mesa_nombre'] as String?,
      mesaId: json['mesa_id'] as String?,
      direccionEntrega: json['direccion_entrega'] as String?,
      domiciliarioNombre: json['domiciliario_nombre'] as String?,
      total: parsearNumero(json['total']),
      creadoEn: DateTime.parse(json['created_at'].toString()),
      estadoDesde: DateTime.parse(
        (json['estado_desde'] ?? json['created_at']).toString(),
      ),
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
        if (tipo == 'domicilio') return null;
        if (tipo == 'mesa' || (mesaId != null && mesaId!.isNotEmpty)) {
          return null;
        }
        return 'entregado';
      case 'asignado':
        return null;
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
        return 'Aprobar';
      case 'en_cocina':
        return 'A cocina';
      case 'listo':
        return 'Listo';
      case 'pagando':
        return 'Pagando';
      case 'asignado':
        return 'Asignado';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      default:
        return 'Avanzar';
    }
  }
}
