import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/features/analitica/data/analitica_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/analitica_filtros_sheet.dart';
import 'package:reserva_canchas/features/analitica/presentation/analitica_resumen_dashboard.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_chart_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_charts.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_header.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_kpi_card.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_surface.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/analitica/utils/analitica_export_foody.dart';
import 'package:share_plus/share_plus.dart';

/// Centro de Análisis — KPIs y series desde `/analitica/*` (solo UI).
class AnaliticaScreen extends StatefulWidget {
  const AnaliticaScreen({
    super.key,
    this.sucursalId,
    this.esCorporativo = false,
    this.puedeVerFinanzas = false,
    this.onIrReportes,
    this.tabInicial,
    this.repository,
  });

  final String? sucursalId;
  final bool esCorporativo;

  /// HUER-PERM-01: tab Rentabilidad exige `ver_finanzas`.
  final bool puedeVerFinanzas;

  /// NAV-ADM2-12: puente a Reportes exportables.
  final VoidCallback? onIrReportes;

  /// Deep-link desde Finanzas: `rentabilidad`.
  final String? tabInicial;
  final AnaliticaRepository? repository;

  @override
  State<AnaliticaScreen> createState() => _AnaliticaScreenState();
}

class _AnaliticaScreenState extends State<AnaliticaScreen>
    with SingleTickerProviderStateMixin {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final _repo = widget.repository ?? AnaliticaRepository();
  late TabController _tabs;

  String _preset = '7d';
  bool _comparar = true;
  String? _compararDesde;
  String? _compararHasta;
  String? _rangoDesde;
  String? _rangoHasta;
  AnaliticaFiltros _filtros = AnaliticaFiltros();
  bool _cargandoResumen = true;
  bool _cargandoComplementarios = false;
  String? _error;
  final _erroresComplementarios = <String, String>{};
  int _revisionCarga = 0;
  int _detallesPendientes = 0;

  Map<String, dynamic>? _resumen;
  Map<String, dynamic>? _ventasResumen;
  Map<String, dynamic>? _cocinasResumen;
  List<dynamic> _topProductos = [];
  List<dynamic> _menosProductos = [];
  List<dynamic> _pedidosRecientes = [];
  final _cache = <int, Map<String, dynamic>?>{};
  final _cargandoTab = <int, bool>{};
  DateTime _actualizadoEn = DateTime.now();

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static const _presets = [
    ('hoy', 'Hoy'),
    ('ayer', 'Ayer'),
    ('7d', '7 días'),
    ('30d', '30 días'),
    ('mes', 'Mes'),
    ('anio', 'Año'),
  ];

  int get _tabCount {
    var n = 8; // resumen..caja + riesgo
    if (widget.puedeVerFinanzas) n++;
    if (widget.esCorporativo) n++;
    return n;
  }

  int get _tabComparativaIndex => widget.esCorporativo ? _tabCount - 1 : -1;
  int get _tabRentabilidadIndex => widget.puedeVerFinanzas ? 7 : -1;
  int get _tabRiesgoIndex => widget.puedeVerFinanzas ? 8 : 7;

  List<String> get _tabLabels => [
        'Resumen',
        'Ventas',
        'Productos',
        'Cocinas',
        'Inventario',
        'Domicilios',
        'Caja',
        if (widget.puedeVerFinanzas) 'Rentabilidad',
        'Riesgo',
        if (widget.esCorporativo) 'Sedes',
      ];

  Map<String, dynamic> get _queryFiltros {
    final q = _filtros.toQuery();
    if (_comparar && _compararDesde != null && _compararHasta != null) {
      q['comparar_desde'] = _compararDesde;
      q['comparar_hasta'] = _compararHasta;
    }
    if (_preset == 'rango') {
      if (_rangoDesde != null) q['desde'] = _rangoDesde;
      if (_rangoHasta != null) q['hasta'] = _rangoHasta;
    }
    return q;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabCount, vsync: this);
    _tabs.addListener(_onTabChanged);
    _cargarResumen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _aplicarTabInicial());
  }

  @override
  void didUpdateWidget(covariant AnaliticaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      _cache.clear();
      _cargarResumen();
    }
    if (oldWidget.tabInicial != widget.tabInicial ||
        oldWidget.puedeVerFinanzas != widget.puedeVerFinanzas) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _aplicarTabInicial());
    }
  }

  void _aplicarTabInicial() {
    if (!mounted) return;
    if (widget.tabInicial == 'rentabilidad' && _tabRentabilidadIndex >= 0) {
      _tabs.animateTo(_tabRentabilidadIndex);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    _cargarTab(_tabs.index);
  }

  Future<void> _cargarResumen() async {
    final revision = ++_revisionCarga;
    final sid = widget.sucursalId;
    if (sid == null) {
      if (!mounted) return;
      setState(() {
        _cargandoResumen = false;
        _cargandoComplementarios = false;
        _detallesPendientes = 0;
        _erroresComplementarios.clear();
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() {
      _cargandoResumen = true;
      _cargandoComplementarios = false;
      _error = null;
      _erroresComplementarios.clear();
      _detallesPendientes = 0;
      _cache.clear();
      _cargandoTab.clear();
      _topProductos = [];
      _menosProductos = [];
      _ventasResumen = null;
      _cocinasResumen = null;
      _pedidosRecientes = [];
    });
    try {
      final f = _queryFiltros;
      final data = await _repo.resumen(
        sucursalId: sid,
        preset: _preset,
        comparar: _comparar,
        filtros: f,
      );
      if (!mounted || revision != _revisionCarga) return;
      setState(() {
        _resumen = data;
        _cache[0] = data;
        _cargandoResumen = false;
        _cargandoComplementarios = true;
        _erroresComplementarios.clear();
        _detallesPendientes = 4;
        // Estos endpoints también alimentan pestañas; no volver a solicitarlos
        // mientras ya estén llegando para el resumen.
        _cargandoTab[1] = true;
        _cargandoTab[2] = true;
        _cargandoTab[3] = true;
        _actualizadoEn = DateTime.now();
      });
      await _cargarComplementarios(revision, sid, f);
    } catch (e) {
      if (mounted && revision == _revisionCarga) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'análisis');
          _cargandoResumen = false;
          _cargandoComplementarios = false;
        });
      }
    }
  }

  Future<void> _cargarComplementarios(
    int revision,
    String sucursalId,
    Map<String, dynamic> filtros,
  ) async {
    final preset = _preset;
    final comparar = _comparar;
    await Future.wait([
      _cargarComplementario(
        revision,
        'ventas',
        () => _repo.ventas(
          sucursalId: sucursalId,
          preset: preset,
          comparar: comparar,
          filtros: filtros,
        ),
        (data) {
          _cache[1] = data;
          _ventasResumen = data;
          _cargandoTab[1] = false;
        },
      ),
      _cargarComplementario(
        revision,
        'productos',
        () => _repo.productos(
          sucursalId: sucursalId,
          preset: preset,
          comparar: comparar,
          filtros: filtros,
        ),
        (data) {
          _cache[2] = data;
          final ranking = data['por_cantidad'] as List<dynamic>? ?? [];
          final sinRotacion = data['sin_rotacion'] as List<dynamic>? ?? [];
          _topProductos = ranking.take(8).toList();
          _menosProductos = sinRotacion.isNotEmpty
              ? sinRotacion
              : (ranking.length > 4
                  ? ranking.reversed.take(6).toList()
                  : <dynamic>[]);
          _cargandoTab[2] = false;
        },
      ),
      _cargarComplementario(
        revision,
        'pedidos recientes',
        () => _repo.pedidosRecientes(
          sucursalId: sucursalId,
          preset: preset,
          filtros: filtros,
          limite: 15,
        ),
        (data) => _pedidosRecientes = data['pedidos'] as List<dynamic>? ?? [],
      ),
      _cargarComplementario(
        revision,
        'cocinas',
        () => _repo.cocinas(
          sucursalId: sucursalId,
          preset: preset,
          comparar: comparar,
          filtros: filtros,
        ),
        (data) {
          _cache[3] = data;
          _cocinasResumen = data;
          _cargandoTab[3] = false;
        },
      ),
    ]);
  }

  Future<void> _cargarComplementario(
    int revision,
    String nombre,
    Future<Map<String, dynamic>> Function() solicitar,
    void Function(Map<String, dynamic>) aplicar,
  ) async {
    try {
      final data = await solicitar();
      if (!mounted || revision != _revisionCarga) return;
      setState(() {
        aplicar(data);
        _terminarCargaComplementaria();
      });
    } catch (e) {
      if (!mounted || revision != _revisionCarga) return;
      setState(() {
        _erroresComplementarios[nombre] =
            mensajeErrorHttp(e, contexto: 'análisis');
        if (nombre == 'ventas') _cargandoTab[1] = false;
        if (nombre == 'productos') _cargandoTab[2] = false;
        if (nombre == 'cocinas') _cargandoTab[3] = false;
        _terminarCargaComplementaria();
      });
    }
  }

  void _terminarCargaComplementaria() {
    if (_detallesPendientes > 0) _detallesPendientes--;
    _cargandoComplementarios = _detallesPendientes > 0;
  }

  Future<void> _cargarTab(int index) async {
    if (index == 0 ||
        _cache.containsKey(index) ||
        _cargandoTab[index] == true ||
        (_cargandoResumen && index <= 3)) {
      return;
    }
    final revision = _revisionCarga;
    if (index == _tabComparativaIndex) {
      setState(() => _cargandoTab[index] = true);
      try {
        final data = await _repo.comparativaSedes(
          preset: _preset,
          filtros: _queryFiltros,
        );
        if (mounted && revision == _revisionCarga) {
          setState(() {
            _cache[index] = data;
            _cargandoTab[index] = false;
          });
        }
      } catch (e) {
        if (mounted && revision == _revisionCarga) {
          setState(() => _cargandoTab[index] = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'análisis'))),
          );
        }
      }
      return;
    }
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _cargandoTab[index] = true);
    try {
      final Map<String, dynamic> data;
      final f = _queryFiltros;
      final cmp = _comparar;
      if (index == 1) {
        data = await _repo.ventas(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == 2) {
        data = await _repo.productos(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == 3) {
        data = await _repo.cocinas(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == 4) {
        data = await _repo.inventario(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == 5) {
        data = await _repo.domiciliarios(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == 6) {
        data = await _repo.caja(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == _tabRentabilidadIndex) {
        data = await _repo.rentabilidad(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else if (index == _tabRiesgoIndex) {
        data = await _repo.riesgo(
          sucursalId: sid,
          preset: _preset,
          comparar: cmp,
          filtros: f,
        );
      } else {
        return;
      }
      if (mounted && revision == _revisionCarga) {
        setState(() {
          _cache[index] = data;
          _cargandoTab[index] = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _revisionCarga) {
        setState(() => _cargandoTab[index] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'análisis'))),
        );
      }
    }
  }

  Future<void> _recargarTodo() async {
    await _cargarResumen();
    final idx = _tabs.index;
    if (idx > 0 && !_cache.containsKey(idx)) {
      await _cargarTab(idx);
    }
  }

  void _cambiarPreset(String preset) {
    if (preset == 'rango') {
      _abrirRangoPersonalizado();
      return;
    }
    setState(() {
      _preset = preset;
      _rangoDesde = null;
      _rangoHasta = null;
    });
    _recargarTodo();
  }

  Future<void> _abrirRangoPersonalizado() async {
    final ahora = DateTime.now();
    final inicial = DateTimeRange(
      start: _rangoDesde != null
          ? DateTime.tryParse(_rangoDesde!) ??
              ahora.subtract(const Duration(days: 7))
          : ahora.subtract(const Duration(days: 7)),
      end: _rangoHasta != null
          ? DateTime.tryParse(_rangoHasta!) ?? ahora
          : ahora,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: ahora.add(const Duration(days: 1)),
      initialDateRange: inicial,
      helpText: 'Periodo personalizado',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() {
      _preset = 'rango';
      _rangoDesde = fmt(picked.start);
      _rangoHasta = fmt(picked.end);
    });
    _recargarTodo();
  }

  Future<void> _abrirFiltros() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final result = await mostrarAnaliticaFiltrosSheet(
      context: context,
      sucursalId: sid,
      filtrosIniciales: _filtros,
    );
    if (result != null && mounted) {
      setState(() => _filtros = result);
      _recargarTodo();
    }
  }

  Future<void> _exportarPdf() async {
    if (_resumen == null) return;
    final periodo = _resumen?['periodo'] as Map<String, dynamic>?;
    final label = periodo?['label'] as String? ?? _preset;
    List<dynamic> porTipo = [];
    final ventas = _cache[1];
    if (ventas != null) {
      porTipo = ventas['por_tipo'] as List<dynamic>? ?? [];
    } else {
      final sid = widget.sucursalId;
      if (sid != null) {
        try {
          final v = await _repo.ventas(
            sucursalId: sid,
            preset: _preset,
            comparar: _comparar,
            filtros: _queryFiltros,
          );
          porTipo = v['por_tipo'] as List<dynamic>? ?? [];
        } catch (_) {}
      }
    }
    try {
      final bytes = await AnaliticaExportFoody.generarPdf(
        periodoLabel: label,
        filtrosLabel: _filtros.etiquetaResumen(),
        resumen: _resumen,
        topProductos: _topProductos,
        porTipo: porTipo,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
              name: 'foody-analitica-$label.pdf',
            ),
          ],
          subject: 'Análisis Foody — $label',
        ),
      );
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'exportar PDF');
      }
    }
  }

  Future<void> _exportarCsv() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final periodo = _resumen?['periodo'] as Map<String, dynamic>?;
    final label = periodo?['label'] as String? ?? _preset;
    try {
      final bytes = await _repo.exportarCsv(
        sucursalId: sid,
        preset: _preset,
        comparar: _comparar,
        filtros: _queryFiltros,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'foody-analitica-$label.csv',
            ),
          ],
          subject: 'Análisis Foody CSV — $label',
        ),
      );
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'exportar CSV');
      }
    }
  }

  Future<void> _abrirRangoComparativa() async {
    if (!_comparar) return;
    final desdeCtrl = TextEditingController(text: _compararDesde ?? '');
    final hastaCtrl = TextEditingController(text: _compararHasta ?? '');
    final result = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Periodo de comparación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Opcional: elige fechas personalizadas. Vacío = periodo anterior automático.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: desdeCtrl,
              decoration: const InputDecoration(
                labelText: 'Desde (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hastaCtrl,
              decoration: const InputDecoration(
                labelText: 'Hasta (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _compararDesde = null;
              _compararHasta = null;
              Navigator.pop(ctx, true);
            },
            child: const Text('Automático'),
          ),
          FilledButton(
            onPressed: () {
              _compararDesde =
                  desdeCtrl.text.trim().isEmpty ? null : desdeCtrl.text.trim();
              _compararHasta =
                  hastaCtrl.text.trim().isEmpty ? null : hastaCtrl.text.trim();
              Navigator.pop(ctx, true);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    desdeCtrl.dispose();
    hastaCtrl.dispose();
    if (result == true && mounted) {
      setState(() {});
      _recargarTodo();
    }
  }

  Widget _bannerComparativa(Map<String, dynamic>? data) {
    final comp = data?['comparativa'] as Map<String, dynamic>?;
    if (comp == null) return const SizedBox.shrink();
    final delta = comp['delta'] as Map<String, dynamic>?;
    if (delta == null) return const SizedBox.shrink();
    final ant = comp['anterior'] as Map<String, dynamic>?;
    final tendencia = delta['tendencia'] as String? ?? 'igual';
    final ventasPct = delta['ventas_netas_pct'];
    final pedidosPct = delta['pedidos_pct'];
    final subtitulo = pedidosPct != null
        ? 'Ventas $ventasPct% · Pedidos $pedidosPct% ($tendencia)'
        : 'Ventas $ventasPct% ($tendencia)';
    final color = tendencia == 'sube'
        ? AnaliticaTokens.inventario
        : tendencia == 'baja'
            ? AnaliticaTokens.alertas
            : _scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnaliticaSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              tendencia == 'sube'
                  ? Icons.trending_up
                  : tendencia == 'baja'
                      ? Icons.trending_down
                      : Icons.trending_flat,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vs periodo anterior',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _scheme.onSurface,
                    ),
                  ),
                  Text(
                    ant != null
                        ? '${ant['desde']} — ${ant['hasta']} · $subtitulo'
                        : subtitulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarExportar() {
    if (_resumen == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Exportar análisis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.cancelacion.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AnaliticaTokens.cancelacion,
                  ),
                ),
                title: const Text('PDF'),
                subtitle: const Text('Resumen visual para compartir'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportarPdf();
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.margen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.table_chart_rounded,
                    color: AnaliticaTokens.margen,
                  ),
                ),
                title: const Text('CSV / Excel'),
                subtitle: const Text('Descarga desde el servidor (UTF-8)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportarCsv();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final periodo = _resumen?['periodo'] as Map<String, dynamic>?;
    final label = periodo?['label'] as String? ?? '';
    final filtrosActivos = _filtros.activos;

    return ColoredBox(
      color: AnaliticaTokens.canvasOf(context),
      child: SaasScrollableShell(
        header: [
          AnaliticaHeader(
            periodoLabel: label,
            preset: _preset,
            presets: _presets,
            comparar: _comparar,
            filtrosActivos: filtrosActivos,
            filtrosEtiqueta: _filtros.etiquetaResumen(),
            actualizadoEn: _actualizadoEn,
            compararPersonalizado:
                _compararDesde != null || _compararHasta != null,
            onPreset: _cambiarPreset,
            onPersonalizado: _abrirRangoPersonalizado,
            onToggleComparar: (v) {
              setState(() => _comparar = v);
              if (!v) {
                _compararDesde = null;
                _compararHasta = null;
              }
              _recargarTodo();
            },
            onCompararRango: _abrirRangoComparativa,
            onFiltros: _abrirFiltros,
            onActualizar: _recargarTodo,
            onExportar: _mostrarExportar,
            onIrReportes: widget.onIrReportes,
          ),
          const SizedBox(height: 8),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: AnimatedBuilder(
                      animation: _tabs,
                      builder: (context, _) => Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AnaliticaTokens.surfaceOf(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AnaliticaTokens.borderOf(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insights_outlined,
                              size: 19,
                              color: AnaliticaTokens.inkMutedOf(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _tabs.index,
                                  isExpanded: true,
                                  borderRadius: BorderRadius.circular(12),
                                  dropdownColor:
                                      AnaliticaTokens.surfaceOf(context),
                                  style: TextStyle(
                                    color: AnaliticaTokens.inkOf(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  items: [
                                    for (var i = 0; i < _tabLabels.length; i++)
                                      DropdownMenuItem(
                                        value: i,
                                        child: Text(_tabLabels[i]),
                                      ),
                                  ],
                                  onChanged: (index) {
                                    if (index != null) _tabs.animateTo(index);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AnaliticaTokens.borderOf(context),
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AnaliticaTokens.inkOf(context),
                      unselectedLabelColor: AnaliticaTokens.inkMutedOf(context),
                      indicatorColor: AnaliticaTokens.inkOf(context),
                      indicatorWeight: 2,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      tabs: [
                        for (final label in _tabLabels) Tab(text: label),
                      ],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: _cargandoResumen && _tabs.index == 0
                  ? AnaliticaSkeleton.resumen()
                  : _error != null && _tabs.index == 0
                      ? _errorView()
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _tabResumen(),
                            _tabLazy(1, _tabVentas),
                            _tabLazy(2, _tabProductos),
                            _tabLazy(3, _tabCocinas),
                            _tabLazy(4, _tabInventario),
                            _tabLazy(5, _tabDomi),
                            _tabLazy(6, _tabCaja),
                            if (widget.puedeVerFinanzas)
                              _tabLazy(
                                _tabRentabilidadIndex,
                                _tabRentabilidad,
                              ),
                            _tabLazy(_tabRiesgoIndex, _tabRiesgo),
                            if (widget.esCorporativo)
                              _tabLazy(
                                _tabComparativaIndex,
                                _tabComparativaSedes,
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnaliticaSurface(
          padding: const EdgeInsets.all(24),
          accent: AnaliticaTokens.cancelacion,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: AnaliticaTokens.cancelacion.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargarResumen,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ventas,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabLazy(int index, Widget Function(Map<String, dynamic>) builder) {
    if (_cargandoTab[index] == true) {
      return AnaliticaSkeleton.tab();
    }
    final data = _cache[index];
    if (data == null) {
      return AnaliticaSkeleton.tab();
    }
    return builder(data);
  }

  Widget _tabResumen() {
    return AnaliticaResumenDashboard(
      resumen: _resumen,
      ventas: _ventasResumen,
      topProductos: _topProductos,
      productosMenosVendidos: _menosProductos,
      pedidosRecientes: _pedidosRecientes,
      cocinas: _cocinasResumen,
      bannerComparativa: _bannerComparativa(_resumen),
      onIrVentas: () => _tabs.animateTo(1),
      onIrRiesgo: () => _tabs.animateTo(_tabRiesgoIndex),
      onIrCaja: () => _tabs.animateTo(6),
      onIrPedidos: () => _tabs.animateTo(1),
      onIrCocinas: () => _tabs.animateTo(3),
      cargandoComplementarios: _cargandoComplementarios,
      errorComplementarios: _erroresComplementarios.isEmpty
          ? null
          : 'No cargaron: ${_erroresComplementarios.keys.join(', ')}',
      onReintentarComplementarios: _recargarTodo,
    );
  }

  Widget _tabVentas(Map<String, dynamic> data) {
    final porDia = data['por_dia'] as List<dynamic>? ?? [];
    final porHora = data['por_hora'] as List<dynamic>? ?? [];
    final porTipo = data['por_tipo'] as List<dynamic>? ?? [];
    final porMetodo = data['por_metodo'] as List<dynamic>? ?? [];
    final porCategoria = data['por_categoria'] as List<dynamic>? ?? [];

    return ColoredBox(
      color: _scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _bannerComparativa(data),
          AnaliticaChartsGrid(
            children: [
              AnaliticaChartCard(
                titulo: 'Ventas por hora',
                subtitulo: 'Barras con gradiente',
                icono: Icons.schedule_rounded,
                acento: AnaliticaTokens.ventas,
                vacio: porHora.isEmpty,
                child: BarChart(AnaliticaCharts.barrasHora(
                  porHora,
                  oscuro: Theme.of(context).brightness == Brightness.dark,
                )),
              ),
              AnaliticaChartCard(
                titulo: 'Tendencia por día',
                subtitulo: 'Área animada',
                icono: Icons.show_chart_rounded,
                acento: AnaliticaTokens.alertas,
                vacio: porDia.length < 2,
                child: LineChart(AnaliticaCharts.lineaDia(
                  porDia,
                  oscuro: Theme.of(context).brightness == Brightness.dark,
                )),
              ),
              AnaliticaChartCard(
                titulo: 'Mix de pago',
                subtitulo: 'Donut premium',
                icono: Icons.pie_chart_rounded,
                acento: AnaliticaTokens.pago,
                vacio: porMetodo.isEmpty,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(AnaliticaCharts.pieMetodo(
                        porMetodo,
                        oscuro: Theme.of(context).brightness == Brightness.dark,
                      )),
                    ),
                    Expanded(
                      flex: 3,
                      child: AnaliticaCharts.leyendaPie(
                        porMetodo,
                        'metodo_pago',
                        'total',
                        oscuro: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ],
                ),
              ),
              AnaliticaChartCard(
                titulo: 'Por categoría',
                subtitulo: 'Ranking horizontal',
                icono: Icons.category_rounded,
                acento: AnaliticaTokens.inventario,
                vacio: porCategoria.isEmpty,
                child: BarChart(
                  AnaliticaCharts.barrasHorizontales(
                    porCategoria,
                    valorKey: 'ventas',
                    nombreKey: 'nombre',
                    color: AnaliticaTokens.inventario,
                    oscuro: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Por tipo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          if (porTipo.isEmpty)
            const Text('Sin datos')
          else
            ...porTipo.map((item) {
              final m = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnaliticaSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m['tipo']}'.replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${m['pedidos']} · ${_moneda.format(_num(m['ventas']))}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (porMetodo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Cobros por método de pago',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...porMetodo.map((item) {
              final m = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnaliticaSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('${m['metodo_pago']}')),
                      Text(
                        _moneda.format(_num(m['total'])),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _tabProductos(Map<String, dynamic> data) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _bannerComparativa(data),
          ),
          const TabBar(
            isScrollable: true,
            labelColor: ColoresFoody.primario,
            tabs: [
              Tab(text: 'Cantidad'),
              Tab(text: 'Ingresos'),
              Tab(text: 'Margen'),
              Tab(text: 'Sin rotación'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _listaProductos(
                  data['por_cantidad'] as List<dynamic>? ?? [],
                  chartValorKey: 'cantidad',
                ),
                _listaProductos(
                  data['por_ingresos'] as List<dynamic>? ?? [],
                  chartValorKey: 'ventas',
                ),
                _listaProductos(
                  data['por_margen'] as List<dynamic>? ?? [],
                  chartValorKey: 'margen',
                ),
                _listaSinRotacion(data['sin_rotacion'] as List<dynamic>? ?? []),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaProductos(
    List<dynamic> ranking, {
    String chartValorKey = 'cantidad',
  }) {
    if (ranking.isEmpty) {
      return const Center(child: Text('Sin ventas en el periodo'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AnaliticaChartCard(
          titulo: 'Top productos',
          altura: 180,
          child: BarChart(
            AnaliticaCharts.barrasHorizontales(
              ranking,
              valorKey: chartValorKey,
              nombreKey: 'nombre',
              oscuro: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < ranking.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE8EAF0)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: ColoresFoody.primario.withValues(alpha: 0.15),
                child: Text('${i + 1}'),
              ),
              title: Text(
                (ranking[i] as Map)['nombre'] as String? ?? '',
              ),
              subtitle: Text(
                '${(ranking[i] as Map)['cantidad']} u · margen '
                '${_moneda.format(_num((ranking[i] as Map)['margen']))}',
              ),
              trailing: Text(
                _moneda.format(_num((ranking[i] as Map)['ventas'])),
              ),
            ),
          ),
      ],
    );
  }

  Widget _listaSinRotacion(List<dynamic> lista) {
    if (lista.isEmpty) {
      return const Center(child: Text('Todos los productos tuvieron ventas'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final p = lista[i] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE8EAF0)),
          ),
          child: ListTile(
            leading: Icon(
              Icons.inventory_2_outlined,
              color: SaaSTokens.inkMuted(context),
            ),
            title: Text(p['nombre'] as String? ?? ''),
          ),
        );
      },
    );
  }

  Widget _tabCocinas(Map<String, dynamic> data) {
    final lista = data['cocinas'] as List<dynamic>? ?? [];
    if (lista.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _bannerComparativa(data),
          const Center(child: Text('Sin cocinas activas')),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _bannerComparativa(data),
        AnaliticaChartsGrid(
          children: [
            AnaliticaChartCard(
              titulo: 'Prep. media (min)',
              child: BarChart(
                AnaliticaCharts.barrasHorizontales(
                  lista,
                  valorKey: 'tiempo_prep_minutos',
                  nombreKey: 'nombre',
                  oscuro: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            AnaliticaChartCard(
              titulo: 'Unidades por cocina',
              child: BarChart(
                AnaliticaCharts.barrasHorizontales(
                  lista,
                  valorKey: 'unidades',
                  nombreKey: 'nombre',
                  oscuro: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...lista.asMap().entries.map((e) {
          final c = e.value as Map<String, dynamic>;
          final prepMin = c['tiempo_prep_min'];
          final prepMax = c['tiempo_prep_max'];
          final prepMedia = _num(c['tiempo_prep_minutos']);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE8EAF0)),
            ),
            child: ExpansionTile(
              title: Text(c['nombre'] as String? ?? 'Cocina'),
              subtitle: Text(
                '${c['unidades']} u · ${_moneda.format(_num(c['ingresos']))} · margen ${_num(c['margen_pct']).toStringAsFixed(1)}%',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Prep. media: ${prepMedia.toStringAsFixed(1)} min'),
                      if (prepMin != null || prepMax != null)
                        Text(
                          'Rango: ${_num(prepMin).toStringAsFixed(1)} – ${_num(prepMax).toStringAsFixed(1)} min',
                          style: TextStyle(
                            color: SaaSTokens.inkMuted(context),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                ...(c['top_productos'] as List<dynamic>? ?? []).map((p) {
                  final pr = p as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text(pr['nombre'] as String? ?? ''),
                    trailing: Text('${pr['unidades']} u'),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _tabInventario(Map<String, dynamic> data) {
    final r = data['resumen'] as Map<String, dynamic>? ?? {};
    final bajo = data['bajo_minimo'] as List<dynamic>? ?? [];
    final topConsumo = data['top_consumo'] as List<dynamic>? ?? [];

    return ColoredBox(
      color: _scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _bannerComparativa(data),
          if ((data['fuentes_cogs'] as Map?)?['nota'] is String)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                (data['fuentes_cogs'] as Map)['nota'] as String,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            ),
          AnaliticaKpiGrid(
            children: [
              AnaliticaKpiCard(
                etiqueta: 'Consumo (costo actual)',
                valor: _moneda.format(_num(r['consumo_valor'])),
                icono: Icons.shopping_cart_outlined,
                acento: AnaliticaTokens.ventas,
                tooltip: 'Valor bruto de movimientos tipo venta en el periodo.',
              ),
              AnaliticaKpiCard(
                etiqueta: 'Stock devuelto',
                valor: _moneda.format(_num(r['stock_devuelto_valor'])),
                icono: Icons.assignment_return_outlined,
                acento: AnaliticaTokens.pedidos,
                tooltip:
                    'Reposiciones registradas por cancelaciones, valorizadas al costo actual del insumo.',
              ),
              AnaliticaKpiCard(
                etiqueta: 'Mermas (costo actual)',
                valor: _moneda.format(_num(r['merma_valor'])),
                icono: Icons.delete_outline,
                acento: AnaliticaTokens.cancelacion,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Dif. conteo',
                valor: _moneda.format(_num(r['diferencia_conteo'])),
                icono: Icons.balance_outlined,
                acento: AnaliticaTokens.alertas,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Valor inventario',
                valor: _moneda.format(_num(r['valor_inventario_actual'])),
                icono: Icons.inventory_2_outlined,
                acento: AnaliticaTokens.inventario,
              ),
            ],
          ),
          if (topConsumo.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Top consumo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            ...topConsumo.map((item) {
              final m = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnaliticaSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(m['nombre'] as String? ?? '')),
                      Text(
                        _moneda.format(_num(m['valor'])),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
          Text(
            'Productos agotándose (${bajo.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (bajo.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Todo OK — sin ítems bajo mínimo'),
            )
          else
            ...bajo.map((item) {
              final m = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AnaliticaSurface(
                  accent: AnaliticaTokens.cancelacion,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AnaliticaTokens.cancelacion,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m['nombre'] as String? ?? '')),
                      Text(
                        '${m['stock_actual']} / ${m['stock_minimo']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _tabDomi(Map<String, dynamic> data) {
    final tot = data['totales'] as Map<String, dynamic>? ?? {};
    final ranking = data['ranking'] as List<dynamic>? ?? [];
    return ColoredBox(
      color: _scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _bannerComparativa(data),
          AnaliticaKpiGrid(
            children: [
              AnaliticaKpiCard(
                etiqueta: 'Entregas',
                valor: '${tot['entregas'] ?? 0}',
                icono: Icons.delivery_dining_outlined,
                acento: AnaliticaTokens.domicilio,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Tiempo prom.',
                valor:
                    '${_num(tot['tiempo_promedio_min']).toStringAsFixed(1)} min',
                icono: Icons.timer_outlined,
                acento: AnaliticaTokens.cocina,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...ranking.map((item) {
            final r = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnaliticaSurface(
                padding: const EdgeInsets.all(14),
                accent: AnaliticaTokens.domicilio,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['nombre'] as String? ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          '${r['entregas']} entregas',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AnaliticaTokens.domicilio,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r['tipo']} · tardías ${r['pct_tardias']}%\n'
                      'Ingresos ${_moneda.format(_num(r['ingresos_domicilio']))} · '
                      '${_num(r['distancia_promedio_km']).toStringAsFixed(2)} km prom.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tabCaja(Map<String, dynamic> data) {
    final cuadre = data['cuadre'] as Map<String, dynamic>? ?? {};
    final diff = _num(cuadre['diferencia']);
    final gastos = data['gastos_por_categoria'] as List<dynamic>? ?? [];
    final cierres = data['cierres'] as List<dynamic>? ?? [];
    final cxcPendiente =
        _num((data['cuentas_por_cobrar'] as Map?)?['pendiente']);

    return ColoredBox(
      color: _scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _bannerComparativa(data),
          AnaliticaKpiGrid(
            children: [
              AnaliticaKpiCard(
                etiqueta: 'Ventas de pedidos',
                valor: _moneda.format(_num(cuadre['ventas_pedidos'])),
                subtitulo: 'Pedidos creados en el rango',
                icono: Icons.receipt_long_outlined,
                acento: AnaliticaTokens.ventas,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Cobros netos asociados',
                valor: _moneda.format(_num(cuadre['ventas_movimientos_caja'])),
                subtitulo: 'De pedidos creados en el rango',
                tooltip: (cuadre['nota_periodo_caja'] as String?) ??
                    'Compara cobros netos asociados a pedidos creados en el rango. Los cobros posteriores pueden cambiar este importe; no es el descuadre físico de un turno.',
                icono: Icons.point_of_sale_outlined,
                acento: AnaliticaTokens.pedidos,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Ventas menos cobros',
                valor: _moneda.format(diff),
                subtitulo: 'Saldo de la cohorte de pedidos',
                tooltip: (cuadre['nota_periodo_caja'] as String?) ??
                    'Saldo actual entre ventas y cobros asociados a pedidos del rango. No equivale al descuadre físico de Caja.',
                icono: Icons.balance_outlined,
                acento: AnaliticaTokens.margen,
              ),
              AnaliticaKpiCard(
                etiqueta: 'CxC pendiente',
                valor: _moneda.format(cxcPendiente),
                icono: Icons.account_balance_wallet_outlined,
                acento: AnaliticaTokens.alertas,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Gastos registrados',
                valor: _moneda.format(_num(data['gastos_total'])),
                subtitulo: 'Fecha de registro',
                icono: Icons.receipt_long_outlined,
                acento: AnaliticaTokens.cancelacion,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Egresos de caja',
                valor: data['gastos_movimientos_caja'] == null
                    ? '—'
                    : _moneda.format(_num(data['gastos_movimientos_caja'])),
                subtitulo: data['gastos_movimientos_caja'] == null
                    ? 'Dato no disponible'
                    : null,
                icono: Icons.money_off_csred_outlined,
                acento: AnaliticaTokens.pedidos,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fila('Retiros', _moneda.format(_num(data['retiros_total']))),
          if (gastos.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnaliticaChartCard(
              titulo: 'Gastos registrados por categoría',
              subtitulo:
                  'Por fecha de registro. Rentabilidad usa la fecha del gasto; algunos registros no afectan el arqueo.',
              icono: Icons.payments_rounded,
              acento: AnaliticaTokens.cancelacion,
              child: BarChart(
                AnaliticaCharts.barrasHorizontales(
                  gastos,
                  valorKey: 'total',
                  nombreKey: 'categoria',
                  color: AnaliticaTokens.cancelacion,
                  oscuro: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...gastos.map((item) {
              final g = item as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${g['categoria']}'),
                subtitle: Text('${g['cantidad']} mov.'),
                trailing: Text(_moneda.format(_num(g['total']))),
              );
            }),
          ],
          if (cierres.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Cierres de caja',
                style: Theme.of(context).textTheme.titleMedium),
            ...cierres.map((item) {
              final c = item as Map<String, dynamic>;
              final fecha = c['cierre_at'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AnaliticaSurface(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fecha.length > 16 ? fecha.substring(0, 16) : fecha,
                        ),
                      ),
                      Text(
                        _moneda.format(_num(c['diferencia'])),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _tabRentabilidad(Map<String, dynamic> data) {
    final gastos = data['gastos_por_categoria'] as List<dynamic>? ?? [];
    final esRentable = data['es_rentable'] == true;
    final cobertura = _num(data['cobertura_costo_pct']);
    final puntoEq = data['punto_equilibrio'];
    final compras = _num(data['compras_periodo']);
    final consejos = (data['consejos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final comp = data['comparativa_utilidad'] as Map?;
    final deltaUtil = comp == null ? null : _num(comp['delta_utilidad_pct']);

    return ColoredBox(
      color: _scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (consejos.isNotEmpty)
            AnaliticaSurface(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Qué significa para tu negocio',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...consejos.map((c) {
                    final nivel = c['nivel'] as String? ?? 'info';
                    final color = nivel == 'alerta'
                        ? AnaliticaTokens.cancelacion
                        : nivel == 'aviso'
                            ? Colors.orange[800]
                            : _scheme.onSurfaceVariant;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c['mensaje']}',
                              style: TextStyle(fontSize: 13, color: color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (deltaUtil != null)
                    Text(
                      deltaUtil > 0
                          ? 'Utilidad neta ${deltaUtil.toStringAsFixed(0)}% mejor que el periodo comparado.'
                          : deltaUtil < 0
                              ? 'Utilidad neta ${deltaUtil.abs().toStringAsFixed(0)}% peor que el periodo comparado.'
                              : 'Utilidad neta igual al periodo comparado.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          if (consejos.isNotEmpty) const SizedBox(height: 12),
          AnaliticaKpiGrid(
            children: [
              AnaliticaKpiCard(
                etiqueta: 'Ventas cumplidas',
                valor: _moneda.format(_num(data['ventas_netas'])),
                icono: Icons.trending_up_rounded,
                acento: AnaliticaTokens.ventas,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Costo de ventas',
                valor: _moneda.format(_num(data['costo_ventas'])),
                icono: Icons.kitchen_outlined,
                acento: AnaliticaTokens.cancelacion,
              ),
              AnaliticaKpiCard(
                etiqueta: 'Utilidad bruta',
                valor: _moneda.format(_num(data['utilidad_bruta'])),
                icono: Icons.pie_chart_outline,
                acento: AnaliticaTokens.margen,
                subtitulo: '${_num(data['utilidad_bruta_pct'])}%',
              ),
              AnaliticaKpiCard(
                etiqueta: esRentable ? 'Utilidad neta' : 'Pérdida neta',
                valor: _moneda.format(_num(data['utilidad_neta'])),
                icono: esRentable
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                acento: esRentable
                    ? AnaliticaTokens.margen
                    : AnaliticaTokens.cancelacion,
                subtitulo: '${_num(data['margen_neto_pct'])}%',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SaaSInsightCard(
            texto:
                'Ventas cumplidas: domicilio entregado y salón/mostrador cobrado (proxy de cierre). Se excluye el impuesto registrado estimado y el cargo de domicilio; este último se muestra aparte. No equivale al recaudo de caja. Los gastos se descuentan completos para la sede y el período.',
            icono: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 12),
          AnaliticaSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Estado de resultados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                _filaPl('Ventas cumplidas (sin impuesto estimado)',
                    _num(data['ventas_netas'])),
                _filaPl(
                  'Valor de pedidos del período',
                  _num(data['valor_pedidos']),
                ),
                _filaPl(
                  'Cargo de domicilio excluido',
                  _num(data['cargo_domicilio_pedidos_cumplidos']),
                ),
                _filaPl(
                  '− Costo de lo vendido (COGS)',
                  _num(data['costo_ventas']),
                ),
                const Divider(),
                _filaPl(
                  '= Utilidad bruta',
                  _num(data['utilidad_bruta']),
                  negrita: true,
                ),
                _filaPl('− Gastos operativos', _num(data['total_gastos'])),
                const Divider(),
                _filaPl(
                  '= Utilidad neta',
                  _num(data['utilidad_neta']),
                  negrita: true,
                  color: esRentable
                      ? AnaliticaTokens.margen
                      : AnaliticaTokens.cancelacion,
                ),
              ],
            ),
          ),
          if (gastos.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnaliticaChartCard(
              titulo: 'Gastos por categoría',
              icono: Icons.account_balance_wallet_outlined,
              acento: AnaliticaTokens.cancelacion,
              child: BarChart(
                AnaliticaCharts.barrasHorizontales(
                  gastos,
                  valorKey: 'total',
                  nombreKey: 'categoria',
                  color: AnaliticaTokens.cancelacion,
                  oscuro: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            ...gastos.map((item) {
              final g = item as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${g['categoria']}'),
                subtitle: Text('${g['cantidad']} egresos'),
                trailing: Text(_moneda.format(_num(g['total']))),
              );
            }),
          ],
          const SizedBox(height: 12),
          if (puntoEq != null)
            _fila(
              'Punto de equilibrio',
              _moneda.format(_num(puntoEq)),
            ),
          _fila('Cobertura de costo en ventas', '$cobertura%'),
          if (cobertura < 80)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Varias ventas no tienen costo registrado. '
                'Revisa recetas en Costos y márgenes.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (compras > 0) ...[
            const SizedBox(height: 12),
            _fila('Compras a proveedores (ref.)', _moneda.format(compras)),
            Text(
              'No se restan del P&L para evitar contar dos veces el mismo insumo.',
              style: TextStyle(fontSize: 12, color: _scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaPl(
    String etiqueta,
    double valor, {
    bool negrita = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontWeight: negrita ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            _moneda.format(valor),
            style: TextStyle(
              fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabRiesgo(Map<String, dynamic> data) {
    final niveles = data['alertas_por_nivel'] as List<dynamic>? ?? [];
    final descuentos = data['descuentos_atipicos'] as List<dynamic>? ?? [];
    final cancelUsuarios =
        data['cancelaciones_por_usuario'] as List<dynamic>? ?? [];
    final senales = data['senales'] as Map<String, dynamic>? ?? {};
    final prodCancel =
        data['productos_cancelados_post_cocina_aprox'] as List<dynamic>? ?? [];
    final prepDelta = data['cocinas_prep_delta'] as List<dynamic>? ?? [];
    final catCaida = data['categorias_caida'] as List<dynamic>? ?? [];

    return ColoredBox(
      color: _scheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _bannerComparativa(data),
          AnaliticaChartsGrid(
            children: [
              AnaliticaChartCard(
                titulo: 'Alertas por nivel',
                icono: Icons.warning_amber_rounded,
                acento: AnaliticaTokens.alertas,
                vacio: niveles.isEmpty,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(AnaliticaCharts.donutNiveles(
                        niveles,
                        oscuro: Theme.of(context).brightness == Brightness.dark,
                      )),
                    ),
                    Expanded(
                      flex: 3,
                      child: AnaliticaCharts.leyendaPie(
                        niveles,
                        'nivel',
                        'total',
                        oscuro: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ],
                ),
              ),
              if (prepDelta.isNotEmpty)
                AnaliticaChartCard(
                  titulo: 'Δ prep cocina (%)',
                  icono: Icons.soup_kitchen_rounded,
                  acento: AnaliticaTokens.cocina,
                  child: BarChart(
                    AnaliticaCharts.barrasHorizontales(
                      prepDelta,
                      valorKey: 'delta_pct',
                      nombreKey: 'nombre',
                      color: AnaliticaTokens.cocina,
                      oscuro: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
              if (catCaida.isNotEmpty)
                AnaliticaChartCard(
                  titulo: 'Caída por categoría (%)',
                  icono: Icons.trending_down_rounded,
                  acento: AnaliticaTokens.cancelacion,
                  child: BarChart(
                    AnaliticaCharts.barrasHorizontales(
                      catCaida,
                      valorKey: 'delta_pct',
                      nombreKey: 'nombre',
                      color: AnaliticaTokens.cancelacion,
                      oscuro: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
            ],
          ),
          if (senales.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Señales', style: Theme.of(context).textTheme.titleMedium),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE8EAF0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _fila('Transferencias mesa',
                        '${senales['transferencias_mesa'] ?? 0}'),
                    _fila('Salió sin pagar',
                        '${senales['salio_sin_pagar'] ?? 0}'),
                    _fila(
                      'Usuarios cancelación alerta',
                      '${senales['usuarios_cancelacion_alerta'] ?? 0}',
                    ),
                    _fila('Cocinas prep ↑',
                        '${senales['cocinas_prep_alerta'] ?? 0}'),
                    _fila('Categorías en caída',
                        '${senales['categorias_caida_alerta'] ?? 0}'),
                  ],
                ),
              ),
            ),
          ],
          if (prepDelta.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Δ prep cocina',
                style: Theme.of(context).textTheme.titleMedium),
            ...prepDelta.take(10).map((item) {
              final c = item as Map<String, dynamic>;
              final alerta = c['alerta_subida'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: alerta
                    ? Icon(Icons.trending_up,
                        color: ColoresFoody.primario, size: 20)
                    : null,
                title: Text(c['nombre'] as String? ?? ''),
                subtitle: Text(
                  '${_num(c['minutos_actual']).toStringAsFixed(1)} min vs ${_num(c['minutos_anterior']).toStringAsFixed(1)}',
                ),
                trailing: Text('${_num(c['delta_pct']).toStringAsFixed(1)}%'),
              );
            }),
          ],
          if (catCaida.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Caída por categoría',
                style: Theme.of(context).textTheme.titleMedium),
            ...catCaida.map((item) {
              final c = item as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c['nombre'] as String? ?? ''),
                subtitle: Text(
                  '${c['unidades_actual']} vs ${c['unidades_anterior']} u',
                ),
                trailing: Text('${_num(c['delta_pct']).toStringAsFixed(1)}%'),
              );
            }),
          ],
          const SizedBox(height: 16),
          Text('Alertas por nivel',
              style: Theme.of(context).textTheme.titleMedium),
          ...niveles.map((item) {
            final a = item as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${a['nivel']}'),
              trailing: Text('${a['total']} (${a['abiertas']} abiertas)'),
            );
          }),
          const SizedBox(height: 16),
          Text('Cancelaciones por usuario',
              style: Theme.of(context).textTheme.titleMedium),
          if (cancelUsuarios.isEmpty)
            const Text('Ninguna en el periodo')
          else
            ...cancelUsuarios.take(10).map((item) {
              final c = item as Map<String, dynamic>;
              final alerta = c['supera_umbral_diario'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: alerta
                    ? Icon(Icons.warning_amber,
                        color: ColoresFoody.primario, size: 20)
                    : null,
                title: Text(c['nombre'] as String? ?? ''),
                trailing: Text('${c['cancelaciones']} cancel.'),
              );
            }),
          const SizedBox(height: 16),
          Text('Productos cancelados post-cocina',
              style: Theme.of(context).textTheme.titleMedium),
          if (prodCancel.isEmpty)
            const Text('Ninguno detectado')
          else
            ...prodCancel.map((item) {
              final p = item as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p['nombre'] as String? ?? ''),
                trailing: Text('${p['cantidad']} u'),
              );
            }),
          const SizedBox(height: 16),
          Text('Descuentos atípicos',
              style: Theme.of(context).textTheme.titleMedium),
          if (descuentos.isEmpty)
            const Text('Ninguno en el periodo')
          else
            ...descuentos.take(10).map((item) {
              final d = item as Map<String, dynamic>;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Pedido ${d['numero_pedido']}'),
                trailing: Text('${d['pct_descuento']}%'),
              );
            }),
        ],
      ),
    );
  }

  Widget _tabComparativaSedes(Map<String, dynamic> data) {
    final totales = data['totales'] as Map<String, dynamic>? ?? {};
    final sedes = (data['sedes'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnaliticaKpiGrid(
          children: [
            AnaliticaKpiCard(
              etiqueta: 'Ventas cadena',
              valor: _moneda.format(_num(totales['ventas_netas'])),
              icono: Icons.storefront_outlined,
              subtitulo: '${data['sucursales_activas'] ?? sedes.length} sedes',
            ),
            AnaliticaKpiCard(
              etiqueta: 'Pedidos',
              valor: '${totales['pedidos'] ?? 0}',
              icono: Icons.receipt_long_outlined,
              acento: ColoresFoody.secundario,
            ),
            AnaliticaKpiCard(
              etiqueta: 'Alertas abiertas',
              valor: '${totales['alertas_abiertas'] ?? 0}',
              icono: Icons.warning_amber_rounded,
              acento: ColoresFoody.primario,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sedes.map((s) {
          final kpis = s['kpis'] as Map<String, dynamic>? ?? {};
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE8EAF0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s['nombre'] as String? ?? 'Sede',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _fila('Ventas', _moneda.format(_num(kpis['ventas_netas']))),
                  _fila('Pedidos', '${kpis['pedidos'] ?? 0}'),
                  _fila(
                    'Margen',
                    '${_num(kpis['margen_bruto_pct']).toStringAsFixed(1)}%',
                  ),
                  _fila(
                    'Cancelación',
                    '${_num(kpis['pct_cancelacion']).toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _fila(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(
            v,
            style:
                TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
