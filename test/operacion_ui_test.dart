import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/tema/tema_foody.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_estado_pill.dart';

void main() {
  for (final caso in [
    (ancho: 320.0, modo: ThemeMode.light),
    (ancho: 390.0, modo: ThemeMode.dark),
    (ancho: 820.0, modo: ThemeMode.dark),
    (ancho: 1440.0, modo: ThemeMode.light),
  ]) {
    testWidgets(
      'controles de operación adaptan tema y ancho ${caso.ancho}px (${caso.modo.name})',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(caso.ancho, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: TemaFoody.claro(),
            darkTheme: TemaFoody.oscuro(),
            themeMode: caso.modo,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OperacionPageHeader(
                      titulo: 'Pedidos del establecimiento',
                      subtitulo: 'Revisa y gestiona los pedidos activos',
                      acciones: [
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add),
                          label: const Text('Crear pedido'),
                        ),
                      ],
                    ),
                    OperacionAviso(
                      mensaje:
                          'No hay una caja abierta. Abre un turno para continuar con la operación.',
                      accion: 'Ir a Caja',
                      onAccion: () {},
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      colorTexto: const Color(0xFF92400E),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OperacionStatusChip(estado: 'en_cocina'),
                          const SizedBox(height: 8),
                          const PedidoEstadoPill(estado: 'pagando'),
                          const SizedBox(height: 8),
                          OperacionStatChip(
                            etiqueta: 'Activos',
                            valor: '12',
                            onTap: () {},
                            seleccionado: true,
                          ),
                          const SizedBox(height: 8),
                          OperacionPillTabs(
                            opciones: const [
                              ('todos', 'Todos'),
                              ('mesa', 'Mesa'),
                              ('domicilio', 'Domicilio'),
                            ],
                            seleccionada: 'todos',
                            onCambio: (_) {},
                          ),
                          const SizedBox(height: 8),
                          OperacionBusqueda(controller: controller),
                          const SizedBox(height: 8),
                          const OperacionTipoToggle(
                            opciones: [
                              ('mesa', 'Mesa'),
                              ('llevar', 'Para llevar')
                            ],
                            seleccionada: 'mesa',
                            onCambio: _sinCambio,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pedidos del establecimiento'), findsOneWidget);
        expect(find.text('Ir a Caja'), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (caso.ancho == 320) {
          expect(tester.getSize(find.byType(TextButton)).height,
              greaterThanOrEqualTo(48));
        }

        if (caso.modo == ThemeMode.dark) {
          final finder = find.descendant(
            of: find.byType(OperacionStatusChip),
            matching: find.text('En cocina'),
          );
          final text = tester.widget<Text>(finder);
          final containerFinder = find
              .ancestor(
                of: finder,
                matching: find.byType(Container),
              )
              .first;
          final container = tester.widget<Container>(containerFinder);
          final background = (container.decoration! as BoxDecoration).color!;
          final surface = TemaFoody.oscuro().colorScheme.surface;
          final ratio = _contrastRatio(
            text.style!.color!,
            Color.alphaBlend(background, surface),
          );
          expect(ratio, greaterThanOrEqualTo(4.5));
        }
      },
    );
  }
}

void _sinCambio(String _) {}

double _contrastRatio(Color a, Color b) {
  final lumA = a.computeLuminance();
  final lumB = b.computeLuminance();
  final brightest = lumA > lumB ? lumA : lumB;
  final darkest = lumA > lumB ? lumB : lumA;
  return (brightest + 0.05) / (darkest + 0.05);
}
