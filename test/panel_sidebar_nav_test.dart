import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_grupo.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/panel_sidebar_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<({MenuAdminGrupo grupo, List<MenuAdminItem> items})> _grupos() => [
      (
        grupo: const MenuAdminGrupo(
          id: 'configuracion',
          titulo: 'Configuración',
          subtitulo: 'Establecimiento y servicio',
          icono: Icons.settings_outlined,
          rutas: ['horarios', 'zonas'],
        ),
        items: const [
          MenuAdminItem(
            permiso: 'editar',
            titulo: 'Horarios',
            icono: Icons.schedule_outlined,
            ruta: 'horarios',
          ),
          MenuAdminItem(
            permiso: 'editar',
            titulo: 'Zonas',
            icono: Icons.map_outlined,
            ruta: 'zonas',
          ),
        ],
      ),
      (
        grupo: const MenuAdminGrupo(
          id: 'operacion',
          titulo: 'Operación',
          subtitulo: 'Pedidos y mesas',
          icono: Icons.receipt_long_outlined,
          rutas: ['pedidos', 'mesas'],
        ),
        items: const [
          MenuAdminItem(
            permiso: 'ver',
            titulo: 'Pedidos',
            icono: Icons.receipt_long_outlined,
            ruta: 'pedidos',
          ),
          MenuAdminItem(
            permiso: 'ver',
            titulo: 'Mesas',
            icono: Icons.table_restaurant_outlined,
            ruta: 'mesas',
          ),
        ],
      ),
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sidebar desktop conserva sección activa y acordeones',
      (tester) async {
    String? rutaElegida;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: PanelSidebarNav(
              grupos: _grupos(),
              seccionActiva: 'horarios',
              nombreUsuario: 'Javier',
              nombreSucursal: 'Sede principal',
              onSeleccionar: (ruta) => rutaElegida = ruta,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Foody'), findsOneWidget);
    expect(find.text('Sede principal'), findsOneWidget);
    expect(find.text('Horarios'), findsOneWidget);
    expect(find.text('Javier'), findsOneWidget);

    await tester.tap(find.text('Operación'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Mesas'), findsOneWidget);
    await tester.tap(find.text('Mesas'));
    await tester.pumpAndSettle();
    expect(rutaElegida, 'mesas');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar compacta navega desde el menú de grupo', (tester) async {
    tester.view.physicalSize = const Size(820, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? rutaElegida;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 72,
            child: PanelSidebarNav(
              grupos: _grupos(),
              seccionActiva: 'horarios',
              anchoCompacto: true,
              onSeleccionar: (ruta) => rutaElegida = ruta,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Configuración'));
    await tester.pumpAndSettle();
    expect(find.text('Horarios'), findsOneWidget);
    await tester.tap(find.text('Horarios'));
    await tester.pumpAndSettle();

    expect(rutaElegida, 'horarios');
    expect(tester.takeException(), isNull);
  });
}
