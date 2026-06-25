import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/dialogo_stock_insuficiente.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/pedidos/data/historial_pedidos_service.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';
import 'package:reserva_canchas/features/pedidos/providers/carrito_provider.dart';
import 'package:reserva_canchas/features/zonas/data/zonas_repository.dart';
import 'package:reserva_canchas/widgets/mapa_seleccion_ubicacion.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.sucursalId,
    required this.sucursalNombre,
    this.mesaId,
    this.mesaNombre,
  });

  final String sucursalId;
  final String sucursalNombre;
  final String? mesaId;
  final String? mesaNombre;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _nit = TextEditingController();
  final _nombreFiscal = TextEditingController();
  final _email = TextEditingController();
  final _codigoPromo = TextEditingController();
  final _repo = PedidosClienteRepository();
  final _zonasRepo = ZonasRepository();
  late String _tipo;
  String _metodoPago = 'efectivo';
  bool _requiereFactura = false;
  bool _enviando = false;
  num _costoDomicilio = 5000;
  String? _zonaNombre;
  bool _cotizandoDomicilio = false;
  String? _errorDomicilio;
  double? _lat;
  double? _lng;
  bool _obteniendoUbicacion = false;
  num _descuentoPromo = 0;
  String? _codigoPromoAplicado;
  bool _validandoCodigo = false;

  @override
  void initState() {
    super.initState();
    _tipo = widget.mesaId != null ? 'mesa' : 'para_llevar';
    _cotizarDomicilio();
  }

  final _formato = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  /// `true` si la cotización fue exitosa (o no aplica).
  Future<bool> _cotizarDomicilio() async {
    if (_tipo != 'domicilio') return true;
    setState(() {
      _cotizandoDomicilio = true;
      _errorDomicilio = null;
    });
    try {
      final res = await _zonasRepo.cotizarDomicilio(
        sucursalId: widget.sucursalId,
        lat: _lat,
        lng: _lng,
      );
      if (!mounted) return false;
      setState(() {
        _costoDomicilio = res['costo'] as num? ?? 5000;
        _zonaNombre = res['zona_nombre'] as String?;
        _cotizandoDomicilio = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      final mensaje = mensajeErrorHttp(e, contexto: 'cotizar domicilio');
      setState(() {
        _cotizandoDomicilio = false;
        _errorDomicilio = mensaje;
      });
      return false;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    _nit.dispose();
    _nombreFiscal.dispose();
    _email.dispose();
    _codigoPromo.dispose();
    super.dispose();
  }

  double _totalEstimado(CarritoState carrito) {
    final tipo = _resolverTipo(carrito);
    var t = carrito.lineas.values.fold<double>(
      0,
      (sum, l) => sum + l.subtotalPara(tipo),
    );
    if (tipo == 'domicilio') t += _costoDomicilio.toDouble();
    t -= _descuentoPromo.toDouble();
    if (t < 0) t = 0;
    return t;
  }

  Future<void> _aplicarCodigoPromo(CarritoState carrito) async {
    final codigo = _codigoPromo.text.trim();
    if (codigo.isEmpty) return;
    setState(() => _validandoCodigo = true);
    try {
      final tipo = _resolverTipo(carrito);
      final subtotal = carrito.lineas.values.fold<double>(
        0,
        (sum, l) => sum + l.subtotalPara(tipo),
      );
      final res = await _repo.validarCodigoPromocion(
        sucursalId: widget.sucursalId,
        codigo: codigo,
        subtotal: subtotal,
      );
      if (!mounted) return;
      setState(() {
        _descuentoPromo = res['monto'] as num? ?? 0;
        _codigoPromoAplicado = codigo.toUpperCase();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Descuento aplicado: ${_formato.format(_descuentoPromo)}',
          ),
          backgroundColor: ColoresFoody.exito,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _descuentoPromo = 0;
          _codigoPromoAplicado = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'validar código')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _validandoCodigo = false);
    }
  }

  bool _carritoSoloEncargo(CarritoState carrito) {
    final lineas = carrito.lineas.values.toList();
    if (lineas.isEmpty) return false;
    return lineas.every((l) => l.esEncargo);
  }

  bool _carritoMezclaEncargo(CarritoState carrito) {
    final lineas = carrito.lineas.values.toList();
    final enc = lineas.any((l) => l.esEncargo);
    final normal = lineas.any((l) => !l.esEncargo);
    return enc && normal;
  }

  String _resolverTipo(CarritoState carrito) {
    if (widget.mesaId != null) return 'mesa';
    if (_carritoSoloEncargo(carrito)) return 'encargo';
    return _tipo;
  }

  bool _usaPrecioLlevar(String tipo) =>
      tipo == 'para_llevar' || tipo == 'domicilio';

  int _cantidadConPrecioLlevar(CarritoState carrito) {
    return carrito.lineas.values
        .where((l) => l.tienePrecioLlevarDistinto)
        .length;
  }

  Future<void> _usarUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activa permisos de ubicación')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      await _cotizarDomicilio();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener ubicación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _obteniendoUbicacion = false);
    }
  }

  Future<void> _abrirMapaEntrega() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MapaSeleccionUbicacion(
              titulo: 'Punto de entrega',
              latitudInicial: _lat,
              longitudInicial: _lng,
              onUbicacionSeleccionada: (lat, lng) {
                setState(() {
                  _lat = lat;
                  _lng = lng;
                });
                _cotizarDomicilio();
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmar() async {
    final carrito = ref.read(carritoProvider);
    if (carrito.lineas.isEmpty) return;

    if (_carritoMezclaEncargo(carrito)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No mezcles productos de encargo con el menú regular. Haz pedidos separados.',
          ),
        ),
      );
      return;
    }

    final tipoPedido = _resolverTipo(carrito);

    if (tipoPedido == 'domicilio' && _direccion.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica la dirección de entrega')),
      );
      return;
    }
    if (tipoPedido == 'domicilio') {
      final cotizado = await _cotizarDomicilio();
      if (!cotizado || _errorDomicilio != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _errorDomicilio ??
                    'No se pudo validar la zona de domicilio. Revisa tu ubicación.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (_requiereFactura) {
      if (_nit.text.trim().isEmpty ||
          _nombreFiscal.text.trim().isEmpty ||
          _email.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa NIT, nombre fiscal y email para la factura'),
          ),
        );
        return;
      }
    }

    setState(() => _enviando = true);
    try {
      final resultado = await _repo.crearPedido(
        sucursalId: widget.sucursalId,
        tipo: tipoPedido,
        lineas: carrito.lineas.values.toList(),
        clienteNombre: _nombre.text.trim().isEmpty ? null : _nombre.text.trim(),
        clienteTelefono:
            _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        direccionEntrega:
            tipoPedido == 'domicilio' ? _direccion.text.trim() : null,
        lat: tipoPedido == 'domicilio' ? _lat : null,
        lng: tipoPedido == 'domicilio' ? _lng : null,
        metodoPago: _metodoPago,
        mesaId: widget.mesaId,
        requiereFactura: _requiereFactura,
        nitCliente: _requiereFactura ? _nit.text.trim() : null,
        nombreFiscalCliente:
            _requiereFactura ? _nombreFiscal.text.trim() : null,
        emailCliente: _requiereFactura ? _email.text.trim() : null,
        codigoPromocion: _codigoPromoAplicado,
      );
      await HistorialPedidosService.registrar(
        pedidoId: resultado['pedido_id'] as String,
        numeroPedido: resultado['numero_pedido'] as String,
        sucursalNombre: widget.sucursalNombre,
        total: resultado['total'] as num?,
        estado: resultado['estado'] as String?,
      );
      ref.read(carritoProvider.notifier).limpiar();
      if (!mounted) return;
      final pedidoId = resultado['pedido_id'] as String;
      context.go('/pedidos/$pedidoId/seguimiento');
    } catch (e) {
      if (mounted) {
        final mostrado = await mostrarDialogoStockSiAplica(context, e);
        if (!mostrado) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'crear el pedido')),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.mesaId != null) ...[
            Card(
              color: ColoresFoody.secundario.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.table_restaurant),
                title: Text('Mesa ${widget.mesaNombre ?? ''}'),
                subtitle: const Text('El pedido irá a aprobación de la mesera'),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_carritoSoloEncargo(carrito)) ...[
            Card(
              color: ColoresFoody.acento.withValues(alpha: 0.35),
              child: const ListTile(
                leading: Icon(Icons.event_available),
                title: Text('Pedido de encargo'),
                subtitle: Text(
                  'El restaurante confirmará disponibilidad y tiempo antes de prepararlo.',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text('Tipo de pedido', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'para_llevar', label: Text('Para llevar')),
                ButtonSegment(value: 'domicilio', label: Text('Domicilio')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) {
                setState(() => _tipo = s.first);
                _cotizarDomicilio();
              },
            ),
            if (_usaPrecioLlevar(_tipo) &&
                _cantidadConPrecioLlevar(carrito) > 0) ...[
              const SizedBox(height: 12),
              Card(
                color: ColoresFoody.secundario.withValues(alpha: 0.12),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.info_outline, size: 20),
                  title: Text(
                    '${_cantidadConPrecioLlevar(carrito)} producto(s) con precio para llevar',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'El total usa el precio de canal llevar/domicilio donde aplique.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              border: OutlineInputBorder(),
            ),
          ),
          if (_tipo == 'domicilio') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _direccion,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dirección de entrega',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _obteniendoUbicacion ? null : _usarUbicacionActual,
                  icon: _obteniendoUbicacion
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Usar mi ubicación'),
                ),
                OutlinedButton.icon(
                  onPressed: _abrirMapaEntrega,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Elegir en mapa'),
                ),
              ],
            ),
            if (_lat != null && _lng != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MapaFoody(
                  altura: 140,
                  centro: LatLng(_lat!, _lng!),
                  zoom: 16,
                  interactuable: false,
                  mostrarControles: false,
                  marcadores: [
                    MarcadorFoody(lat: _lat!, lng: _lng!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (_cotizandoDomicilio)
              const LinearProgressIndicator(minHeight: 2)
            else if (_errorDomicilio != null)
              Text(
                _errorDomicilio!,
                style: TextStyle(color: ColoresFoody.error, fontSize: 13),
              )
            else
              Text(
                'Costo domicilio: ${_formato.format(_costoDomicilio)}'
                '${_zonaNombre != null ? ' ($_zonaNombre)' : ''}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
          ],
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Necesito factura'),
            subtitle: const Text('Te pediremos datos fiscales'),
            value: _requiereFactura,
            onChanged: (v) => setState(() => _requiereFactura = v),
          ),
          if (_requiereFactura) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _nit,
              decoration: const InputDecoration(
                labelText: 'NIT o cédula',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreFiscal,
              decoration: const InputDecoration(
                labelText: 'Nombre o razón social',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Método de pago', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Efectivo'),
                selected: _metodoPago == 'efectivo',
                onSelected: (_) => setState(() => _metodoPago = 'efectivo'),
              ),
              ChoiceChip(
                label: const Text('Nequi'),
                selected: _metodoPago == 'nequi',
                onSelected: (_) => setState(() => _metodoPago = 'nequi'),
              ),
              ChoiceChip(
                label: const Text('Tarjeta'),
                selected: _metodoPago == 'tarjeta',
                onSelected: (_) => setState(() => _metodoPago = 'tarjeta'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoPromo,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Código promocional',
                    border: const OutlineInputBorder(),
                    suffixIcon: _codigoPromoAplicado != null
                        ? Icon(Icons.check_circle, color: ColoresFoody.exito)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _validandoCodigo
                    ? null
                    : () => _aplicarCodigoPromo(carrito),
                child: _validandoCodigo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aplicar'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${carrito.totalItems} productos'),
                  if (_tipo == 'domicilio')
                    Text('Domicilio: ${_formato.format(_costoDomicilio)}'),
                  if (_descuentoPromo > 0)
                    Text(
                      'Descuento ($_codigoPromoAplicado): -${_formato.format(_descuentoPromo)}',
                      style: const TextStyle(color: ColoresFoody.exito),
                    ),
                  const Divider(),
                  Text(
                    'Total estimado: ${_formato.format(_totalEstimado(carrito))}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: ColoresFoody.primario,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El total final lo confirma el restaurante al aceptar tu pedido.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _enviando ? null : _confirmar,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresFoody.primario,
              minimumSize: const Size.fromHeight(52),
            ),
            child: _enviando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Hacer pedido'),
          ),
        ),
      ),
    );
  }
}
