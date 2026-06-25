import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Panel caja (Sprint 5) — abrir turno, movimientos, cerrar.
class CajaAdminScreen extends StatefulWidget {
  const CajaAdminScreen({super.key, this.sucursalId});

  final String? sucursalId;

  @override
  State<CajaAdminScreen> createState() => _CajaAdminScreenState();
}

class _CajaAdminScreenState extends State<CajaAdminScreen> {
  final _repo = CajaRepository();
  final _montoApertura = TextEditingController(text: '0');
  final _montoCierre = TextEditingController();
  final _conceptoGasto = TextEditingController();
  final _montoGasto = TextEditingController();
  final _montoRetiro = TextEditingController();
  final _montoDevolucion = TextEditingController();
  final _motivoDevolucion = TextEditingController();
  bool _arqueoCiego = false;

  Map<String, dynamic>? _caja;
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _fiados = [];
  bool _cargando = true;
  String? _error;
  RealtimeChannel? _canal;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargar();
    _suscribirRealtime();
  }

  void _suscribirRealtime() {
    final sid = widget.sucursalId;
    if (!AppBackend.supabaseReady || sid == null) return;
    _canal = FoodyRealtime.suscribirSucursal(
      sid,
      onEvento: (evento) {
        if (evento == 'caja_movimiento') {
          _cargar();
        }
      },
    );
  }

  @override
  void dispose() {
    _canal?.unsubscribe();
    _montoApertura.dispose();
    _montoCierre.dispose();
    _conceptoGasto.dispose();
    _montoGasto.dispose();
    _montoRetiro.dispose();
    _montoDevolucion.dispose();
    _motivoDevolucion.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final caja = await _repo.cajaActiva(sid);
      List<Map<String, dynamic>> movs = [];
      List<Map<String, dynamic>> fiados = [];
      try {
        fiados = await _repo.cuentasPorCobrar(sid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'fiados'))),
          );
        }
      }
      if (caja != null) {
        movs = await _repo.movimientos(caja['id'] as String);
        if (caja['arqueo_ciego'] != true) {
          _montoCierre.text = '${caja['saldo_sistema'] ?? 0}';
        } else {
          _montoCierre.clear();
        }
      }
      if (mounted) {
        setState(() {
          _caja = caja;
          _movimientos = movs;
          _fiados = fiados;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'caja');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrir() async {
    final sid = widget.sucursalId!;
    final monto = double.tryParse(_montoApertura.text.replaceAll(',', '.')) ?? 0;
    try {
      await _repo.abrir(
        sucursalId: sid,
        montoInicial: monto,
        arqueoCiego: _arqueoCiego,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caja abierta')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _cerrar() async {
    final cajaId = _caja!['id'] as String;
    final monto =
        double.tryParse(_montoCierre.text.replaceAll(',', '.')) ?? 0;
    try {
      final res = await _repo.cerrar(
        cajaId: cajaId,
        montoContado: monto,
      );
      if (!mounted) return;
      final diff = (res['diferencia'] as num?)?.toDouble() ?? 0;
      final alertaArqueo = diff.abs() > 5000;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(alertaArqueo ? 'Caja cerrada — revisar arqueo' : 'Caja cerrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alertaArqueo)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColoresFoody.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ColoresFoody.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: ColoresFoody.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Diferencia superior a \$5.000. Informa al administrador.',
                          style: TextStyle(
                            color: ColoresFoody.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                _caja?['arqueo_ciego'] == true
                    ? 'Contado: ${_moneda.format(res['monto_final_contado'])}\n'
                      'Diferencia: ${_moneda.format(res['diferencia'])}\n'
                      '(Arqueo ciego — saldo sistema oculto)'
                    : 'Sistema: ${_moneda.format(res['monto_final_sistema'])}\n'
                      'Contado: ${_moneda.format(res['monto_final_contado'])}\n'
                      'Diferencia: ${_moneda.format(res['diferencia'])}',
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _nuevoFiado() async {
    final sid = widget.sucursalId!;
    final nombre = TextEditingController();
    final tel = TextEditingController();
    final monto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar fiado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Cliente'),
            ),
            TextField(
              controller: tel,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
            ),
            TextField(
              controller: monto,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final nombreTxt = nombre.text.trim();
    final telTxt = tel.text.trim();
    final m = double.tryParse(monto.text.replaceAll(',', '.'));
    nombre.dispose();
    tel.dispose();
    monto.dispose();
    if (ok != true || m == null || nombreTxt.isEmpty) return;
    try {
      await _repo.crearCuentaPorCobrar(
        sucursalId: sid,
        clienteNombre: nombreTxt,
        clienteTelefono: telTxt.isEmpty ? null : telTxt,
        monto: m,
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pagarFiado(String id) async {
    try {
      await _repo.pagarCuenta(id);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta cobrada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _gasto() async {
    try {
      await _repo.registrarGasto(
        cajaId: _caja!['id'] as String,
        concepto: _conceptoGasto.text.trim(),
        monto: double.tryParse(_montoGasto.text.replaceAll(',', '.')) ?? 0,
      );
      _conceptoGasto.clear();
      _montoGasto.clear();
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _devolucion() async {
    final sid = widget.sucursalId!;
    try {
      await _repo.registrarDevolucion(
        cajaId: _caja!['id'] as String,
        sucursalId: sid,
        monto: double.tryParse(_montoDevolucion.text.replaceAll(',', '.')) ?? 0,
        motivo: _motivoDevolucion.text.trim(),
      );
      _montoDevolucion.clear();
      _motivoDevolucion.clear();
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devolución registrada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _retiroParcial() async {
    try {
      await _repo.retiro(
        cajaId: _caja!['id'] as String,
        monto: double.tryParse(_montoRetiro.text.replaceAll(',', '.')) ?? 0,
        descripcion: 'Retiro parcial',
      );
      _montoRetiro.clear();
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_caja == null) {
      return _pantallaApertura();
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperacionPageHeader(
          titulo: 'Caja',
          subtitulo: 'Turno abierto',
          acciones: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: Color(0xFF3B6D11)),
                  SizedBox(width: 4),
                  Text(
                    'Turno activo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B6D11),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: dosColumnas
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _panelPrincipalCaja()),
                      SizedBox(width: 280, child: _panelLateralCaja()),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _metricasCaja(),
                      const SizedBox(height: 12),
                      _listaMovimientos(),
                      const SizedBox(height: 16),
                      _panelLateralCaja(),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _panelPrincipalCaja() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _metricasCaja(),
        const SizedBox(height: 12),
        _listaMovimientos(),
      ],
    );
  }

  Widget _metricasCaja() {
    final ventas = _num(_caja!['total_ventas']);
    final gastos = _num(_caja!['total_gastos']);
    final saldo = _num(_caja!['saldo_sistema']);
    final ciego = _caja!['arqueo_ciego'] == true;
    return Row(
      children: [
        Expanded(
          child: OperacionMetricCard(
            etiqueta: 'Saldo sistema',
            valor: ciego ? '—' : _moneda.format(saldo),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OperacionMetricCard(
            etiqueta: 'Ventas',
            valor: _moneda.format(ventas),
            colorValor: const Color(0xFF3B6D11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OperacionMetricCard(
            etiqueta: 'Gastos',
            valor: _moneda.format(gastos),
            colorValor: const Color(0xFFA32D2D),
          ),
        ),
      ],
    );
  }

  Widget _listaMovimientos() {
    return Container(
      decoration: OperacionUi.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'Movimientos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_movimientos.length} registros',
                  style: const TextStyle(fontSize: 11, color: OperacionUi.textoTerciario),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_movimientos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Sin movimientos aún')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _movimientos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _filaMovimiento(_movimientos[i]),
            ),
        ],
      ),
    );
  }

  Widget _panelLateralCaja() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      children: [
        _seccionFiados(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OperacionUi.tarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Registrar gasto',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _conceptoGasto,
                decoration: InputDecoration(
                  hintText: 'Concepto',
                  filled: true,
                  fillColor: OperacionUi.fondoPagina,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoGasto,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Monto',
                  filled: true,
                  fillColor: OperacionUi.fondoPagina,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _gasto,
                style: FilledButton.styleFrom(backgroundColor: ColoresFoody.primario),
                child: const Text('Guardar gasto'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OperacionUi.tarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Retiro parcial',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoRetiro,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Monto retiro',
                  filled: true,
                  fillColor: OperacionUi.fondoPagina,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _retiroParcial,
                child: const Text('Registrar retiro'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OperacionUi.tarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Devolución',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoDevolucion,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Monto',
                  filled: true,
                  fillColor: OperacionUi.fondoPagina,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _motivoDevolucion,
                decoration: InputDecoration(
                  hintText: 'Motivo',
                  filled: true,
                  fillColor: OperacionUi.fondoPagina,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _devolucion,
                style: FilledButton.styleFrom(backgroundColor: ColoresFoody.secundario),
                child: const Text('Registrar devolución'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OperacionUi.tarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cerrar turno',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoCierre,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monto contado',
                  prefixText: r'$ ',
                  filled: true,
                  fillColor: OperacionUi.fondoPagina,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _cerrar,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: const Text(
                      'Cerrar caja',
                      style: TextStyle(
                        color: Color(0xFFA32D2D),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaMovimiento(Map<String, dynamic> m) {
    final tipo = m['tipo'] as String? ?? '';
    final monto = _num(m['monto']);
    final esNeg = tipo == 'gasto' || tipo == 'retiro';
    final iconData = _iconoTipo(tipo);
    final iconBg = tipo == 'venta'
        ? const Color(0xFFEAF3DE)
        : tipo == 'gasto'
            ? const Color(0xFFFCEBEB)
            : const Color(0xFFFAEEDA);
    final iconColor = tipo == 'venta'
        ? const Color(0xFF3B6D11)
        : tipo == 'gasto'
            ? const Color(0xFFA32D2D)
            : const Color(0xFF854F0B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  m['descripcion'] as String? ?? '',
                  style: const TextStyle(fontSize: 11, color: OperacionUi.textoTerciario),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _moneda.format(monto),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: esNeg ? const Color(0xFFA32D2D) : const Color(0xFF3B6D11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pantallaApertura() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.point_of_sale, size: 48, color: ColoresFoody.primario),
                const SizedBox(height: 16),
                Text(
                  'Abrir turno de caja',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Indica el monto inicial en efectivo para comenzar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Arqueo ciego'),
                  subtitle: const Text('El cajero no verá el saldo del sistema'),
                  value: _arqueoCiego,
                  onChanged: (v) => setState(() => _arqueoCiego = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _montoApertura,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto inicial',
                    prefixText: r'$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _abrir,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresFoody.primario,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Abrir caja'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  Widget _seccionFiados() {
    final pendientes =
        _fiados.where((f) => f['estado'] == 'pendiente').toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Cuentas por cobrar', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _nuevoFiado,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Fiado'),
                ),
              ],
            ),
            if (pendientes.isEmpty)
              Text('Sin fiados pendientes', style: TextStyle(color: Colors.grey.shade600)),
            for (final f in pendientes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(f['cliente_nombre'] as String? ?? ''),
                subtitle: Text(
                  f['numero_pedido'] != null
                      ? 'Pedido #${f['numero_pedido']}'
                      : f['cliente_telefono'] as String? ?? '',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _moneda.format(_num(f['monto'])),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _pagarFiado(f['id'] as String),
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresFoody.secundario,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Cobrar'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'venta':
        return Icons.payments;
      case 'gasto':
        return Icons.money_off;
      case 'retiro':
        return Icons.savings;
      case 'apertura':
        return Icons.lock_open;
      default:
        return Icons.receipt;
    }
  }
}
