import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/tema/tema_foody.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';
import 'package:reserva_canchas/features/usuarios/presentation/usuarios_admin_screen.dart';

class _UsuariosDePrueba extends UsuariosRepository {
  bool activo = true;
  int cambiosEstado = 0;

  @override
  Future<List<Map<String, dynamic>>> listar(String sucursalId) async => [
        {
          'id': 'usuario-1',
          'nombre': 'María del Equipo',
          'email': 'maria@example.test',
          'rol': 'cajero',
          'activo': activo,
          'cocina_nombre': null,
        },
      ];

  @override
  Future<CatalogoRolesResultado> catalogoRoles() async =>
      const CatalogoRolesResultado(
        roles: [
          {
            'rol': 'cajero',
            'permisos': ['crear_pedido']
          },
        ],
        permisosDisponibles: [],
      );

  @override
  Future<void> cambiarEstado({
    required String usuarioId,
    required String sucursalId,
    required bool activo,
  }) async {
    cambiosEstado++;
    this.activo = activo;
  }
}

class _SucursalesDePrueba extends SucursalesRepository {
  @override
  Future<List<Map<String, dynamic>>> listarMiRestaurante() async => [];
}

class _CocinasDePrueba extends CocinasRepository {
  @override
  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) async =>
      [];
}

void main() {
  for (final size in const [
    Size(390, 844),
    Size(820, 1180),
    Size(1440, 1000),
  ]) {
    testWidgets('usuarios cambia de patrón a ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: TemaFoody.claro(),
          home: Scaffold(
            body: UsuariosAdminScreen(
              sucursalId: 'sucursal-prueba',
              repository: _UsuariosDePrueba(),
              sucursalesRepository: _SucursalesDePrueba(),
              cocinasRepository: _CocinasDePrueba(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (size.width >= 1100) {
        expect(find.byType(DataTable), findsOneWidget);
        expect(find.text('Estación'), findsOneWidget);
      } else {
        expect(find.byType(DataTable), findsNothing);
      }
      expect(find.text('María del Equipo'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in const [390.0, 1440.0]) {
    testWidgets(
      'desactivar acceso requiere confirmación en ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final usuarios = _UsuariosDePrueba();

        await tester.pumpWidget(
          MaterialApp(
            theme: TemaFoody.claro(),
            home: Scaffold(
              body: UsuariosAdminScreen(
                sucursalId: 'sucursal-prueba',
                repository: usuarios,
                sucursalesRepository: _SucursalesDePrueba(),
                cocinasRepository: _CocinasDePrueba(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(find.text('¿Desactivar el acceso?'), findsOneWidget);
        expect(usuarios.cambiosEstado, 0);

        await tester.tap(
          find.byKey(const ValueKey<String>('usuario-mantener-activo')),
        );
        await tester.pumpAndSettle();
        expect(usuarios.cambiosEstado, 0);
        expect(usuarios.activo, isTrue);

        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('usuario-confirmar-desactivacion'),
          ),
        );
        await tester.pumpAndSettle();

        expect(usuarios.cambiosEstado, 1);
        expect(usuarios.activo, isFalse);
        expect(find.text('Inactivo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('explica el alcance real del permiso de pedidos', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: TemaFoody.claro(),
        home: Scaffold(
          body: UsuariosAdminScreen(
            sucursalId: 'sucursal-prueba',
            repository: _UsuariosDePrueba(),
            sucursalesRepository: _SucursalesDePrueba(),
            cocinasRepository: _CocinasDePrueba(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Crear y operar pedidos'), findsOneWidget);
    expect(
      find.text(
        'Incluye agregar o editar pedidos y solicitar cambios de estado válidos para el rol.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
