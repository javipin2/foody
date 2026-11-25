import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';

const _destinos = [
  OperacionRoleNavItem(
    label: 'POS',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  ),
  OperacionRoleNavItem(
    label: 'Mesas',
    icon: Icons.table_restaurant_outlined,
    selectedIcon: Icons.table_restaurant,
  ),
  OperacionRoleNavItem(
    label: 'Caja',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
];

void main() {
  testWidgets('barra móvil conserva targets grandes y selecciona pestaña', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: OperacionRoleNavBar(
              destinations: _destinos,
              selectedIndex: selected,
              onDestinationSelected: (index) =>
                  setState(() => selected = index),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mesas = find.byKey(const ValueKey<String>('operacion-role-nav-1'));
    expect(tester.getSize(mesas).height, greaterThanOrEqualTo(56));
    await tester.tap(mesas);
    await tester.pumpAndSettle();

    expect(selected, 1);
    final semanticsData = tester.getSemantics(mesas).getSemanticsData();
    expect(semanticsData.label, 'Mesas');
    expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('barra superior mantiene una navegación compacta en tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(820, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OperacionRoleNavBar(
                destinations: _destinos,
                selectedIndex: 0,
                compactTop: true,
                onDestinationSelected: (_) {},
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('operacion-role-nav-0')),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
