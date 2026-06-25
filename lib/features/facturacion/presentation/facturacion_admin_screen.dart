import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/facturacion/data/facturacion_repository.dart';

/// Config fiscal, listado y emisión de facturas (Sprint 9).
class FacturacionAdminScreen extends StatefulWidget {
  const FacturacionAdminScreen({super.key, this.sucursalId});

  final String? sucursalId;

  @override
  State<FacturacionAdminScreen> createState() => _FacturacionAdminScreenState();
}

class _FacturacionAdminScreenState extends State<FacturacionAdminScreen>
    with SingleTickerProviderStateMixin {
  final _repo = FacturacionRepository();
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
  String? _error;

  final _moneda = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
  final _fecha = DateFormat('d MMM yyyy HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() => _cargandoConfig = true);
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
          _error = mensajeErrorHttp(e, contexto: 'config fiscal');
          _cargandoConfig = false;
        });
      }
    }
  }

  Future<void> _cargarFacturas() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    setState(() => _cargandoFacturas = true);
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
          _error = mensajeErrorHttp(e, contexto: 'facturas');
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
        'resolucion_dian': _resolucion.text.trim().isEmpty
            ? null
            : _resolucion.text.trim(),
        'prefijo_factura': _prefijo.text.trim().isEmpty
            ? 'FE'
            : _prefijo.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración fiscal guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'guardar config'))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _emitir(String pedidoId) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _repo.emitir(pedidoId, sid);
      await _cargarFacturas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factura emitida')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'emisión'))),
        );
      }
    }
  }

  Future<void> _verPdf(String facturaId) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final datos = await _repo.obtenerPdf(facturaId, sid);
      final html = datos['html'] as String? ?? '';
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vista previa factura'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                _resumenTexto(datos['factura'] as Map<String, dynamic>?),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: html));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('HTML copiado al portapapeles')),
                );
              },
              child: const Text('Copiar HTML'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'PDF'))),
        );
      }
    }
  }

  String _resumenTexto(Map<String, dynamic>? f) {
    if (f == null) return 'Sin datos';
    return [
      'Número: ${f['numero_factura'] ?? 'Pendiente'}',
      'Pedido: ${f['numero_pedido'] ?? '—'}',
      'Cliente: ${f['nombre_fiscal_cliente'] ?? '—'}',
      'NIT: ${f['nit_cliente'] ?? '—'}',
      'Estado: ${f['estado'] ?? '—'}',
      'Subtotal: ${_moneda.format(double.tryParse('${f['subtotal']}') ?? 0)}',
      'IVA: ${_moneda.format(double.tryParse('${f['iva']}') ?? 0)}',
      'Total: ${_moneda.format(double.tryParse('${f['total']}') ?? 0)}',
    ].join('\n');
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'emitida':
        return ColoresFoody.exito;
      case 'anulada':
        return ColoresFoody.error;
      default:
        return ColoresFoody.acento;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Facturación',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: ColoresFoody.primario,
          tabs: const [
            Tab(text: 'Config fiscal'),
            Tab(text: 'Facturas'),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: TextStyle(color: ColoresFoody.error)),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _tabConfig(),
              _tabFacturas(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabConfig() {
    if (_cargandoConfig) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nit,
          decoration: const InputDecoration(
            labelText: 'NIT emisor',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _razon,
          decoration: const InputDecoration(
            labelText: 'Razón social',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _regimen,
          decoration: const InputDecoration(
            labelText: 'Régimen',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'comun', child: Text('Común')),
            DropdownMenuItem(value: 'simplificado', child: Text('Simplificado')),
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
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Aplica IVA en factura'),
          subtitle: const Text('Precios al cliente siguen con IVA incluido'),
          value: _aplicaIva,
          onChanged: (v) => setState(() => _aplicaIva = v),
        ),
        if (_aplicaIva)
          Slider(
            value: _pctIva,
            min: 0,
            max: 19,
            divisions: 19,
            label: '${_pctIva.toInt()}%',
            onChanged: (v) => setState(() => _pctIva = v),
          ),
        TextField(
          controller: _resolucion,
          decoration: const InputDecoration(
            labelText: 'Resolución DIAN',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _prefijo,
          decoration: const InputDecoration(
            labelText: 'Prefijo factura',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardarConfig,
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Guardar configuración'),
        ),
      ],
    );
  }

  Future<void> _anularFactura(String facturaId) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular factura'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo de anulación',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim().length >= 3),
            style: FilledButton.styleFrom(backgroundColor: ColoresFoody.error),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (ok != true) {
      motivoCtrl.dispose();
      return;
    }
    try {
      await _repo.anular(
        facturaId: facturaId,
        sucursalId: sid,
        motivo: motivoCtrl.text.trim(),
      );
      motivoCtrl.dispose();
      await _cargarFacturas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factura anulada')),
        );
      }
    } catch (e) {
      motivoCtrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'anular factura'))),
        );
      }
    }
  }

  Widget _tabFacturas() {
    if (_cargandoFacturas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_facturas.isEmpty) {
      return const Center(child: Text('Sin facturas aún'));
    }
    return RefreshIndicator(
      onRefresh: _cargarFacturas,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _facturas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = _facturas[i];
          final estado = '${f['estado']}';
          final pedidoId = '${f['pedido_id']}';
          return Card(
            child: ListTile(
              title: Text(
                f['numero_factura']?.toString() ?? 'Borrador · pedido ${f['numero_pedido']}',
              ),
              subtitle: Text(
                '${f['nombre_fiscal_cliente']} · ${_moneda.format(double.tryParse('${f['total']}') ?? 0)}\n'
                '${f['created_at'] != null ? _fecha.format(DateTime.parse('${f['created_at']}').toLocal()) : ''}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 4,
                children: [
                  Chip(
                    label: Text(estado, style: const TextStyle(fontSize: 11)),
                    backgroundColor: _colorEstado(estado).withValues(alpha: 0.2),
                  ),
                  if (estado == 'borrador')
                    IconButton(
                      tooltip: 'Emitir',
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () => _emitir(pedidoId),
                    ),
                  if (estado != 'anulada' && estado != 'borrador')
                    IconButton(
                      tooltip: 'Anular',
                      icon: Icon(Icons.cancel_outlined, color: ColoresFoody.error),
                      onPressed: () => _anularFactura('${f['id']}'),
                    ),
                  IconButton(
                    tooltip: 'Ver',
                    icon: const Icon(Icons.receipt_long_outlined),
                    onPressed: () => _verPdf('${f['id']}'),
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
