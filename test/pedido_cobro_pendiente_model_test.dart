import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/pedidos/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_columnas_por_canal.dart';

void main() {
  PedidoAdminModel pedido({
    required String tipo,
    required String estado,
    required num total,
    required num pagado,
  }) {
    final ahora = DateTime.now();
    return PedidoAdminModel(
      id: 'pedido-1',
      numeroPedido: 'FDY-1',
      tipo: tipo,
      estado: estado,
      total: total,
      montoPagado: pagado,
      creadoEn: ahora,
      estadoDesde: ahora,
    );
  }

  test('domicilio entregado impago sigue abierto y ofrece registrar pago', () {
    final p = pedido(
      tipo: 'domicilio',
      estado: 'entregado',
      total: 10000,
      pagado: 4000,
    );

    expect(p.requiereCobroCaja, isTrue);
    expect(p.esTerminal, isFalse);
    expect(p.accionRapida, 'cobrar');
    expect(p.etiquetaAccionRapida, 'Registrar pago');
  });

  test('domicilio entregado totalmente pagado queda terminal', () {
    final p = pedido(
      tipo: 'domicilio',
      estado: 'entregado',
      total: 10000,
      pagado: 10000,
    );

    expect(p.requiereCobroCaja, isFalse);
    expect(p.esTerminal, isTrue);
    expect(p.accionRapida, isNull);
  });

  test('pedido de otro canal no hereda la acción de cobro de domicilio', () {
    final p = pedido(
      tipo: 'mesa',
      estado: 'entregado',
      total: 10000,
      pagado: 0,
    );

    expect(p.requiereCobroCaja, isFalse);
    expect(p.accionRapida, isNull);
  });

  test('Kanban expone la columna de domicilio por cobrar', () {
    final columns = PedidoColumnasPorCanal.para(
      filtroTipo: 'domicilio',
      modoMesero: false,
    );
    final column = columns.singleWhere((c) => c.clave == 'por_cobrar');

    expect(column.titulo, 'Entregados · por cobrar');
    expect(column.contieneEstado('entregado'), isTrue);
  });
}
