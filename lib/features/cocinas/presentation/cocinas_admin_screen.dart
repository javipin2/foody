import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';

/// Gestión de cocinas e impresoras de la sucursal (admin/gerente).
///
/// UX: header denso, KPIs de riesgo (sin impresora), dual Cocinas‖Impresoras
/// en escritorio, cards con badges, FoodyDialogo con dispose seguro.
class CocinasAdminScreen extends StatefulWidget {
  const CocinasAdminScreen({
    super.key,
    required this.sucursalId,
    this.onIrKds,
  });

  final String? sucursalId;

  /// NAV-ADM2-13: atajo a cocina en vivo.
  final VoidCallback? onIrKds;

  @override
  State<CocinasAdminScreen> createState() => _CocinasAdminScreenState();
}

class _CocinasAdminScreenState extends State<CocinasAdminScreen> {
  final _repo = CocinasRepository();
  List<Map<String, dynamic>> _cocinas = [];
  List<Map<String, dynamic>> _impresoras = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant CocinasAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal asignada';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cocinas = await _repo.listarCocinas(sucursalId);
      final impresoras = await _repo.listarImpresoras(sucursalId);
      if (!mounted) return;
      setState(() {
        _cocinas = cocinas;
        _impresoras = impresoras;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar cocinas');
      });
    }
  }

  void _avisar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? AnaliticaTokens.alertas : AnaliticaTokens.ink,
      ),
    );
  }

  List<Map<String, dynamic>> get _cocinasActivas =>
      _cocinas.where((c) => c['activa'] == true).toList();

  int get _sinImpresora => _cocinasActivas.where((c) {
        final n = int.tryParse('${c['impresoras'] ?? 0}') ?? 0;
        return n == 0;
      }).length;

  // ----------------------------- Cocinas -----------------------------

  Future<void> _dialogoCocina({Map<String, dynamic>? cocina}) async {
    final nombre = await FoodyDialogo.mostrar<String>(
      context: context,
      builder: (ctx) => _DialogoNombreCocina(
        titulo: cocina == null ? 'Nueva cocina' : 'Editar cocina',
        inicial: cocina?['nombre'] as String? ?? '',
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      if (cocina != null) {
        await _repo.actualizarCocina(
          cocinaId: cocina['id'] as String,
          nombre: nombre,
        );
      } else {
        await _repo.crearCocina(
          sucursalId: widget.sucursalId!,
          nombre: nombre,
        );
      }
      _avisar('Cocina guardada');
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar cocina'), error: true);
    }
  }

  Future<void> _toggleCocina(Map<String, dynamic> cocina) async {
    final activa = cocina['activa'] == true;
    try {
      await _repo.actualizarCocina(
        cocinaId: cocina['id'] as String,
        activa: !activa,
      );
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'cambiar cocina'), error: true);
    }
  }

  Future<void> _confirmarEliminarCocina(Map<String, dynamic> cocina) async {
    final nombre = cocina['nombre'] as String? ?? 'esta cocina';
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cocina'),
        content: Text(
          '¿Desactivar «$nombre»? Los productos quedarán sin cocina asignada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.alertas,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.desactivarCocina(cocina['id'] as String);
      _avisar('Cocina eliminada');
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'eliminar cocina'), error: true);
    }
  }

  Future<void> _confirmarEliminarImpresora(
    Map<String, dynamic> impresora,
  ) async {
    final nombre = impresora['nombre'] as String? ?? 'esta impresora';
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar impresora'),
        content: Text('¿Desactivar «$nombre»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.alertas,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.desactivarImpresora(impresora['id'] as String);
      _avisar('Impresora eliminada');
      await _cargar();
    } catch (e) {
      _avisar(
        mensajeErrorHttp(e, contexto: 'eliminar impresora'),
        error: true,
      );
    }
  }

  // ---------------------------- Impresoras ----------------------------

  Future<void> _dialogoImpresora({
    Map<String, dynamic>? impresora,
    String? cocinaPrefill,
  }) async {
    if (_cocinasActivas.isEmpty) {
      _avisar('Crea una cocina antes de añadir impresoras', error: true);
      return;
    }
    final datos = await FoodyDialogo.mostrar<_DatosImpresora>(
      context: context,
      builder: (ctx) => _DialogoImpresora(
        cocinas: _cocinasActivas,
        inicial: impresora,
        cocinaPrefill: cocinaPrefill,
      ),
    );
    if (datos == null) return;
    try {
      if (impresora != null) {
        await _repo.actualizarImpresora(
          impresoraId: impresora['id'] as String,
          nombre: datos.nombre,
          cocinaId: datos.cocinaId,
          ipLocal: datos.ipLocal,
          tipo: datos.tipo,
        );
      } else {
        await _repo.crearImpresora(
          sucursalId: widget.sucursalId!,
          cocinaId: datos.cocinaId,
          nombre: datos.nombre,
          ipLocal: datos.ipLocal,
          tipo: datos.tipo,
        );
      }
      _avisar('Impresora guardada');
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar impresora'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final dual = ancho >= 980;

    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: SaasScrollableShell(
        header: [
          _header(compacto: !dual),
        ],
        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(
                  color: AnaliticaTokens.inkMuted,
                ),
              )
            : _error != null
                ? _estadoError()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: AnaliticaTokens.ink,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        _kpis(),
                        const SizedBox(height: 8),
                        if (dual)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _bloqueCocinas()),
                              const SizedBox(width: 16),
                              Expanded(child: _bloqueImpresoras()),
                            ],
                          )
                        else ...[
                          _bloqueCocinas(),
                          const SizedBox(height: 20),
                          _bloqueImpresoras(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _header({required bool compacto}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cocinas e impresoras',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AnaliticaTokens.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estaciones para el KDS e impresión de tickets',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AnaliticaTokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onIrKds != null) ...[
            const SizedBox(width: 8),
            if (compacto)
              IconButton.outlined(
                tooltip: 'Cocina en vivo',
                onPressed: widget.onIrKds,
                icon: const Icon(Icons.kitchen_outlined),
              )
            else
              OutlinedButton.icon(
                onPressed: widget.onIrKds,
                icon: const Icon(Icons.kitchen_outlined, size: 18),
                label: const Text('Cocina en vivo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AnaliticaTokens.ink,
                  side: const BorderSide(color: AnaliticaTokens.border),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _kpis() {
    final activas = _cocinasActivas.length;
    final impresoras = _impresoras.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _kpiChip(
            '$activas ${_plural(activas, 'cocina', 'cocinas')}',
            AnaliticaTokens.cocina,
          ),
          _kpiChip(
            '$impresoras ${_plural(impresoras, 'impresora', 'impresoras')}',
            AnaliticaTokens.inkMuted,
          ),
          if (_sinImpresora > 0)
            _kpiChip(
              '$_sinImpresora sin impresora',
              AnaliticaTokens.alertas,
            ),
        ],
      ),
    );
  }

  Widget _kpiChip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AnaliticaTokens.border),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AnaliticaTokens.inkSoft,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AnaliticaTokens.ink,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargar,
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloqueCocinas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seccionTitulo(
          icono: Icons.soup_kitchen_rounded,
          titulo: 'Cocinas',
          accion: 'Nueva',
          onAccion: () => _dialogoCocina(),
        ),
        const SizedBox(height: 10),
        if (_cocinas.isEmpty)
          _vacio(
            icono: Icons.soup_kitchen_outlined,
            titulo: 'Sin estaciones',
            texto:
                'Crea al menos una cocina y asígnala a productos del menú para ver tickets en el KDS.',
            cta: 'Crear cocina',
            onCta: () => _dialogoCocina(),
          )
        else
          for (final c in _cocinas) ...[
            _cardCocina(c),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _bloqueImpresoras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seccionTitulo(
          icono: Icons.print_rounded,
          titulo: 'Impresoras',
          accion: 'Nueva',
          onAccion: () => _dialogoImpresora(),
        ),
        const SizedBox(height: 10),
        if (_impresoras.isEmpty)
          _vacio(
            icono: Icons.print_disabled_outlined,
            titulo: 'Sin impresoras',
            texto:
                'Asigna una impresora a cada cocina para imprimir tickets de pedidos.',
            cta: _cocinasActivas.isEmpty ? null : 'Añadir impresora',
            onCta: _cocinasActivas.isEmpty ? null : () => _dialogoImpresora(),
          )
        else
          for (final i in _impresoras) ...[
            _cardImpresora(i),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _seccionTitulo({
    required IconData icono,
    required String titulo,
    required String accion,
    required VoidCallback onAccion,
  }) {
    return Row(
      children: [
        Icon(icono, size: 20, color: AnaliticaTokens.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AnaliticaTokens.ink,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAccion,
          icon: const Icon(Icons.add, size: 16),
          label: Text(accion),
          style: FilledButton.styleFrom(
            backgroundColor: AnaliticaTokens.ink,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _vacio({
    required IconData icono,
    required String titulo,
    required String texto,
    String? cta,
    VoidCallback? onCta,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: AnaliticaTokens.border),
      ),
      child: Column(
        children: [
          Icon(icono, size: 36, color: AnaliticaTokens.inkSoft),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AnaliticaTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AnaliticaTokens.inkMuted,
            ),
          ),
          if (cta != null && onCta != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onCta,
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
              ),
              child: Text(cta),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardCocina(Map<String, dynamic> c) {
    final activa = c['activa'] == true;
    final productos = int.tryParse('${c['productos'] ?? 0}') ?? 0;
    final impresoras = int.tryParse('${c['impresoras'] ?? 0}') ?? 0;
    final sinImp = activa && impresoras == 0;
    final sinProd = activa && productos == 0;

    return Material(
      color: AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        onTap: () => _dialogoCocina(cocina: c),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(
              color: sinImp
                  ? AnaliticaTokens.alertas.withValues(alpha: 0.35)
                  : AnaliticaTokens.border,
            ),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: activa
                            ? AnaliticaTokens.cocina.withValues(alpha: 0.12)
                            : AnaliticaTokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.soup_kitchen_rounded,
                        size: 20,
                        color: activa
                            ? AnaliticaTokens.cocina
                            : AnaliticaTokens.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['nombre'] as String? ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: activa
                                  ? AnaliticaTokens.ink
                                  : AnaliticaTokens.inkSoft,
                            ),
                          ),
                          if (!activa)
                            const Text(
                              'Inactiva',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AnaliticaTokens.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Más',
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: AnaliticaTokens.inkMuted,
                      ),
                      onSelected: (a) {
                        if (a == 'editar') {
                          unawaited(_dialogoCocina(cocina: c));
                        } else if (a == 'impresora') {
                          unawaited(
                            _dialogoImpresora(
                              cocinaPrefill: c['id'] as String?,
                            ),
                          );
                        } else if (a == 'eliminar') {
                          unawaited(_confirmarEliminarCocina(c));
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Text('Editar nombre'),
                        ),
                        if (activa)
                          const PopupMenuItem(
                            value: 'impresora',
                            child: Text('Añadir impresora'),
                          ),
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Text(
                            'Eliminar',
                            style: TextStyle(color: AnaliticaTokens.alertas),
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: activa,
                      onChanged: (_) => _toggleCocina(c),
                      activeTrackColor: AnaliticaTokens.ink,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge(
                      '$productos prod.',
                      sinProd
                          ? AnaliticaTokens.alertas
                          : AnaliticaTokens.inkMuted,
                    ),
                    _badge(
                      '$impresoras impr.',
                      sinImp
                          ? AnaliticaTokens.alertas
                          : AnaliticaTokens.inkMuted,
                    ),
                    if (sinImp)
                      _badge('Sin impresora', AnaliticaTokens.alertas),
                    if (sinProd)
                      _badge('Sin productos', AnaliticaTokens.alertas),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardImpresora(Map<String, dynamic> i) {
    final activa = i['activa'] != false;
    final tipo = _tipoImpresoraTexto(i['tipo'] as String?);
    final ip = i['ip_local'] as String?;
    final cocina = i['cocina_nombre'] as String? ?? 'Sin cocina';

    return Material(
      color: AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        onTap: () => _dialogoImpresora(impresora: i),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    size: 20,
                    color: activa
                        ? AnaliticaTokens.ink
                        : AnaliticaTokens.inkSoft,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i['nombre'] as String? ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AnaliticaTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge(cocina, AnaliticaTokens.cocina),
                          _badge(tipo, AnaliticaTokens.inkMuted),
                          if (ip != null && ip.isNotEmpty)
                            _badge(ip, AnaliticaTokens.inkMuted),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más',
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AnaliticaTokens.inkMuted,
                  ),
                  onSelected: (a) {
                    if (a == 'editar') {
                      unawaited(_dialogoImpresora(impresora: i));
                    } else if (a == 'eliminar') {
                      unawaited(_confirmarEliminarImpresora(i));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'eliminar',
                      child: Text(
                        'Eliminar',
                        style: TextStyle(color: AnaliticaTokens.alertas),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String texto, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String _tipoImpresoraTexto(String? tipo) => switch (tipo) {
        'termica_red' => 'Térmica red',
        'termica_usb' => 'Térmica USB',
        'pdf' => 'PDF',
        _ => tipo ?? '—',
      };

  static String _plural(int n, String uno, String muchos) =>
      n == 1 ? uno : muchos;
}

// ---------------------------------------------------------------------------
// Diálogos (controllers viven en el State → dispose seguro)
// ---------------------------------------------------------------------------

class _DialogoNombreCocina extends StatefulWidget {
  const _DialogoNombreCocina({
    required this.titulo,
    required this.inicial,
  });

  final String titulo;
  final String inicial;

  @override
  State<_DialogoNombreCocina> createState() => _DialogoNombreCocinaState();
}

class _DialogoNombreCocinaState extends State<_DialogoNombreCocina> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Cocina asados, Barra de bebidas…',
          ),
          onSubmitted: (_) {
            final n = _ctrl.text.trim();
            if (n.isNotEmpty) Navigator.pop(context, n);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final n = _ctrl.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(context, n);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DatosImpresora {
  const _DatosImpresora({
    required this.nombre,
    required this.cocinaId,
    required this.tipo,
    required this.ipLocal,
  });

  final String nombre;
  final String cocinaId;
  final String tipo;
  final String ipLocal;
}

class _DialogoImpresora extends StatefulWidget {
  const _DialogoImpresora({
    required this.cocinas,
    this.inicial,
    this.cocinaPrefill,
  });

  final List<Map<String, dynamic>> cocinas;
  final Map<String, dynamic>? inicial;
  final String? cocinaPrefill;

  @override
  State<_DialogoImpresora> createState() => _DialogoImpresoraState();
}

class _DialogoImpresoraState extends State<_DialogoImpresora> {
  late final TextEditingController _nombre;
  late final TextEditingController _ip;
  late String _cocinaId;
  late String _tipo;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _nombre = TextEditingController(text: i?['nombre'] as String? ?? '');
    _ip = TextEditingController(text: i?['ip_local'] as String? ?? '');
    _cocinaId = i?['cocina_id'] as String? ??
        widget.cocinaPrefill ??
        widget.cocinas.first['id'] as String;
    _tipo = i?['tipo'] as String? ?? 'termica_red';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _ip.dispose();
    super.dispose();
  }

  void _guardar() {
    final n = _nombre.text.trim();
    if (n.isEmpty) return;
    Navigator.pop(
      context,
      _DatosImpresora(
        nombre: n,
        cocinaId: _cocinaId,
        tipo: _tipo,
        ipLocal: _ip.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.inicial != null;
    return AlertDialog(
      title: Text(esEdicion ? 'Editar impresora' : 'Nueva impresora'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombre,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _cocinaId,
                decoration: const InputDecoration(labelText: 'Cocina'),
                items: [
                  for (final c in widget.cocinas)
                    DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['nombre'] as String? ?? '—'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _cocinaId = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: 'termica_red',
                    child: Text('Térmica de red'),
                  ),
                  DropdownMenuItem(
                    value: 'termica_usb',
                    child: Text('Térmica USB'),
                  ),
                  DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _tipo = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ip,
                decoration: const InputDecoration(
                  labelText: 'IP local (opcional)',
                  hintText: '192.168.1.50',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
