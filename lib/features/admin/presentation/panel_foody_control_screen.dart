import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/core/tema/tema_mode_provider.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/admin/data/super_admin_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/foody_control_repartidores_vista.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/foody_control_ui.dart';

/// Panel super admin — Foody Control (multi-restaurante).
class PanelFoodyControlScreen extends StatefulWidget {
  const PanelFoodyControlScreen({super.key});

  @override
  State<PanelFoodyControlScreen> createState() =>
      _PanelFoodyControlScreenState();
}

class _PanelFoodyControlScreenState extends State<PanelFoodyControlScreen> {
  final _repo = SuperAdminRepository();
  String _seccion = 'resumen';
  int _refreshTick = 0;

  void _ir(String id) => setState(() => _seccion = id);

  void _refrescar() => setState(() => _refreshTick++);

  String get _tituloSeccion {
    for (final s in FoodyControlUi.secciones) {
      if (s.id == _seccion) return s.titulo;
    }
    return 'Foody Control';
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esMovil = FoodyBreakpoints.esCompact(ancho);
    final railExtendido = FoodyBreakpoints.esLarge(ancho);
    final scheme = Theme.of(context).colorScheme;
    final oscuro = scheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: SaaSTokens.canvas(context),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: esMovil ? 60 : 68,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        leading: esMovil
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Abrir menú de plataforma',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: Scaffold.of(context).openDrawer,
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Foody Control',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              _tituloSeccion,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
            icon: Icon(
                oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => ProviderScope.containerOf(context)
                .read(temaModeProvider.notifier)
                .alternar(),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refrescar,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => cerrarSesionStaff(context),
          ),
        ],
      ),
      drawer: esMovil
          ? Drawer(
              width: (ancho * 0.85).clamp(0.0, 320.0),
              child: Builder(
                  builder: (drawerContext) => _NavFoodyControl(
                        seccion: _seccion,
                        extendido: true,
                        onSeleccionar: (id) {
                          _ir(id);
                          Scaffold.of(drawerContext).closeDrawer();
                        },
                      )),
            )
          : null,
      body: Row(
        children: [
          if (!esMovil)
            SizedBox(
              width: railExtendido ? 232 : 72,
              child: _NavFoodyControl(
                seccion: _seccion,
                extendido: railExtendido,
                onSeleccionar: _ir,
              ),
            ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SaaSTokens.canvas(context),
                border: Border(
                    left: esMovil
                        ? BorderSide.none
                        : BorderSide(color: scheme.outlineVariant)),
              ),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('$_seccion-$_refreshTick'),
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, valor, child) => Opacity(
                  opacity: 0.76 + valor * 0.24,
                  child: child,
                ),
                child: _ContenidoFoodyControl(seccion: _seccion, repo: _repo),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavFoodyControl extends StatelessWidget {
  const _NavFoodyControl({
    required this.seccion,
    required this.extendido,
    required this.onSeleccionar,
  });

  final String seccion;
  final bool extendido;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FoodyControlUi.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                extendido ? 16 : 12, 20, extendido ? 16 : 12, 12),
            child: extendido
                ? Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ColoresFoody.primario,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.hub_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Plataforma Foody',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ColoresFoody.primario,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.hub_rounded, color: Colors.white),
                    ),
                  ),
          ),
          const Divider(color: FoodyControlUi.borde, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                for (final s in FoodyControlUi.secciones)
                  _itemNav(context, s.id, s.titulo, s.icono),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemNav(
      BuildContext context, String id, String titulo, IconData icono) {
    final sel = seccion == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
          button: true,
          selected: sel,
          label: extendido ? null : titulo,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSeleccionar(id),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: extendido ? 12 : 8,
                  vertical: extendido ? 11 : 12,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? ColoresFoody.primario.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: sel
                      ? Border.all(
                          color: ColoresFoody.primario.withValues(alpha: 0.35),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: extendido
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      icono,
                      size: 22,
                      color: sel ? ColoresFoody.primario : Colors.white60,
                    ),
                    if (extendido) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          titulo,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )),
    );
  }
}

class _ContenidoFoodyControl extends StatelessWidget {
  const _ContenidoFoodyControl({
    required this.seccion,
    required this.repo,
  });

  final String seccion;
  final SuperAdminRepository repo;

  @override
  Widget build(BuildContext context) {
    switch (seccion) {
      case 'restaurantes':
        return _VistaRestaurantes(repo: repo);
      case 'planes':
        return _VistaPlanes(repo: repo);
      case 'usuarios':
        return _VistaUsuarios(repo: repo);
      case 'ciudades':
        return _VistaCiudades(repo: repo);
      case 'config':
        return _VistaConfig(repo: repo);
      case 'repartidores':
        return FoodyControlRepartidoresVista(repo: repo);
      default:
        return _VistaResumen(repo: repo);
    }
  }
}

// ─── Resumen ───────────────────────────────────────────────────────────────

class _VistaResumen extends StatefulWidget {
  const _VistaResumen({required this.repo});
  final SuperAdminRepository repo;

  @override
  State<_VistaResumen> createState() => _VistaResumenState();
}

class _VistaResumenState extends State<_VistaResumen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.resumen();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.resumen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final moneda =
        NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCarga(
            mensaje: mensajeErrorHttp(snap.error!, contexto: 'resumen'),
            onReintentar: _recargar,
          );
        }
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: AnaliticaSkeleton.seccion(
                etiqueta: 'Cargando datos de la plataforma'),
          );
        }
        final d = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Vista general de la plataforma',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FoodyControlTarjetaKpi(
                  titulo: 'Restaurantes',
                  valor: '${d['restaurantes_activos'] ?? 0}',
                  icono: Icons.storefront_outlined,
                ),
                FoodyControlTarjetaKpi(
                  titulo: 'Sucursales',
                  valor: '${d['sucursales_activas'] ?? 0}',
                  icono: Icons.store_mall_directory_outlined,
                  color: ColoresFoody.secundario,
                ),
                FoodyControlTarjetaKpi(
                  titulo: 'Ciudades',
                  valor: '${d['ciudades_activas'] ?? 0}',
                  icono: Icons.location_city_outlined,
                ),
                FoodyControlTarjetaKpi(
                  titulo: 'Pedidos hoy',
                  valor: '${d['pedidos_hoy'] ?? 0}',
                  icono: Icons.receipt_long_outlined,
                ),
                FoodyControlTarjetaKpi(
                  titulo: 'Ingresos Foody hoy',
                  valor: moneda.format(d['ingresos_foody_hoy'] ?? 0),
                  icono: Icons.payments_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Self-service (F7)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final ss = d['self_service'] as Map<String, dynamic>?;
                if (ss == null) return const SizedBox.shrink();
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FoodyControlTarjetaKpi(
                      titulo: 'Registros auto',
                      valor: '${ss['registros_self_service'] ?? 0}',
                      icono: Icons.person_add_outlined,
                    ),
                    FoodyControlTarjetaKpi(
                      titulo: 'Pagos 30 días',
                      valor: '${ss['pagos_aprobados_30d'] ?? 0}',
                      icono: Icons.credit_card_outlined,
                      color: ColoresFoody.secundario,
                    ),
                    FoodyControlTarjetaKpi(
                      titulo: 'Conversión',
                      valor: '${ss['tasa_conversion_pagos_pct'] ?? 0}%',
                      icono: Icons.trending_up,
                    ),
                    FoodyControlTarjetaKpi(
                      titulo: 'Ingresos 30 días',
                      valor: moneda.format(ss['ingresos_cop_30d'] ?? 0),
                      icono: Icons.attach_money,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Suscripciones',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...(d['suscripciones'] as List<dynamic>? ?? []).map((s) {
              final map = Map<String, dynamic>.from(s as Map);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: FoodyControlUi.colorEstado('${map['estado']}'),
                  ),
                  title:
                      Text(FoodyControlUi.etiquetaEstado('${map['estado']}')),
                  trailing: Text('${map['total'] ?? 0} restaurantes'),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ─── Restaurantes ──────────────────────────────────────────────────────────

class _VistaRestaurantes extends StatefulWidget {
  const _VistaRestaurantes({required this.repo});
  final SuperAdminRepository repo;

  @override
  State<_VistaRestaurantes> createState() => _VistaRestaurantesState();
}

class _VistaRestaurantesState extends State<_VistaRestaurantes> {
  late Future<List<Map<String, dynamic>>> _future;
  final _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.restaurantes();
    });
  }

  Future<void> _crearRestaurante() async {
    List<Map<String, dynamic>> ciudades = [];
    try {
      ciudades = await widget.repo.ciudades();
    } catch (e) {
      if (mounted) {
        _snack(mensajeErrorHttp(e, contexto: 'ciudades'));
      }
      return;
    }
    if (!mounted) return;
    if (ciudades.isEmpty) {
      _snack('Crea una ciudad primero (pestaña Ciudades)');
      return;
    }

    String? ciudadId = ciudades.first['id'] as String?;
    final restCtrl = TextEditingController();
    final sucCtrl = TextEditingController(text: 'Sede principal');
    final dirCtrl = TextEditingController();
    final adminCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formulario = GlobalKey<FormState>();
    String? requerido(String? valor) =>
        (valor?.trim().isEmpty ?? true) ? 'Completa este campo' : null;

    final confirmado = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo restaurante'),
          scrollable: true,
          content: SizedBox(
            width: 420,
            child: Form(
              key: formulario,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: ciudadId,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      border: OutlineInputBorder(),
                    ),
                    items: ciudades
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['nombre'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => ciudadId = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: restCtrl,
                    validator: requerido,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del restaurante',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sucCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Primera sucursal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dirCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Administrador inicial',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: adminCtrl,
                    validator: requerido,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    validator: (valor) {
                      final correo = valor?.trim() ?? '';
                      return correo.contains('@') && !correo.endsWith('@')
                          ? null
                          : 'Escribe un correo válido';
                    },
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passCtrl,
                    validator: (valor) => (valor?.trim().length ?? 0) < 6
                        ? 'Escribe al menos 6 caracteres'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if ((formulario.currentState?.validate() ?? false) &&
                    ciudadId != null) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Crear restaurante'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true || ciudadId == null || !mounted) {
      restCtrl.dispose();
      sucCtrl.dispose();
      dirCtrl.dispose();
      adminCtrl.dispose();
      emailCtrl.dispose();
      passCtrl.dispose();
      return;
    }

    final nombreRest = restCtrl.text.trim();
    final emailAdmin = emailCtrl.text.trim();
    final nombreSuc =
        sucCtrl.text.trim().isEmpty ? 'Sede principal' : sucCtrl.text.trim();
    final direccion = dirCtrl.text.trim();
    final adminNombre = adminCtrl.text.trim();
    final contrasena = passCtrl.text.trim();

    restCtrl.dispose();
    sucCtrl.dispose();
    dirCtrl.dispose();
    adminCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();

    try {
      final res = await foodyControlConCarga(
        context,
        () => widget.repo.crearRestaurante(
          ciudadId: ciudadId!,
          nombreRestaurante: nombreRest,
          nombreSucursal: nombreSuc,
          direccionSucursal: direccion.isEmpty ? null : direccion,
          adminNombre: adminNombre,
          adminEmail: emailAdmin,
          adminContrasena: contrasena,
        ),
        mensaje: 'Creando restaurante y admin…\nPuede tardar unos segundos.',
      );
      _recargar();
      if (mounted) {
        _snack(
          '✓ ${res?['admin_email'] ?? emailAdmin} · plan prueba 14 días',
          color: ColoresFoody.exito,
        );
      }
    } catch (e) {
      _recargar();
      if (mounted) {
        try {
          final existe =
              await widget.repo.existeRestaurantePorNombre(nombreRest);
          if (existe) {
            _snack(
              'El restaurante «$nombreRest» sí se creó (hubo error de red al confirmar).',
              color: Colors.orange.shade800,
            );
            return;
          }
        } catch (_) {}
        _snack(mensajeErrorHttp(e, contexto: 'crear restaurante'));
      }
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _editarPlanRapido(Map<String, dynamic> r) async {
    final susId = r['suscripcion_id'] as String?;
    if (susId == null) return;
    var plan = r['suscripcion_plan'] as String? ?? 'basico';
    var estado = r['suscripcion_estado'] as String? ?? 'prueba';

    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Plan · ${r['nombre']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: plan,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: FoodyControlUi.planes
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(FoodyControlUi.etiquetaPlan(p)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => plan = v ?? plan),
              ),
              DropdownButtonFormField<String>(
                initialValue: estado,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: FoodyControlUi.estadosSuscripcion
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(FoodyControlUi.etiquetaEstado(e)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => estado = v ?? estado),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo
          .actualizarSuscripcion(susId, estado: estado, plan: plan);
      _recargar();
      _snack('Plan actualizado');
    } catch (e) {
      _snack(mensajeErrorHttp(e, contexto: 'plan'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            FoodyControlBarraBusqueda(
              controller: _busqueda,
              hint: 'Buscar restaurante…',
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _ErrorCarga(
                      mensaje: mensajeErrorHttp(snap.error!,
                          contexto: 'restaurantes'),
                      onReintentar: _recargar,
                    );
                  }
                  if (!snap.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: AnaliticaSkeleton.seccion(
                          etiqueta: 'Cargando datos de la plataforma'),
                    );
                  }
                  final q = _busqueda.text.trim().toLowerCase();
                  final lista = snap.data!.where((r) {
                    if (q.isEmpty) return true;
                    return (r['nombre'] as String? ?? '')
                        .toLowerCase()
                        .contains(q);
                  }).toList();

                  if (lista.isEmpty) {
                    return const Center(child: Text('Sin restaurantes'));
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _recargar(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final r = lista[i];
                        final activo = r['activo'] != false;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              r['nombre'] as String? ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  '${r['ciudad_nombre']} · '
                                  '${r['sucursales_activas'] ?? 0} sucursal(es)',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                FoodyControlChipEstado(
                                  estado: r['suscripcion_estado'] as String?,
                                  plan: r['suscripcion_plan'] as String?,
                                ),
                                if (!activo)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Restaurante desactivado',
                                      style: TextStyle(
                                        color: ColoresFoody.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'plan') {
                                  await _editarPlanRapido(r);
                                } else if (v == 'toggle') {
                                  try {
                                    await widget.repo.actualizarRestaurante(
                                      '${r['id']}',
                                      activo: !activo,
                                    );
                                    _recargar();
                                  } catch (e) {
                                    _snack(mensajeErrorHttp(e));
                                  }
                                } else if (v == 'suscripcion') {
                                  final susId = r['suscripcion_id'] as String?;
                                  if (susId == null) return;
                                  final est =
                                      r['suscripcion_estado'] == 'activa'
                                          ? 'bloqueada'
                                          : 'activa';
                                  try {
                                    await widget.repo.actualizarSuscripcion(
                                        susId,
                                        estado: est);
                                    _recargar();
                                  } catch (e) {
                                    _snack(mensajeErrorHttp(e));
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'plan', child: Text('Editar plan')),
                                PopupMenuItem(
                                  value: 'suscripcion',
                                  child: Text(
                                    r['suscripcion_estado'] == 'activa'
                                        ? 'Bloquear suscripción'
                                        : 'Activar suscripción',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(activo
                                      ? 'Desactivar restaurante'
                                      : 'Activar restaurante'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FilledButton.icon(
            onPressed: _crearRestaurante,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Nuevo restaurante'),
          ),
        ),
      ],
    );
  }
}

// ─── Planes ────────────────────────────────────────────────────────────────

class _VistaPlanes extends StatefulWidget {
  const _VistaPlanes({required this.repo});
  final SuperAdminRepository repo;

  @override
  State<_VistaPlanes> createState() => _VistaPlanesState();
}

class _VistaPlanesState extends State<_VistaPlanes> {
  late Future<List<Map<String, dynamic>>> _future;
  final _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.suscripciones();
    });
  }

  Future<void> _editar(Map<String, dynamic> s) async {
    var plan = s['plan'] as String? ?? 'basico';
    var estado = s['estado'] as String? ?? 'prueba';
    final vence = DateTime.tryParse('${s['fecha_vencimiento']}');
    var fechaVence = vence ?? DateTime.now().add(const Duration(days: 14));

    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${s['restaurante_nombre']}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: plan,
                  decoration: const InputDecoration(
                    labelText: 'Plan',
                    border: OutlineInputBorder(),
                  ),
                  items: FoodyControlUi.planes
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(FoodyControlUi.etiquetaPlan(p)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => plan = v ?? plan),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: FoodyControlUi.estadosSuscripcion
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(FoodyControlUi.etiquetaEstado(e)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => estado = v ?? estado),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vence'),
                  subtitle: Text(DateFormat.yMMMd('es').format(fechaVence)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: fechaVence,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setLocal(() => fechaVence = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Aplicar plan')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      await widget.repo.actualizarSuscripcion(
        '${s['id']}',
        estado: estado,
        plan: plan,
        fechaVencimientoIso: fechaVence.toUtc().toIso8601String(),
      );
      _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan aplicado al restaurante')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'plan'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd('es');
    return Column(
      children: [
        FoodyControlBarraBusqueda(
          controller: _busqueda,
          hint: 'Buscar por restaurante…',
          onChanged: (_) => setState(() {}),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorCarga(
                  mensaje: mensajeErrorHttp(snap.error!, contexto: 'planes'),
                  onReintentar: _recargar,
                );
              }
              if (!snap.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnaliticaSkeleton.seccion(
                      etiqueta: 'Cargando datos de la plataforma'),
                );
              }
              final q = _busqueda.text.trim().toLowerCase();
              final lista = snap.data!.where((s) {
                if (q.isEmpty) return true;
                return (s['restaurante_nombre'] as String? ?? '')
                    .toLowerCase()
                    .contains(q);
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => _recargar(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final s = lista[i];
                    final vence =
                        DateTime.tryParse('${s['fecha_vencimiento']}');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          s['restaurante_nombre'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            FoodyControlChipEstado(
                              estado: s['estado'] as String?,
                              plan: s['plan'] as String?,
                            ),
                            if (vence != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Vence: ${fmt.format(vence)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar plan',
                          onPressed: () => _editar(s),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Usuarios ──────────────────────────────────────────────────────────────

class _VistaUsuarios extends StatefulWidget {
  const _VistaUsuarios({required this.repo});
  final SuperAdminRepository repo;

  @override
  State<_VistaUsuarios> createState() => _VistaUsuariosState();
}

class _VistaUsuariosState extends State<_VistaUsuarios> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _restaurantesFuture;
  final _busqueda = TextEditingController();
  String _filtroRestaurante = '';

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.usuarios();
      _restaurantesFuture = widget.repo.restaurantes();
    });
  }

  Future<void> _crearUsuario() async {
    final List<Map<String, dynamic>> restaurantes;
    try {
      restaurantes = await widget.repo.restaurantes();
    } catch (error) {
      if (mounted) mostrarErrorSnackBar(context, error);
      return;
    }
    if (!mounted) return;
    if (restaurantes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea un restaurante primero')),
      );
      return;
    }

    final resultado = await FoodyDialogo.mostrar<Map<String, String>>(
      context: context,
      builder: (ctx) => _DialogoCrearUsuario(
        restaurantes: restaurantes,
        repo: widget.repo,
      ),
    );
    if (mounted && resultado != null) {
      try {
        await foodyControlConCarga(
          context,
          () => widget.repo.crearUsuario(
            nombre: resultado['nombre']!,
            email: resultado['email']!,
            contrasena: resultado['contrasena']!,
            rol: resultado['rol']!,
            sucursalId: resultado['sucursal_id']!,
          ),
          mensaje: 'Creando usuario…',
        );
        if (mounted) {
          _recargar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario creado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'usuario'))),
          );
        }
      }
    }
  }

  Future<void> _editarUsuario(Map<String, dynamic> u) async {
    var rol = u['rol'] as String? ?? 'cajero';
    final nombreCtrl =
        TextEditingController(text: u['nombre'] as String? ?? '');
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Editar · ${u['email']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              DropdownButtonFormField<String>(
                initialValue: rol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: FoodyControlUi.rolesStaff
                    .map(
                        (r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) => setLocal(() => rol = v ?? rol),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      return;
    }
    try {
      await widget.repo.actualizarUsuario(
        '${u['id']}',
        nombre: nombreCtrl.text.trim(),
        rol: rol,
      );
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    }
    nombreCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _restaurantesFuture,
              builder: (context, snap) {
                final rests = snap.data ?? [];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _filtroRestaurante.isEmpty ? '' : _filtroRestaurante,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar restaurante',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos')),
                      ...rests.map(
                        (r) => DropdownMenuItem(
                          value: r['id'] as String,
                          child: Text(r['nombre'] as String? ?? ''),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _filtroRestaurante = v ?? ''),
                  ),
                );
              },
            ),
            FoodyControlBarraBusqueda(
              controller: _busqueda,
              hint: 'Buscar por nombre o correo…',
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: AnaliticaSkeleton.seccion(
                          etiqueta: 'Cargando datos de la plataforma'),
                    );
                  }
                  final q = _busqueda.text.trim().toLowerCase();
                  final lista = snap.data!.where((u) {
                    if (_filtroRestaurante.isNotEmpty &&
                        u['restaurante_id'] != _filtroRestaurante) {
                      return false;
                    }
                    if (q.isEmpty) return true;
                    final nombre = (u['nombre'] as String? ?? '').toLowerCase();
                    final email = (u['email'] as String? ?? '').toLowerCase();
                    return nombre.contains(q) || email.contains(q);
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: () async => _recargar(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final u = lista[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(u['nombre'] as String? ?? ''),
                            subtitle: Text(
                              '${u['email']}\n'
                              '${u['rol']} · ${u['restaurante_nombre'] ?? '—'} / '
                              '${u['sucursal_nombre'] ?? '—'}',
                            ),
                            isThreeLine: true,
                            trailing: Switch(
                              value: u['activo'] == true,
                              onChanged: (_) async {
                                try {
                                  await widget.repo.cambiarEstadoUsuario(
                                    '${u['id']}',
                                    u['activo'] != true,
                                  );
                                  _recargar();
                                } catch (e) {
                                  if (mounted) {
                                    mostrarErrorSnackBar(context, e);
                                  }
                                }
                              },
                            ),
                            onTap: () => _editarUsuario(u),
                            onLongPress: () async {
                              final passCtrl = TextEditingController();
                              final ok = await FoodyDialogo.mostrar<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Contraseña · ${u['email']}'),
                                  content: TextField(
                                    controller: passCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Nueva contraseña'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                          ctx, passCtrl.text.length >= 6),
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                try {
                                  await widget.repo.cambiarContrasenaUsuario(
                                    '${u['id']}',
                                    passCtrl.text.trim(),
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Contraseña actualizada')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    mostrarErrorSnackBar(context, e);
                                  }
                                }
                              }
                              passCtrl.dispose();
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FilledButton.icon(
            onPressed: _crearUsuario,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Nuevo usuario'),
          ),
        ),
      ],
    );
  }
}

// ─── Ciudades, Config, Repartidores (compactos) ───────────────────────────

class _VistaCiudades extends StatefulWidget {
  const _VistaCiudades({required this.repo});
  final SuperAdminRepository repo;

  @override
  State<_VistaCiudades> createState() => _VistaCiudadesState();
}

class _VistaCiudadesState extends State<_VistaCiudades> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.ciudades();
    });
  }

  Future<void> _nueva() async {
    final nombreCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva ciudad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            TextField(
              controller: slugCtrl,
              decoration: const InputDecoration(
                labelText: 'Slug (opcional)',
                hintText: 'auto desde nombre',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, nombreCtrl.text.trim().isNotEmpty),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.repo.crearCiudad(
          nombre: nombreCtrl.text.trim(),
          slug: slugCtrl.text.trim().isEmpty ? null : slugCtrl.text.trim(),
        );
        _recargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e))),
          );
        }
      }
    }
    nombreCtrl.dispose();
    slugCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: AnaliticaSkeleton.seccion(
                    etiqueta: 'Cargando datos de la plataforma'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _recargar(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: snap.data!.length,
                itemBuilder: (_, i) {
                  final c = snap.data![i];
                  return Card(
                    child: ListTile(
                      title: Text(c['nombre'] as String? ?? ''),
                      subtitle: Text(
                        'slug: ${c['slug']} · ${c['restaurantes']} restaurantes',
                      ),
                      trailing: Switch(
                        value: c['activa'] == true,
                        onChanged: (_) async {
                          try {
                            await widget.repo.actualizarCiudad(
                              '${c['id']}',
                              activa: c['activa'] != true,
                            );
                            _recargar();
                          } catch (e) {
                            if (mounted) {
                              mostrarErrorSnackBar(context, e);
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FilledButton.icon(
            onPressed: _nueva,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Nueva ciudad'),
          ),
        ),
      ],
    );
  }
}

class _VistaConfig extends StatefulWidget {
  const _VistaConfig({required this.repo});
  final SuperAdminRepository repo;

  @override
  State<_VistaConfig> createState() => _VistaConfigState();
}

class _VistaConfigState extends State<_VistaConfig> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.configuracion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: AnaliticaSkeleton.seccion(
                etiqueta: 'Cargando datos de la plataforma'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.length,
          itemBuilder: (_, i) {
            final c = snap.data![i];
            return Card(
              child: ListTile(
                title: Text('${c['clave']}'),
                subtitle:
                    Text('${c['descripcion'] ?? ''}\nValor: ${c['valor']}'),
                isThreeLine: true,
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final ctrl = TextEditingController(text: '${c['valor']}');
                  final ok = await FoodyDialogo.mostrar<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('${c['clave']}'),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(labelText: 'Valor'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    try {
                      await widget.repo.actualizarConfiguracion(
                        '${c['clave']}',
                        ctrl.text.trim(),
                      );
                      _recargar();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configuración guardada'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(mensajeErrorHttp(e))),
                        );
                      }
                    }
                  }
                  ctrl.dispose();
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _DialogoCrearUsuario extends StatefulWidget {
  const _DialogoCrearUsuario({
    required this.restaurantes,
    required this.repo,
  });

  final List<Map<String, dynamic>> restaurantes;
  final SuperAdminRepository repo;

  @override
  State<_DialogoCrearUsuario> createState() => _DialogoCrearUsuarioState();
}

class _DialogoCrearUsuarioState extends State<_DialogoCrearUsuario> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  String? _restauranteId;
  String? _sucursalId;
  String _rol = 'cajero';
  List<Map<String, dynamic>> _sucursales = [];
  bool _cargandoSucursales = false;
  String? _errorSucursales;

  @override
  void initState() {
    super.initState();
    _cambiarRestaurante(widget.restaurantes.first['id'] as String?);
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _cambiarRestaurante(String? id) async {
    setState(() {
      _restauranteId = id;
      _sucursalId = null;
      _sucursales = [];
      _cargandoSucursales = true;
      _errorSucursales = null;
    });
    if (id == null) {
      setState(() => _cargandoSucursales = false);
      return;
    }
    try {
      final lista = await widget.repo.sucursalesRestaurante(id);
      if (!mounted || _restauranteId != id) return;
      setState(() {
        _sucursales = lista;
        _sucursalId = lista.isNotEmpty ? lista.first['id'] as String? : null;
        _cargandoSucursales = false;
      });
    } catch (e) {
      if (mounted && _restauranteId == id) {
        setState(() {
          _cargandoSucursales = false;
          _errorSucursales = mensajeErrorHttp(e, contexto: 'sucursales');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo usuario staff'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _restauranteId,
                  decoration: const InputDecoration(
                    labelText: 'Restaurante',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.restaurantes
                      .map(
                        (r) => DropdownMenuItem(
                          value: r['id'] as String,
                          child: Text(r['nombre'] as String? ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: _cambiarRestaurante,
                ),
                const SizedBox(height: 10),
                if (_cargandoSucursales)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  )
                else if (_errorSucursales != null)
                  TextButton(
                    onPressed: () => _cambiarRestaurante(_restauranteId),
                    child: Text('$_errorSucursales Reintentar'),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_restauranteId),
                    initialValue: _sucursalId,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal',
                      border: OutlineInputBorder(),
                    ),
                    items: _sucursales
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['nombre'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _sucursalId = v),
                    validator: (v) =>
                        v == null ? 'Selecciona una sucursal' : null,
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _rol,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: FoodyControlUi.rolesStaff
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.$1,
                          child: Text(r.$2),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _rol = v ?? _rol),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 2 ? 'Escribe el nombre' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim() ?? '').contains('@')
                      ? null
                      : 'Escribe un correo válido',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contrasena,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (v) => (v?.trim().length ?? 0) < 6
                      ? 'Escribe al menos 6 caracteres'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _cargandoSucursales || _errorSucursales != null
              ? null
              : () {
                  if (!_formulario.currentState!.validate()) return;
                  Navigator.pop(context, {
                    'sucursal_id': _sucursalId!,
                    'rol': _rol,
                    'nombre': _nombre.text.trim(),
                    'email': _email.text.trim(),
                    'contrasena': _contrasena.text.trim(),
                  });
                },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
