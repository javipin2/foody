import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:reserva_canchas/core/mapas/mapa_foody.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:reserva_canchas/core/red/dialogo_stock_insuficiente.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/widgets/foody_pasos_pedido.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cliente/presentation/foody_scaffold_cliente.dart';
import 'package:reserva_canchas/features/pedidos/data/historial_pedidos_service.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';
import 'package:reserva_canchas/features/pedidos/presentation/validar_telefono_checkout.dart';
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
  final _formContactoKey = GlobalKey<FormState>();
  final _telefonoFocusNode = FocusNode();
  final _direccion = TextEditingController();
  final _nit = TextEditingController();
  final _nombreFiscal = TextEditingController();
  final _email = TextEditingController();
  final _codigoPromo = TextEditingController();
  final _propina = TextEditingController(text: '0');
  final _repo = PedidosClienteRepository();
  final _zonasRepo = ZonasRepository();
  late String _tipo;
  String _metodoPago = 'efectivo';
  bool _requiereFactura = false;
  bool _enviando = false;
  final _idempotencyKey = const Uuid().v4();
  num _costoDomicilio = 5000;
  String? _zonaNombre;
  bool _costoDomicilioEstimado = true;
  bool _cotizandoDomicilio = false;
  String? _errorDomicilio;
  double? _lat;
  double? _lng;
  bool _obteniendoUbicacion = false;
  num _descuentoPromo = 0;
  String? _codigoPromoAplicado;
  DateTime? _fechaEncargo;
  bool _validandoCodigo = false;
  String? _errorFormulario;
  String? _errorDireccion;
  String? _errorFactura;
  String? _errorEncargo;
  final _scrollCtrl = ScrollController();

  /// Totales de `POST /pedidos/estimar` (autoritativos).
  num? _totalServidor;
  bool _estimando = false;
  String? _errorEstimar;

  @override
  void initState() {
    super.initState();
    _tipo = widget.mesaId != null ? 'mesa' : 'para_llevar';
    _cotizarDomicilio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final carrito = ref.read(carritoProvider);
      _refrescarEstimar(carrito);
    });
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
        _costoDomicilioEstimado = res['distancia_km'] == null;
        _cotizandoDomicilio = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      final mensaje = mensajeErrorCliente(e, contexto: 'cotizar domicilio');
      setState(() {
        _cotizandoDomicilio = false;
        _errorDomicilio = mensaje;
      });
      return false;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nombre.dispose();
    _telefono.dispose();
    _telefonoFocusNode.dispose();
    _direccion.dispose();
    _nit.dispose();
    _nombreFiscal.dispose();
    _email.dispose();
    _codigoPromo.dispose();
    _propina.dispose();
    super.dispose();
  }

  /// Fallback UI si estimar falla (red); cobro real sigue en POST /pedidos.
  double _totalEstimadoLocal(CarritoState carrito) {
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

  double _totalMostrar(CarritoState carrito) {
    if (_totalServidor != null) return _totalServidor!.toDouble();
    return _totalEstimadoLocal(carrito);
  }

  Future<void> _refrescarEstimar(CarritoState carrito) async {
    if (carrito.lineas.isEmpty) {
      if (mounted) {
        setState(() {
          _totalServidor = 0;
          _estimando = false;
          _errorEstimar = null;
        });
      }
      return;
    }
    if (mounted) setState(() => _estimando = true);
    try {
      final tipo = _resolverTipo(carrito);
      final datos = await _repo.estimarTotales(
        sucursalId: widget.sucursalId,
        tipo: tipo,
        lineas: carrito.lineas.values.toList(),
        mesaId: widget.mesaId,
        lat: _lat,
        lng: _lng,
        codigoPromocion: _codigoPromoAplicado,
      );
      if (!mounted) return;
      setState(() {
        _totalServidor = datos['total'] as num? ?? 0;
        _descuentoPromo = datos['descuento'] as num? ?? 0;
        if (tipo == 'domicilio') {
          _costoDomicilio = datos['costo_domicilio'] as num? ?? _costoDomicilio;
        }
        _estimando = false;
        _errorEstimar = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estimando = false;
        _errorEstimar = mensajeErrorCliente(e, contexto: 'estimar total');
        _totalServidor = null;
      });
    }
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
        _validandoCodigo = false;
      });
      await _refrescarEstimar(carrito);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Descuento aplicado: ${_formato.format(_descuentoPromo)}',
          ),
          backgroundColor: AnaliticaTokens.inventario,
          behavior: SnackBarBehavior.floating,
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
            backgroundColor: AnaliticaTokens.alertas,
            behavior: SnackBarBehavior.floating,
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

  void _mostrarErrorFormulario(String mensaje) {
    setState(() => _errorFormulario = mensaje);
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _confirmar() async {
    final carrito = ref.read(carritoProvider);
    if (carrito.lineas.isEmpty) return;

    setState(() {
      _errorFormulario = null;
      _errorDireccion = null;
      _errorFactura = null;
      _errorEncargo = null;
    });

    if (_carritoMezclaEncargo(carrito)) {
      _mostrarErrorFormulario(
        'No mezcles productos de encargo con el menú regular. Haz pedidos separados.',
      );
      return;
    }

    final tipoPedido = _resolverTipo(carrito);

    final contactoValido = _formContactoKey.currentState!.validate();
    if (!contactoValido) {
      _telefonoFocusNode.requestFocus();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    _formContactoKey.currentState!.save();

    if (tipoPedido == 'domicilio' && _direccion.text.trim().isEmpty) {
      setState(() {
        _errorDireccion = 'Indica la dirección de entrega';
        _errorFormulario = 'Completa la dirección de entrega';
      });
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (tipoPedido == 'encargo' && _fechaEncargo == null) {
      setState(() {
        _errorEncargo = 'Selecciona la fecha deseada (mínimo 2 días)';
        _errorFormulario = _errorEncargo;
      });
      return;
    }
    if (tipoPedido == 'domicilio') {
      final cotizado = await _cotizarDomicilio();
      if (!cotizado || _errorDomicilio != null) {
        if (mounted) {
          _mostrarErrorFormulario(
            _errorDomicilio ??
                'No se pudo validar la zona de domicilio. Revisa tu ubicación.',
          );
        }
        return;
      }
    }

    if (_requiereFactura) {
      if (_nit.text.trim().isEmpty ||
          _nombreFiscal.text.trim().isEmpty ||
          _email.text.trim().isEmpty) {
        setState(() {
          _errorFactura = 'Completa NIT, nombre fiscal y email para la factura';
          _errorFormulario = _errorFactura;
        });
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
        propina: widget.mesaId == null
            ? double.tryParse(_propina.text.replaceAll(',', '').trim())
            : null,
        idempotencyKey: _idempotencyKey,
        fechaEntregaDeseada: tipoPedido == 'encargo'
            ? DateFormat('yyyy-MM-dd').format(_fechaEncargo!)
            : null,
      );
      TextInput.finishAutofillContext(shouldSave: true);
      await HistorialPedidosService.registrar(
        pedidoId: resultado['pedido_id'] as String,
        numeroPedido: resultado['numero_pedido'] as String,
        sucursalNombre: widget.sucursalNombre,
        total: resultado['total'] as num?,
        estado: resultado['estado'] as String?,
        seguimientoToken: resultado['seguimiento_token'] as String?,
      );
      ref.read(carritoProvider.notifier).limpiar();
      if (!mounted) return;
      final pedidoId = resultado['pedido_id'] as String;
      final token = resultado['seguimiento_token'] as String?;
      final qs = token != null && token.isNotEmpty ? '?token=$token' : '';
      context.go('/pedidos/$pedidoId/seguimiento$qs');
    } catch (e) {
      if (mounted) {
        final mostrado = await mostrarDialogoStockSiAplica(context, e);
        if (!mounted) return;
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

  InputDecoration _campo({
    required String label,
    String? hint,
    String? errorText,
    String? helperText,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      helperText: helperText,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        borderSide: const BorderSide(color: AnaliticaTokens.alertas),
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Text(
      texto,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
    );
  }

  Widget _chipPago(String valor, String etiqueta) {
    final selected = _metodoPago == valor;
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(etiqueta),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _metodoPago = valor),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surface,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);
    final total = _totalMostrar(carrito);
    final scheme = Theme.of(context).colorScheme;

    return FoodyScaffoldCliente(
      mostrarNavInferior: false,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmar pedido',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              widget.sucursalNombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ColoredBox(
        color: AnaliticaTokens.canvasOf(context),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const FoodyPasosPedido(pasoActual: 2),
                Text(
                  'Completa tus datos. El restaurante confirma el total al aceptar.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                if (_errorFormulario != null) ...[
                  Material(
                    color: AnaliticaTokens.alertas.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AnaliticaTokens.alertas,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorFormulario!,
                              style: const TextStyle(
                                color: AnaliticaTokens.alertas,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.mesaId != null) ...[
                  Card(
                    elevation: 0,
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.table_restaurant_rounded,
                        color: scheme.primary,
                      ),
                      title: Text(
                        'Mesa ${widget.mesaNombre ?? ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'El pedido irá a aprobación de la mesera',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_carritoSoloEncargo(carrito)) ...[
                  Card(
                    elevation: 0,
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.event_available_rounded,
                            color: scheme.primary,
                          ),
                          title: Text(
                            'Pedido de encargo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'El restaurante confirmará disponibilidad y tiempo antes de prepararlo.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.calendar_today_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                          title: Text(
                            _fechaEncargo == null
                                ? 'Fecha de entrega deseada'
                                : DateFormat.yMMMd('es').format(_fechaEncargo!),
                            style: TextStyle(color: scheme.onSurface),
                          ),
                          subtitle: Text(
                            _errorEncargo ?? 'Mínimo 2 días de anticipación',
                            style: TextStyle(
                              color: _errorEncargo != null
                                  ? AnaliticaTokens.alertas
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final hoy = DateTime.now();
                            final minima =
                                DateTime(hoy.year, hoy.month, hoy.day + 2);
                            final maxima =
                                DateTime(hoy.year + 1, hoy.month, hoy.day);
                            final elegida = await showDatePicker(
                              context: context,
                              initialDate: _fechaEncargo ?? minima,
                              firstDate: minima,
                              lastDate: maxima,
                              locale: const Locale('es'),
                            );
                            if (elegida != null) {
                              setState(() {
                                _fechaEncargo = elegida;
                                _errorEncargo = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _tituloSeccion('Tipo de pedido'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return scheme.primary;
                        }
                        return scheme.surface;
                      }),
                      foregroundColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return scheme.onPrimary;
                        }
                        return scheme.onSurface;
                      }),
                      side: WidgetStateProperty.all(
                        BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: 'para_llevar',
                        label: Text('paso por el local'),
                        icon: Icon(Icons.shopping_bag_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: 'domicilio',
                        label: Text('Domicilio'),
                        icon: Icon(Icons.delivery_dining_outlined, size: 18),
                      ),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (s) {
                      setState(() => _tipo = s.first);
                      _cotizarDomicilio().then((_) {
                        if (mounted) _refrescarEstimar(carrito);
                      });
                    },
                  ),
                  if (_usaPrecioLlevar(_tipo) &&
                      _cantidadConPrecioLlevar(carrito) > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r12),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          '${_cantidadConPrecioLlevar(carrito)} producto(s) con precio para llevar',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'El total usa el precio de canal llevar/domicilio donde aplique.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
                _tituloSeccion('Tus datos'),
                const SizedBox(height: 8),
                AutofillGroup(
                  child: Form(
                    key: _formContactoKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombre,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          style: TextStyle(color: scheme.onSurface),
                          decoration: _campo(label: 'Nombre'),
                          onSaved: (value) => _nombre.text = value?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefono,
                          focusNode: _telefonoFocusNode,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          style: TextStyle(color: scheme.onSurface),
                          decoration: _campo(label: 'Teléfono', helperText: ' ')
                              .copyWith(errorMaxLines: 2),
                          validator: (value) => validarTelefonoCheckout(
                            value,
                            domicilio: _resolverTipo(ref.read(carritoProvider)) ==
                                'domicilio',
                          ),
                          onSaved: (value) => _telefono.text = value?.trim() ?? '',
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_tipo == 'domicilio') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _direccion,
                    maxLines: 2,
                    style: TextStyle(color: scheme.onSurface),
                    onChanged: (_) {
                      if (_errorDireccion != null) {
                        setState(() => _errorDireccion = null);
                      }
                    },
                    decoration: _campo(
                      label: 'Dirección de entrega',
                      errorText: _errorDireccion,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _obteniendoUbicacion ? null : _usarUbicacionActual,
                        icon: _obteniendoUbicacion
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: const Text('Usar mi ubicación'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.primary,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _abrirMapaEntrega,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Elegir en mapa'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.primary,
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ],
                  ),
                  if (_lat != null && _lng != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
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
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: scheme.primary,
                    )
                  else if (_errorDomicilio != null)
                    Text(
                      _errorDomicilio!,
                      style: const TextStyle(
                        color: AnaliticaTokens.alertas,
                        fontSize: 13,
                      ),
                    )
                  else
                    Text(
                      '${_costoDomicilioEstimado ? 'Costo domicilio estimado' : 'Costo domicilio'}: '
                      '${_formato.format(_costoDomicilio)}'
                      '${_costoDomicilioEstimado ? ' (puede cambiar al confirmar la ubicación)' : ''}'
                      '${_zonaNombre != null ? ' ($_zonaNombre)' : ''}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: scheme.primary,
                        ),
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    collapsedIconColor: scheme.onSurfaceVariant,
                    iconColor: scheme.primary,
                    title: Text(
                      'Factura (opcional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Solo si necesitas datos fiscales',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                    initiallyExpanded: false,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: scheme.primary,
                        title: Text(
                          'Necesito factura',
                          style: TextStyle(color: scheme.onSurface),
                        ),
                        subtitle: Text(
                          'Te pediremos NIT y razón social',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        value: _requiereFactura,
                        onChanged: (v) => setState(() => _requiereFactura = v),
                      ),
                      if (_requiereFactura) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nit,
                          style: TextStyle(color: scheme.onSurface),
                          decoration: _campo(
                            label: 'NIT o cédula',
                            errorText: _errorFactura,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nombreFiscal,
                          style: TextStyle(color: scheme.onSurface),
                          decoration: _campo(label: 'Nombre o razón social'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: scheme.onSurface),
                          decoration: _campo(label: 'Email'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.mesaId == null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _propina,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: scheme.onSurface),
                    decoration: _campo(
                      label: 'Propina (opcional)',
                      hint: '0',
                      prefixText: r'$ ',
                      helperText: 'Se registra al cobrar tu pedido',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _tituloSeccion('Método de pago'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chipPago('efectivo', 'Efectivo'),
                    _chipPago('nequi', 'Nequi'),
                    _chipPago('tarjeta', 'Tarjeta'),
                  ],
                ),
                const SizedBox(height: 20),
                _tituloSeccion('Código promocional'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoPromo,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(color: scheme.onSurface),
                        decoration: _campo(
                          label: 'Código',
                          suffixIcon: _codigoPromoAplicado != null
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AnaliticaTokens.inventario,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _validandoCodigo
                          ? null
                          : () => _aplicarCodigoPromo(carrito),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(96, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                        ),
                      ),
                      child: _validandoCodigo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Aplicar'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${carrito.totalItems} ${carrito.totalItems == 1 ? 'producto' : 'productos'}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_tipo == 'domicilio') ...[
                          const SizedBox(height: 4),
                          Text(
                            'Domicilio: ${_formato.format(_costoDomicilio)}',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                        ],
                        if (_descuentoPromo > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Descuento ($_codigoPromoAplicado): -${_formato.format(_descuentoPromo)}',
                            style: const TextStyle(
                              color: AnaliticaTokens.inventario,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        Divider(height: 20, color: scheme.outlineVariant),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _estimando
                                  ? 'Calculando…'
                                  : (_totalServidor != null
                                      ? 'Total'
                                      : 'Total estimado'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              _formato.format(total),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: scheme.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        if (_errorEstimar != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _errorEstimar!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AnaliticaTokens.alertas,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'El total final lo confirma el restaurante al aceptar tu pedido.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomBar: Material(
        elevation: 0,
        color: scheme.surface,
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  onPressed: _enviando ? null : _confirmar,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                    ),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Hacer pedido · ${_formato.format(total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
