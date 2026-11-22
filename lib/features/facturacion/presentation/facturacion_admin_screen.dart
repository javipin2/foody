import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/tema/foody_formulario.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/facturacion/data/facturacion_repository.dart';

/// Config fiscal, listado y emisión de facturas (Sprint 9).
class FacturacionAdminScreen extends StatefulWidget {
  const FacturacionAdminScreen({
    super.key,
    this.sucursalId,
    this.pedidoIdInicial,
    this.pedidoNumeroInicial,
    this.onPedidoSugeridoUsado,
    this.onIrPedido,
    this.repository,
  });

  final String? sucursalId;
  final FacturacionRepository? repository;

  /// NAV-ADM-02: llegar desde sheet de pedidos.
  final String? pedidoIdInicial;
  final String? pedidoNumeroInicial;
  final VoidCallback? onPedidoSugeridoUsado;

  /// NAV-ADM-17: desde factura → kanban del pedido.
  final ValueChanged<String>? onIrPedido;

  @override
  State<FacturacionAdminScreen> createState() => _FacturacionAdminScreenState();
}

class _FacturacionAdminScreenState extends State<FacturacionAdminScreen>
    with SingleTickerProviderStateMixin {
  late final _repo = widget.repository ?? FacturacionRepository();
  late TabController _tabs;

  final _nit = TextEditingController();
  final _razon = TextEditingController();
  final _resolucion = TextEditingController();
  final _prefijo = TextEditingController(text: 'FE');
  String _regimen = 'comun';
  bool _aplicaIva = true;
  double _pctIva = 19;

  List<Map<String, dynamic>> _facturas = [];
  bool _cargandoConfig = true;
  bool _cargandoFacturas = true;
  bool _guardando = false;
  String? _errorConfig;
  String? _errorFacturas;
  final _emitiendoPedidos = <String>{};
  String? get _errorVista => _errorConfig ?? _errorFacturas;

  final _moneda =
      NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
  final _fecha = DateFormat('d MMM yyyy HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (widget.pedidoIdInicial != null) {
      _tabs.index = 1;
    }
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nit.dispose();
    _razon.dispose();
    _resolucion.dispose();
    _prefijo.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([_cargarConfig(), _cargarFacturas()]);
  }

  Future<void> _cargarConfig() async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargandoConfig = false;
        _errorConfig = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() {
      _errorConfig = null;
      _cargandoConfig = true;
    });
    try {
      final config = await _repo.obtenerConfig(sid);
      if (mounted && config != null) {
        _nit.text = '${config['nit'] ?? ''}';
        _razon.text = '${config['razon_social'] ?? ''}';
        _resolucion.text = '${config['resolucion_dian'] ?? ''}';
        _prefijo.text = '${config['prefijo_factura'] ?? 'FE'}';
        _regimen = '${config['regimen'] ?? 'comun'}';
        _aplicaIva = config['aplica_iva'] == true;
        _pctIva = double.tryParse('${config['porcentaje_iva']}') ?? 19;
      }
      if (mounted) setState(() => _cargandoConfig = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorConfig = mensajeErrorHttp(e, contexto: 'config fiscal');
          _cargandoConfig = false;
        });
      }
    }
  }

  Future<void> _cargarFacturas() async {
    final sid = widget.sucursalId;
    if (sid == null || !mounted) return;
    setState(() {
      _errorFacturas = null;
      _cargandoFacturas = true;
    });
    try {
      final lista = await _repo.listarFacturas(sid);
      if (mounted) {
        setState(() {
          _facturas = lista;
          _cargandoFacturas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorFacturas = mensajeErrorHttp(e, contexto: 'facturas');
          _cargandoFacturas = false;
        });
      }
    }
  }

  Future<void> _guardarConfig() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    if (_nit.text.trim().isEmpty || _razon.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NIT y razón social son obligatorios')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await _repo.guardarConfig({
        'sucursal_id': sid,
        'nit': _nit.text.trim(),
        'razon_social': _razon.text.trim(),
        'regimen': _regimen,
        'aplica_iva': _aplicaIva,
        'porcentaje_iva': _pctIva,
        'resolucion_dian':
            _resolucion.text.trim().isEmpty ? null : _resolucion.text.trim(),
        'prefijo_factura':
            _prefijo.text.trim().isEmpty ? 'FE' : _prefijo.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración fiscal guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'guardar config')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<bool> _emitir(String pedidoId) async {
    final sid = widget.sucursalId;
    if (sid == null || _emitiendoPedidos.contains(pedidoId)) return false;
    setState(() => _emitiendoPedidos.add(pedidoId));
    try {
      await _repo.emitir(pedidoId, sid);
      await _cargarFacturas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factura emitida')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'emisión'))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _emitiendoPedidos.remove(pedidoId));
    }
  }

  Future<void> _verPdf(String facturaId, {bool esBorrador = false}) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final datos = await _repo.obtenerPdf(facturaId, sid);
      final html = datos['html'] as String? ?? '';
      if (!mounted) return;
      await FoodyDialogo.mostrar<void>(
        context: context,
        builder: (ctx) {
          final maxW = MediaQuery.sizeOf(ctx).width.clamp(280.0, 520.0);
          final maxH = MediaQuery.sizeOf(ctx).height * 0.7;
          final factura = datos['factura'] as Map<String, dynamic>?;
          return FoodyDialogoShell(
            titulo:
                esBorrador ? 'Vista previa borrador' : 'Vista previa factura',
            subtitulo: 'Resumen de los datos de facturación',
            maxWidth: maxW,
            maxHeightFactor: maxH / MediaQuery.sizeOf(ctx).height,
            contenido: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (esBorrador)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Revisa los datos fiscales antes de emitir. El número oficial se asigna al emitir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                FoodyFormSeccion(
                  titulo: factura?['numero_factura']?.toString() ?? 'Borrador',
                  icono: Icons.receipt_long_outlined,
                  hijo: Column(
                    children: [
                      _filaVistaPrevia('Pedido', factura?['numero_pedido']),
                      _filaVistaPrevia(
                          'Cliente', factura?['nombre_fiscal_cliente']),
                      _filaVistaPrevia('NIT', factura?['nit_cliente']),
                      _filaVistaPrevia('Estado', factura?['estado']),
                      const Divider(height: 20),
                      _filaVistaPrevia(
                        'Subtotal',
                        _moneda.format(
                            double.tryParse('${factura?['subtotal']}') ?? 0),
                      ),
                      _filaVistaPrevia(
                        'IVA',
                        _moneda
                            .format(double.tryParse('${factura?['iva']}') ?? 0),
                      ),
                      _filaVistaPrevia(
                        'Total',
                        _moneda.format(
                            double.tryParse('${factura?['total']}') ?? 0),
                        destacado: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            acciones: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: html));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('HTML copiado al portapapeles'),
                    ),
                  );
                },
                child: const Text('Copiar HTML'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'PDF'))),
        );
      }
    }
  }

  Widget _filaVistaPrevia(String etiqueta, Object? valor,
      {bool destacado = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor?.toString().trim().isNotEmpty == true
                  ? valor.toString()
                  : '—',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: destacado ? FontWeight.w700 : FontWeight.w500,
                fontSize: destacado ? 16 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'emitida':
        return AnaliticaTokens.inventario;
      case 'anulada':
        return AnaliticaTokens.alertas;
      case 'borrador':
        return const Color(0xFFD97706);
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  InputDecoration _campo(String label, {String? helper, String? hint}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      helperText: helper,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    );
  }

  Widget _seccionCard({
    required String titulo,
    String? subtitulo,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidoSug = widget.pedidoIdInicial;
    final numSug = widget.pedidoNumeroInicial;
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return ColoredBox(
      color: AnaliticaTokens.canvasOf(context),
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(compacto ? 12 : 16, 8, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin / Finanzas',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Facturas internas',
                        style: TextStyle(
                          fontSize: compacto ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Borradores y PDF · DIAN electrónico pausado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _cargarTodo,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (pedidoSug != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compacto ? 12 : 16,
                8,
                compacto ? 12 : 16,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AnaliticaTokens.pedidos.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                      color: AnaliticaTokens.pedidos,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        numSug != null && numSug.isNotEmpty
                            ? 'Emitir factura del pedido $numSug'
                            : 'Emitir factura del pedido seleccionado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onPedidoSugeridoUsado?.call(),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Descartar'),
                    ),
                    FilledButton(
                      onPressed: _emitiendoPedidos.contains(pedidoSug)
                          ? null
                          : () async {
                              final emitida = await _emitir(pedidoSug);
                              if (mounted && emitida) {
                                widget.onPedidoSugeridoUsado?.call();
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        _emitiendoPedidos.contains(pedidoSug)
                            ? 'Emitiendo…'
                            : 'Emitir',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorVista != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compacto ? 12 : 16,
                8,
                compacto ? 12 : 16,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AnaliticaTokens.alertas.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AnaliticaTokens.alertas,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorVista!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _cargarTodo,
                      style: TextButton.styleFrom(
                        foregroundColor: AnaliticaTokens.alertas,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: FoodyScrollHorizontalFade(
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
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
                      const Tab(text: 'Config fiscal'),
                      Tab(text: 'Facturas (${_facturas.length})'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _tabConfig(compacto: compacto),
                  _tabFacturas(compacto: compacto),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabConfig({required bool compacto}) {
    if (_cargandoConfig) {
      return ColoredBox(
        color: AnaliticaTokens.canvasOf(context),
        child: AnaliticaSkeleton.tab(),
      );
    }

    final maxForm = compacto ? double.infinity : 720.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 16,
        12,
        compacto ? 12 : 16,
        32,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxForm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Borradores y emisión interna (ticket/PDF). '
                          'DIAN electrónico (CUFE/XML) está pausado — no hay envío legal.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _seccionCard(
                  titulo: 'Datos del emisor',
                  subtitulo: 'Identificación fiscal del restaurante',
                  children: [
                    if (compacto) ...[
                      TextField(
                        controller: _nit,
                        decoration: _campo('NIT emisor'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _razon,
                        decoration: _campo('Razón social'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _regimen,
                        decoration: _campo('Régimen'),
                        items: const [
                          DropdownMenuItem(
                            value: 'comun',
                            child: Text('Común'),
                          ),
                          DropdownMenuItem(
                            value: 'simplificado',
                            child: Text('Simplificado'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _regimen = v;
                            if (v == 'simplificado') {
                              _aplicaIva = false;
                              _pctIva = 0;
                            } else {
                              _aplicaIva = true;
                              _pctIva = 19;
                            }
                          });
                        },
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nit,
                              decoration: _campo('NIT emisor'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _razon,
                              decoration: _campo('Razón social'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _regimen,
                        decoration: _campo('Régimen'),
                        items: const [
                          DropdownMenuItem(
                            value: 'comun',
                            child: Text('Común'),
                          ),
                          DropdownMenuItem(
                            value: 'simplificado',
                            child: Text('Simplificado'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _regimen = v;
                            if (v == 'simplificado') {
                              _aplicaIva = false;
                              _pctIva = 0;
                            } else {
                              _aplicaIva = true;
                              _pctIva = 19;
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
                _seccionCard(
                  titulo: 'IVA en factura',
                  subtitulo: 'Precios al cliente siguen con IVA incluido',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Aplica IVA en factura',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'Desglosa IVA al emitir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: _aplicaIva,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      onChanged: (v) => setState(() => _aplicaIva = v),
                    ),
                    if (_aplicaIva) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Porcentaje IVA',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '${_pctIva.toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _pctIva,
                        min: 0,
                        max: 19,
                        divisions: 19,
                        label: '${_pctIva.toInt()}%',
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (v) => setState(() => _pctIva = v),
                      ),
                    ],
                  ],
                ),
                _seccionCard(
                  titulo: 'Numeración interna',
                  subtitulo: 'Prefijo de factura (FE legal pausada)',
                  children: [
                    // ponytail: resolución DIAN oculta mientras FE esté pausada
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: compacto ? double.infinity : 180,
                        child: TextField(
                          controller: _prefijo,
                          decoration: _campo(
                            'Prefijo factura',
                            hint: 'FE',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardarConfig,
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      minimumSize: Size(compacto ? double.infinity : 200, 44),
                    ),
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _guardando ? 'Guardando…' : 'Guardar configuración',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _anularFactura(String facturaId) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final formulario = GlobalKey<FormState>();
    String? motivoValidado;
    final motivo = await FoodyDialogo.mostrar<String>(
      context: context,
      builder: (ctx) => FoodyDialogoShell(
        titulo: 'Anular factura',
        subtitulo: 'Registra el motivo para identificar esta acción después.',
        maxWidth: 440,
        contenido: FoodyFormSeccion(
          titulo: 'Motivo',
          icono: Icons.cancel_outlined,
          acento: AnaliticaTokens.alertas,
          hijo: Form(
            key: formulario,
            child: TextFormField(
              decoration: FoodyFormEstilo.campo(label: 'Motivo de anulación'),
              validator: (valor) => (valor?.trim().length ?? 0) < 3
                  ? 'Escribe al menos 3 caracteres'
                  : null,
              onSaved: (valor) => motivoValidado = valor?.trim(),
              maxLines: 3,
              minLines: 2,
            ),
          ),
        ),
        acciones: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final estadoFormulario = formulario.currentState;
              if (estadoFormulario != null && estadoFormulario.validate()) {
                estadoFormulario.save();
                Navigator.pop(ctx, motivoValidado);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.alertas,
            ),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (!mounted || motivo == null) return;
    try {
      await _repo.anular(
        facturaId: facturaId,
        sucursalId: sid,
        motivo: motivo,
      );
      await _cargarFacturas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factura anulada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'anular factura')),
          ),
        );
      }
    }
  }

  Widget _badgeEstado(String estado) {
    final color = _colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _accionesFactura(
    Map<String, dynamic> factura, {
    required String estado,
    required String pedidoId,
    required bool tienePedido,
  }) {
    return PopupMenuButton<String>(
      enabled: !_emitiendoPedidos.contains(pedidoId),
      tooltip: 'Acciones de factura',
      onSelected: (accion) {
        switch (accion) {
          case 'pedido':
            if (tienePedido) widget.onIrPedido?.call(pedidoId);
          case 'emitir':
            _emitir(pedidoId);
          case 'anular':
            _anularFactura('${factura['id']}');
          case 'ver':
            _verPdf('${factura['id']}', esBorrador: estado == 'borrador');
        }
      },
      itemBuilder: (_) => [
        if (tienePedido && widget.onIrPedido != null)
          const PopupMenuItem(
            value: 'pedido',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shopping_bag_outlined),
              title: Text('Ver pedido'),
            ),
          ),
        if (estado == 'borrador' && tienePedido)
          const PopupMenuItem(
            value: 'emitir',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.send_rounded),
              title: Text('Emitir'),
            ),
          ),
        if (estado == 'emitida')
          const PopupMenuItem(
            value: 'anular',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cancel_outlined),
              title: Text('Anular'),
            ),
          ),
        PopupMenuItem(
          value: 'ver',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              estado == 'borrador'
                  ? Icons.preview_outlined
                  : Icons.receipt_long_outlined,
            ),
            title: Text(estado == 'borrador' ? 'Vista previa' : 'Ver factura'),
          ),
        ),
      ],
    );
  }

  Widget _tablaFacturas() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  columns: const [
                    DataColumn(label: Text('FACTURA')),
                    DataColumn(label: Text('CLIENTE')),
                    DataColumn(label: Text('FECHA')),
                    DataColumn(label: Text('TOTAL'), numeric: true),
                    DataColumn(label: Text('ESTADO')),
                    DataColumn(label: Text('ACCIONES')),
                  ],
                  rows: _facturas.map((factura) {
                    final estado = '${factura['estado']}';
                    final pedidoId = '${factura['pedido_id']}';
                    final tienePedido =
                        pedidoId.isNotEmpty && pedidoId != 'null';
                    final titulo = factura['numero_factura']?.toString() ??
                        'Borrador · pedido ${factura['numero_pedido']}';
                    final fecha = factura['created_at'] != null
                        ? _fecha.format(
                            DateTime.parse('${factura['created_at']}')
                                .toLocal(),
                          )
                        : '—';
                    return DataRow(cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      DataCell(Text(
                        factura['nombre_fiscal_cliente']?.toString() ?? '—',
                      )),
                      DataCell(Text(fecha)),
                      DataCell(Text(_moneda.format(
                        double.tryParse('${factura['total']}') ?? 0,
                      ))),
                      DataCell(_badgeEstado(estado)),
                      DataCell(_accionesFactura(
                        factura,
                        estado: estado,
                        pedidoId: pedidoId,
                        tienePedido: tienePedido,
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabFacturas({required bool compacto}) {
    final scheme = Theme.of(context).colorScheme;
    if (_cargandoFacturas) {
      return ColoredBox(
        color: AnaliticaTokens.canvasOf(context),
        child: AnaliticaSkeleton.tab(),
      );
    }
    if (_facturas.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(compacto ? 20 : 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: scheme.onSurfaceVariant,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Sin facturas aún',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cuando un pedido pida factura o emitas desde aquí, aparecerán en esta lista.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarFacturas,
      child: FoodyBreakpoints.esLarge(FoodyBreakpoints.widthOf(context))
          ? _tablaFacturas()
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                compacto ? 12 : 16,
                12,
                compacto ? 12 : 16,
                24,
              ),
              itemCount: _facturas.length,
              itemBuilder: (context, i) {
                final f = _facturas[i];
                final estado = '${f['estado']}';
                final pedidoId = '${f['pedido_id']}';
                final tienePedido = pedidoId.isNotEmpty && pedidoId != 'null';
                final color = _colorEstado(estado);
                final titulo = f['numero_factura']?.toString() ??
                    'Borrador · pedido ${f['numero_pedido']}';
                final fecha = f['created_at'] != null
                    ? _fecha.format(
                        DateTime.parse('${f['created_at']}').toLocal(),
                      )
                    : '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: estado == 'anulada' || estado == 'borrador'
                          ? color.withValues(alpha: 0.35)
                          : scheme.outlineVariant,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A111827),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(compacto ? 10 : 12, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${f['nombre_fiscal_cliente']} · '
                                '${_moneda.format(double.tryParse('${f['total']}') ?? 0)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (fecha.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  fecha,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              _badgeEstado(estado),
                            ],
                          ),
                        ),
                        _accionesFactura(
                          f,
                          estado: estado,
                          pedidoId: pedidoId,
                          tienePedido: tienePedido,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
