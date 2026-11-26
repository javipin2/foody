import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/dialogo_stock_insuficiente.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_combo_sheet.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_producto_sheet.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

bool esDireccionDomicilioPendiente(String direccion) {
  final normalizada = direccion.trim().toLowerCase();
  return normalizada.isEmpty ||
      const {
        'por confirmar',
        'pendiente',
        'por definir',
        'n/a',
        'na',
        'sin dirección',
        'sin direccion',
      }.contains(normalizada);
}

/// Constructor de pedido staff — layout POS (ref. foody_redesign_complete.html).
class PedidoCajeroScreen extends StatefulWidget {
  const PedidoCajeroScreen({
    super.key,
    this.sucursalId,
    this.mesaIdFija,
    this.mesaNombreFija,
    this.modoMesero = false,
    this.pedidoIdAgregar,
    this.itemIdReemplazar,
    this.onPedidoModificado,
    this.ocultarCabecera = false,
    this.onIrCaja,
    this.menuRepository,
    this.mesasRepository,
    this.cajaRepository,
    this.pedidosRepository,
  });

  final String? sucursalId;
  final String? mesaIdFija;
  final String? mesaNombreFija;
  final bool modoMesero;

  /// Si se indica, los ítems se suman a este pedido (consumo en mesa).
  final String? pedidoIdAgregar;

  /// Si se indica junto a [pedidoIdAgregar], tras agregar se elimina este ítem.
  final String? itemIdReemplazar;

  /// Tras agregar (y opcional reemplazo). Panel limpia sticky y vuelve a pedidos.
  final VoidCallback? onPedidoModificado;

  /// NAV-CJ-01: shell cajero ya muestra el título.
  final bool ocultarCabecera;

  /// NAV-ADM2-10: saltar a Caja cuando no hay turno abierto.
  final VoidCallback? onIrCaja;
  final MenuRepository? menuRepository;
  final MesasRepository? mesasRepository;
  final CajaRepository? cajaRepository;
  final PedidosRepository? pedidosRepository;

  @override
  State<PedidoCajeroScreen> createState() => _PedidoCajeroScreenState();
}

class _PedidoCajeroScreenState extends State<PedidoCajeroScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final MenuRepository _menuRepo;
  late final _pedidosRepo = widget.pedidosRepository ?? PedidosRepository();
  late final MesasRepository _mesasRepo;
  late final CajaRepository _cajaRepo;
  final _busquedaCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  MenuModel? _menu;
  List<Map<String, dynamic>> _mesas = [];
  final List<LineaCarrito> _carrito = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _idempotencyKeyOperacion;
  String? _firmaIdempotenciaOperacion;
  String? _error;
  bool? _cajaAbierta;
  String? _errorConsultaCaja;
  bool _ocultarAvisoHorario = false;

  String _tipoPedido = 'mesa';
  String? _mesaId;
  String _metodoPago = 'efectivo';
  String _metodoPago2 = 'tarjeta';
  bool _pagoMixto = false;
  final _montoMixto1Ctrl = TextEditingController();
  final _montoMixto2Ctrl = TextEditingController();
  final _propinaCtrl = TextEditingController(text: '0');
  final _clienteNombreCtrl = TextEditingController();
  final _clienteTelCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  Timer? _timerEstimacion;
  int _versionEstimacion = 0;
  num? _totalEstimadoServidor;
  bool _estimandoTotal = false;
  String? _errorEstimacion;
  String _categoriaId = 'todo';
  RealtimeChannel? _canalCatalogo;
  PollRealtimeRespaldo? _pollRespaldo;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  /// Hint local; cobro real vía API. Preview POS: preferir /pedidos/estimar (F4).
  double get _totalVisual =>
      _carrito.fold<double>(0, (s, l) => s + l.subtotalPara(_tipoPedido));

  double? _monto(String valor) =>
      double.tryParse(valor.replaceAll(',', '').trim());

  String get _etiquetaMetodoPago => switch (_tipoPedido) {
        'mesa' => 'Método previsto al cobrar',
        'domicilio' => 'Método de pago al entregar',
        _ => 'Cobro ahora',
      };

  String get _ayudaMetodoPago => switch (_tipoPedido) {
        'mesa' =>
          'No se cobra al crear el pedido. Confirma el método al cerrar la cuenta.',
        'domicilio' when _metodoPago == 'pendiente' =>
          'El repartidor debe indicar el método. Si Admin marca la entrega manualmente, se registra efectivo.',
        'domicilio' =>
          'El repartidor confirma el método al entregar; Admin puede marcar la entrega manual desde Pedidos.',
        _ when _metodoPago == 'pendiente' =>
          'El cobro queda pendiente y no se registra en Caja todavía.',
        _ => 'El cobro se registra en Caja al confirmar el pedido.',
      };

  String? get _errorPagoMixto {
    if (!_pagoMixto) return null;
    if (_estimandoTotal) return 'Actualizando el total del pedido…';
    final total = _totalEstimadoServidor;
    if (total == null) {
      return _errorEstimacion ?? 'No hay un total del servidor para dividir.';
    }
    final monto1 = _monto(_montoMixto1Ctrl.text);
    final monto2 = _monto(_montoMixto2Ctrl.text);
    if (monto1 == null || monto2 == null || monto1 <= 0 || monto2 <= 0) {
      return 'Ingresa dos montos mayores que cero.';
    }
    if ((monto1 + monto2 - total).abs() > 0.01) {
      return 'Los pagos deben sumar ${_moneda.format(total)}.';
    }
    return null;
  }

  bool get _requiereCotizacionParaConfirmar =>
      !widget.modoMesero &&
      widget.pedidoIdAgregar == null &&
      _tipoPedido == 'para_llevar' &&
      _metodoPago != 'pendiente';

  bool get _bloqueadoPorCotizacion =>
      _requiereCotizacionParaConfirmar &&
      (_estimandoTotal || _totalEstimadoServidor == null);

  void _programarEstimacion() {
    _timerEstimacion?.cancel();
    final version = ++_versionEstimacion;
    if (_carrito.isEmpty || widget.pedidoIdAgregar != null) {
      setState(() {
        _totalEstimadoServidor = null;
        _estimandoTotal = false;
        _errorEstimacion = null;
      });
      return;
    }
    if (_tipoPedido == 'domicilio' &&
        esDireccionDomicilioPendiente(_direccionCtrl.text)) {
      setState(() {
        _totalEstimadoServidor = null;
        _estimandoTotal = false;
        _errorEstimacion = 'Ingresa la dirección para cotizar el domicilio.';
      });
      return;
    }
    setState(() {
      _totalEstimadoServidor = null;
      _estimandoTotal = true;
      _errorEstimacion = null;
    });
    final lineas = List<LineaCarrito>.of(_carrito);
    final tipo = _tipoPedido;
    final mesaId = tipo == 'mesa' ? (widget.mesaIdFija ?? _mesaId) : null;
    final direccion = tipo == 'domicilio' ? _direccionCtrl.text.trim() : null;
    _timerEstimacion = Timer(const Duration(milliseconds: 300), () async {
      try {
        final sid = widget.sucursalId;
        if (sid == null) throw StateError('Sin sucursal para estimar.');
        final datos = await _pedidosRepo.estimarTotales(
          sucursalId: sid,
          tipo: tipo,
          lineas: lineas,
          mesaId: mesaId,
          direccionEntrega: direccion,
        );
        final total = datos['total'];
        if (total is! num) {
          throw const FormatException('El servidor no devolvió total.');
        }
        if (!mounted || version != _versionEstimacion) return;
        setState(() {
          _totalEstimadoServidor = total;
          _estimandoTotal = false;
          _errorEstimacion = null;
        });
      } catch (e) {
        if (!mounted || version != _versionEstimacion) return;
        setState(() {
          _totalEstimadoServidor = null;
          _estimandoTotal = false;
          _errorEstimacion = mensajeErrorHttp(e, contexto: 'estimar pedido');
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _menuRepo = widget.menuRepository ?? MenuRepository();
    _mesasRepo = widget.mesasRepository ?? MesasRepository();
    _cajaRepo = widget.cajaRepository ?? CajaRepository();
    _tipoPedido = widget.modoMesero ? 'mesa' : 'para_llevar';
    // El flujo de mesero registra el pedido sin cobrar; no debe enviar el
    // valor POS predeterminado (efectivo) mientras la UI oculta ese selector.
    if (widget.modoMesero) _metodoPago = 'pendiente';
    _mesaId = widget.mesaIdFija;
    _cargar();
    final sid = widget.sucursalId;
    if (sid != null && AppBackend.supabaseReady) {
      _canalCatalogo = FoodyRealtime.suscribirCatalogo(
        sid,
        onCatalogoActualizado: () {
          if (mounted) _cargar(silencioso: true);
        },
        onReconectado: () {
          if (mounted) _cargar(silencioso: true);
        },
      );
    }
    // RT-FALL-01: POS sin poll → menú stale si cae RT.
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) await _cargar(silencioso: true);
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  @override
  void dispose() {
    _pollRespaldo?.detener();
    _timerEstimacion?.cancel();
    _versionEstimacion++;
    FoodyRealtime.liberarCanal(_canalCatalogo);
    _busquedaCtrl.dispose();
    _notaCtrl.dispose();
    _montoMixto1Ctrl.dispose();
    _montoMixto2Ctrl.dispose();
    _propinaCtrl.dispose();
    _clienteNombreCtrl.dispose();
    _clienteTelCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      Object? errorConsultaCaja;
      final consultaCaja = _cajaRepo.cajaActiva(sid).catchError((Object error) {
        errorConsultaCaja = error;
        return null;
      });
      final resultados = await Future.wait<Object?>([
        _menuRepo.obtenerPorSucursal(sid),
        _mesasRepo.listar(sid),
        consultaCaja,
      ]);
      final menu = resultados[0] as MenuModel;
      final mesas = resultados[1] as List<Map<String, dynamic>>;
      final caja = resultados[2] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _menu = menu;
        _mesas = mesas.where((m) => m['activa'] != false).toList();
        if (_mesaId == null && _mesas.isNotEmpty && _tipoPedido == 'mesa') {
          _mesaId = _mesas.first['id'] as String?;
        }
        _cajaAbierta = errorConsultaCaja == null ? caja != null : null;
        _errorConsultaCaja = errorConsultaCaja == null
            ? null
            : mensajeErrorHttp(errorConsultaCaja!, contexto: 'consultar caja');
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silencioso) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'cargar POS');
        _cargando = false;
      });
    }
  }

  void _agregarProducto(ProductoMenuModel producto) {
    if (!producto.disponible) return;
    final menu = _menu;
    DetalleProductoSheet.mostrar(
      context,
      producto: producto,
      sugerenciasBebidas:
          menu == null || menu.productoEsDeCategoriaBebidas(producto)
              ? const []
              : menu.productosBebidasVendibles(excluirId: producto.id),
      onAgregar: (lineas) {
        setState(() => _carrito.addAll(lineas));
        _programarEstimacion();
      },
    );
  }

  void _agregarCombo(ComboMenuModel combo) {
    if (!combo.disponible) return;
    final menu = _menu;
    final tops = <OpcionMenuModel>[];
    final seenT = <String>{};
    if (menu != null) {
      for (final ci in combo.items) {
        if (ci.tipoItem != 'producto' || ci.itemId == null) continue;
        for (final p in menu.todosLosProductos) {
          if (p.id != ci.itemId) continue;
          for (final t in p.toppings) {
            if (seenT.add(t.id)) tops.add(t);
          }
        }
      }
    }
    DetalleComboSheet.mostrar(
      context,
      combo: combo,
      toppingsDisponibles: tops,
      sugerenciasBebidas: menu?.productosBebidasVendibles() ?? const [],
      onAgregar: (lineas) {
        setState(() => _carrito.addAll(lineas));
        _programarEstimacion();
      },
    );
  }

  void _cambiarCantidad(int index, int delta) {
    final l = _carrito[index];
    final nueva = l.cantidad + delta;
    if (nueva <= 0) {
      setState(() => _carrito.removeAt(index));
      _programarEstimacion();
      return;
    }
    setState(() {
      _carrito[index] = LineaCarrito(
        clave: l.clave,
        productoId: l.productoId,
        comboId: l.comboId,
        nombre: l.nombre,
        precioUnitario: l.precioUnitario,
        precioUnitarioLlevar: l.precioUnitarioLlevar,
        cantidad: nueva,
        toppings: l.toppings,
        bebidas: l.bebidas,
        observaciones: l.observaciones,
        imagenUrl: l.imagenUrl,
      );
    });
    _programarEstimacion();
  }

  Future<void> _confirmarPedido() async {
    final sid = widget.sucursalId;
    if (sid == null || _carrito.isEmpty) return;

    if (_pagoMixto && _errorPagoMixto != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorPagoMixto!)),
      );
      return;
    }

    if (_bloqueadoPorCotizacion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calcula el total con Foody antes de cobrar.'),
        ),
      );
      return;
    }

    if (!widget.modoMesero && _cajaAbierta != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cajaAbierta == null
                ? 'No se pudo verificar la caja. Reintenta la consulta.'
                : 'Abre la caja antes de registrar ventas.',
          ),
          action: _cajaAbierta == null
              ? SnackBarAction(
                  label: 'Reintentar',
                  onPressed: () => _cargar(silencioso: true),
                )
              : widget.onIrCaja == null
                  ? null
                  : SnackBarAction(
                      label: 'Ir a caja',
                      onPressed: widget.onIrCaja!,
                    ),
        ),
      );
      return;
    }

    if (_tipoPedido == 'mesa' &&
        widget.pedidoIdAgregar == null &&
        (_mesaId == null || _mesaId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una mesa')),
      );
      return;
    }

    if (_tipoPedido == 'domicilio' && widget.pedidoIdAgregar == null) {
      final nombre = _clienteNombreCtrl.text.trim();
      final tel = _clienteTelCtrl.text.trim();
      final dir = _direccionCtrl.text.trim();
      if (nombre.isEmpty || tel.isEmpty || esDireccionDomicilioPendiente(dir)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Domicilio: nombre y teléfono son obligatorios; ingresa una dirección real',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _enviando = true);
    try {
      final agregarAPedido =
          widget.pedidoIdAgregar != null && widget.pedidoIdAgregar!.isNotEmpty;
      final mesaVinculada =
          widget.mesaIdFija ?? (_tipoPedido == 'mesa' ? _mesaId : null);

      List<Map<String, dynamic>>? pagos;
      if (!widget.modoMesero &&
          _tipoPedido == 'para_llevar' &&
          _pagoMixto &&
          _metodoPago != 'pendiente') {
        final m1 = _monto(_montoMixto1Ctrl.text)!;
        final m2 = _monto(_montoMixto2Ctrl.text)!;
        pagos = [
          {'metodo_pago': _metodoPago, 'monto': m1},
          {'metodo_pago': _metodoPago2, 'monto': m2},
        ];
      }

      final nota = _notaCtrl.text.trim();
      final propina = double.tryParse(_propinaCtrl.text.replaceAll(',', ''));
      final propinaOperacion = (!widget.modoMesero &&
              _tipoPedido == 'para_llevar' &&
              _metodoPago != 'pendiente' &&
              propina != null &&
              propina > 0)
          ? propina
          : null;
      final observacionesOperacion = nota.isNotEmpty ? nota : null;
      final nombreClienteOperacion =
          _tipoPedido == 'domicilio' ? _clienteNombreCtrl.text.trim() : null;
      final telefonoClienteOperacion =
          _tipoPedido == 'domicilio' ? _clienteTelCtrl.text.trim() : null;
      final direccionOperacion =
          _tipoPedido == 'domicilio' ? _direccionCtrl.text.trim() : null;
      final firmaOperacion = jsonEncode({
        'sucursal_id': sid,
        'tipo': _tipoPedido,
        'mesa_id': mesaVinculada,
        'pedido_id_agregar': agregarAPedido ? widget.pedidoIdAgregar : null,
        'item_id_reemplazar': widget.itemIdReemplazar,
        'cliente_nombre': nombreClienteOperacion,
        'cliente_telefono': telefonoClienteOperacion,
        'direccion_entrega': direccionOperacion,
        'metodo_pago': pagos != null ? null : _metodoPago,
        'pagos': pagos,
        'propina': propinaOperacion,
        'observaciones': observacionesOperacion,
        'lineas': _carrito
            .map(
              (linea) => {
                'producto_id': linea.productoId,
                'combo_id': linea.comboId,
                'cantidad': linea.cantidad,
                'precio': linea.precioUnitarioPara(_tipoPedido),
                'observaciones': linea.observaciones,
                'toppings': linea.toppings.map((t) => t.id).toList()..sort(),
                'bebidas': linea.bebidas
                    .map((b) => {'id': b.id, 'cantidad': b.cantidad})
                    .toList()
                  ..sort((a, b) =>
                      (a['id'] as String).compareTo(b['id'] as String)),
              },
            )
            .toList(),
      });
      if (_firmaIdempotenciaOperacion != firmaOperacion) {
        _idempotencyKeyOperacion = null;
        _firmaIdempotenciaOperacion = firmaOperacion;
      }
      final idempotencyKey = _idempotencyKeyOperacion ??= const Uuid().v4();
      final datos = await _pedidosRepo.crearPedidoStaff(
        sucursalId: sid,
        tipo: _tipoPedido,
        lineas: _carrito,
        metodoPago: pagos != null ? null : _metodoPago,
        pagos: pagos,
        mesaId: widget.modoMesero && widget.mesaIdFija != null
            ? widget.mesaIdFija
            : mesaVinculada,
        pedidoIdAgregar: agregarAPedido ? widget.pedidoIdAgregar : null,
        itemIdReemplazar: agregarAPedido ? widget.itemIdReemplazar : null,
        clienteNombre: nombreClienteOperacion,
        clienteTelefono: telefonoClienteOperacion,
        direccionEntrega: direccionOperacion,
        observaciones: observacionesOperacion,
        propina: propinaOperacion,
        idempotencyKey: idempotencyKey,
        totalEsperado: _requiereCotizacionParaConfirmar
            ? _totalEstimadoServidor?.toDouble()
            : null,
      );
      if (!mounted) return;
      final pendiente = _metodoPago == 'pendiente' &&
          !widget.modoMesero &&
          _tipoPedido == 'para_llevar';
      setState(() {
        _idempotencyKeyOperacion = null;
        _firmaIdempotenciaOperacion = null;
        _carrito.clear();
        _totalEstimadoServidor = null;
        _errorEstimacion = null;
        _estimandoTotal = false;
        _notaCtrl.clear();
        _propinaCtrl.text = '0';
        if (_tipoPedido == 'domicilio') {
          _clienteNombreCtrl.clear();
          _clienteTelCtrl.clear();
          _direccionCtrl.clear();
        }
        _enviando = false;
      });
      _programarEstimacion();

      if (!mounted) return;
      final numPedido = datos['numero_pedido'] ?? datos['id'];
      if (widget.modoMesero) {
        Navigator.of(context).pop(true);
      } else {
        final messenger = ScaffoldMessenger.of(context);
        if (agregarAPedido) {
          widget.onPedidoModificado?.call();
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.itemIdReemplazar != null && agregarAPedido
                  ? 'Producto cambiado · $numPedido'
                  : agregarAPedido
                      ? 'Ítems agregados · $numPedido'
                      : 'Pedido creado · $numPedido',
            ),
            backgroundColor: AnaliticaTokens.inventario,
            duration: const Duration(seconds: 4),
          ),
        );
        if (pendiente) {
          await _ofrecerRegistrarFiado(
            sucursalId: sid,
            pedido: datos,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      if (codigoErrorApi(e) == 'TOTAL_PEDIDO_CAMBIO' && e is DioException) {
        final datos = e.response?.data;
        if (datos is Map && datos['total_actual'] is num) {
          final anterior = datos['total_esperado'] is num
              ? (datos['total_esperado'] as num).toDouble()
              : _totalEstimadoServidor?.toDouble();
          final actual = (datos['total_actual'] as num).toDouble();
          setState(() => _totalEstimadoServidor = actual);
          await FoodyDialogo.mostrar<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('El precio del pedido cambió'),
              content: Text(
                'No se creó ni se cobró el pedido. '
                '${anterior == null ? '' : 'El total cotizado era ${_moneda.format(anterior)} y ahora es '}'
                '${_moneda.format(actual)}. Revisa el nuevo valor y confirma otra vez para continuar.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
          return;
        }
      }
      final mostrado = await mostrarDialogoStockSiAplica(context, e);
      if (!mostrado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'crear pedido')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// «Pendiente» no mueve caja: ofrece CxC vinculada al pedido (auditoría caja).
  Future<void> _ofrecerRegistrarFiado({
    required String sucursalId,
    required Map<String, dynamic> pedido,
  }) async {
    final totalRaw = pedido['total'] ?? pedido['total_pedido'];
    final monto = totalRaw is num
        ? totalRaw.toDouble()
        : double.tryParse('$totalRaw') ?? 0;
    if (monto <= 0) return;

    final nombreCtrl = TextEditingController(text: 'Cliente mostrador');
    final telCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar fiado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pago pendiente · ${_moneda.format(monto)}. '
              '¿Crear cuenta por cobrar?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre cliente',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      return;
    }
    try {
      await _cajaRepo.crearCuentaPorCobrar(
        sucursalId: sucursalId,
        clienteNombre: nombreCtrl.text.trim().isEmpty
            ? 'Cliente mostrador'
            : nombreCtrl.text.trim(),
        monto: monto,
        clienteTelefono:
            telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
        pedidoId: pedido['id'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiado registrado en caja')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'registrar fiado')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      nombreCtrl.dispose();
      telCtrl.dispose();
    }
  }

  List<ProductoMenuModel> _productosFiltrados(MenuModel menu) {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    return menu.categorias
        .where((c) => _categoriaId == 'todo' || c.id == _categoriaId)
        .expand((c) => c.productos.map((p) => p.conCategoria(c.id)))
        .where((p) => p.disponible)
        .where((p) => q.isEmpty || p.nombre.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return ColoredBox(
        color: _scheme.surface,
        child: AnaliticaSkeleton.tab(),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: _scheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _cargar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _scheme.primary,
                    foregroundColor: _scheme.onPrimary,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final menu = _menu!;
    final ancho = FoodyBreakpoints.widthOf(context);
    final dosColumnas = FoodyBreakpoints.splitOperacion(ancho);
    final productos = _productosFiltrados(menu);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final titulo = widget.modoMesero
        ? 'Pedido · ${widget.mesaNombreFija ?? 'Mesa'}'
        : widget.itemIdReemplazar != null
            ? 'Cambiar producto'
            : widget.pedidoIdAgregar != null
                ? 'Agregar al pedido'
                : 'Nuevo pedido';

    return ColoredBox(
      color: _scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.ocultarCabecera)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compacto ? 12 : 16,
                8,
                compacto ? 12 : 16,
                4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin / Operación',
                    style: TextStyle(
                      fontSize: 11,
                      color: _scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: compacto ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: _scheme.onSurface,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${productos.length} disponibles · total lo calcula el servidor',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.modoMesero && _cajaAbierta != true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OperacionAviso(
                mensaje: _cajaAbierta == null
                    ? 'No pudimos verificar la caja. ${_errorConsultaCaja ?? ''}'
                    : 'No hay caja abierta. Abre turno en la pestaña Caja.',
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                colorTexto: const Color(0xFF92400E),
                accion: _cajaAbierta == null
                    ? 'Reintentar'
                    : widget.onIrCaja != null
                        ? 'Ir a Caja'
                        : null,
                onAccion: _cajaAbierta == null
                    ? () => _cargar(silencioso: true)
                    : widget.onIrCaja,
              ),
            ),
          if (widget.itemIdReemplazar != null && widget.pedidoIdAgregar != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OperacionAviso(
                mensaje: 'Elige el producto o combo de reemplazo y confirma. '
                    'Se agrega al pedido y se quita el ítem anterior.',
                color: AnaliticaTokens.pedidos.withValues(alpha: 0.1),
                colorTexto: AnaliticaTokens.pedidos,
              ),
            ),
          if (!menu.sucursal.horarioActivo && !_ocultarAvisoHorario)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OperacionAviso(
                mensaje:
                    'Sucursal fuera de horario. El servidor puede rechazar el pedido.',
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                colorTexto: const Color(0xFF92400E),
                accion: 'Ignorar',
                onAccion: () => setState(() => _ocultarAvisoHorario = true),
              ),
            ),
          Expanded(
            child: dosColumnas
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _panelMenu(menu, productos)),
                      SizedBox(
                        width: ancho >= 1200 ? 340 : 300,
                        child: _panelCarrito(),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final altoCarrito =
                          (constraints.maxHeight * 0.42).clamp(240.0, 380.0);
                      return Column(
                        children: [
                          Expanded(child: _panelMenu(menu, productos)),
                          SizedBox(height: altoCarrito, child: _panelCarrito()),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _panelMenu(MenuModel menu, List<ProductoMenuModel> productos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _campoBusqueda(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: FoodyScrollHorizontalFade(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chipCategoria('todo', 'Todo'),
                for (final c in menu.categorias) _chipCategoria(c.id, c.nombre),
              ],
            ),
          ),
        ),
        if (menu.combos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: FoodyScrollHorizontalFade(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: menu.combos.where((c) => c.disponible).map((combo) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(
                        '${combo.nombre} · ${_moneda.format(combo.precioFijo)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                      backgroundColor: _scheme.surfaceContainerLow,
                      side: BorderSide(color: _scheme.outlineVariant),
                      onPressed: () => _agregarCombo(combo),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            color: _scheme.onSurface,
            child: productos.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: _scheme.surfaceContainerLow,
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          border: Border.all(color: _scheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu_outlined,
                              size: 32,
                              color: _scheme.onSurfaceVariant,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Sin productos en esta categoría',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _scheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Cambia el filtro o publica ítems en Menú.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // La grilla ocupa solo el panel de menú (el carrito
                      // comparte el ancho en escritorio), así que decide
                      // columnas con sus restricciones reales, no la ventana.
                      final columnas = ((constraints.maxWidth - 32) / 178)
                          .floor()
                          .clamp(2, 5);
                      final anchoImagen =
                          ((constraints.maxWidth - 32 - ((columnas - 1) * 8)) /
                                  columnas *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round();
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnas,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: productos.length,
                        itemBuilder: (_, i) {
                          final p = productos[i];
                          final placeholder = Container(
                            height: 48,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: _scheme.onSurfaceVariant,
                              size: 22,
                            ),
                          );
                          return Material(
                            color: _scheme.surfaceContainerLow,
                            borderRadius:
                                BorderRadius.circular(AnaliticaTokens.r10),
                            child: InkWell(
                              onTap: () => _agregarProducto(p),
                              borderRadius:
                                  BorderRadius.circular(AnaliticaTokens.r10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      AnaliticaTokens.r10),
                                  border: Border.all(
                                    color: _scheme.outlineVariant,
                                    width: 0.5,
                                  ),
                                  boxShadow: AnaliticaTokens.shadowSoft,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: p.imagenUrl != null &&
                                              p.imagenUrl!.trim().isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: p.imagenUrl!,
                                              width: double.infinity,
                                              height: 48,
                                              memCacheWidth: anchoImagen,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) =>
                                                  placeholder,
                                              errorWidget: (_, __, ___) =>
                                                  placeholder,
                                            )
                                          : placeholder,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      p.nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _scheme.onSurface,
                                        height: 1.25,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _moneda.format(p.precio),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _campoBusqueda() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: _scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: 13,
                color: _scheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar plato, combo…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: _scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_busquedaCtrl.text.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16),
              color: _scheme.onSurfaceVariant,
              onPressed: () {
                _busquedaCtrl.clear();
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  Widget _chipCategoria(String id, String nombre) {
    final activa = _categoriaId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          nombre,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activa ? _scheme.onPrimary : _scheme.onSurfaceVariant,
          ),
        ),
        selected: activa,
        onSelected: (_) => setState(() => _categoriaId = id),
        selectedColor: _scheme.primary,
        backgroundColor: _scheme.surfaceContainerLow,
        side: BorderSide(
          color: activa ? _scheme.onSurface : _scheme.outlineVariant,
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _panelCarrito() {
    // Todo el carrito scrollea: evita BOTTOM OVERFLOW en móvil (alto fijo).
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Carrito',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${_carrito.length} ${_carrito.length == 1 ? 'producto' : 'productos'}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (!widget.modoMesero || widget.mesaIdFija != null) ...[
                  if (!widget.modoMesero || widget.pedidoIdAgregar == null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OperacionTipoToggle(
                        opciones: widget.modoMesero
                            ? const [
                                ('mesa', 'En mesa'),
                                ('para_llevar', 'Llevar'),
                                ('domicilio', 'Domi'),
                              ]
                            : const [
                                ('mesa', 'Mesa'),
                                ('domicilio', 'Domi'),
                                ('para_llevar', 'Llevar'),
                              ],
                        seleccionada: _tipoPedido,
                        onCambio: (v) {
                          setState(() {
                            _tipoPedido = v;
                            if (v != 'para_llevar') _pagoMixto = false;
                          });
                          _programarEstimacion();
                        },
                      ),
                    ),
                  ],
                  if (widget.modoMesero && widget.pedidoIdAgregar != null)
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Se suma al pedido de mesa abierto',
                        style: TextStyle(
                          fontSize: 11,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (!widget.modoMesero && _tipoPedido == 'mesa')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _mesaId,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Mesa',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _mesas
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text(
                          '${m['nombre']} ${m['pedido_id'] == null ? '(libre)' : '(ocupada)'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _mesaId = v);
                  _programarEstimacion();
                },
              ),
            ),
          if (!widget.modoMesero &&
              _tipoPedido == 'domicilio' &&
              widget.pedidoIdAgregar == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _clienteNombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre cliente *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _clienteTelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _direccionCtrl,
                    onChanged: (_) => _programarEstimacion(),
                    decoration: const InputDecoration(
                      labelText: 'Dirección de entrega *',
                      hintText: 'Calle, barrio, referencias',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sin mapa: ubicación solo cuando el cliente pide por la app',
                      style: TextStyle(
                        fontSize: 11,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.modoMesero && widget.pedidoIdAgregar == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_tipoPedido == 'para_llevar')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Pago mixto (CAJ-005)',
                        style: TextStyle(fontSize: 13),
                      ),
                      key: const ValueKey<String>('pos-pago-mixto'),
                      value: _pagoMixto,
                      onChanged: _estimandoTotal ||
                              _totalEstimadoServidor == null
                          ? null
                          : (v) => setState(() {
                                _pagoMixto = v;
                                if (v) {
                                  final total = _totalEstimadoServidor!;
                                  final primero = (total / 2).roundToDouble();
                                  _montoMixto1Ctrl.text =
                                      primero.toStringAsFixed(0);
                                  _montoMixto2Ctrl.text =
                                      (total - primero).toStringAsFixed(0);
                                }
                              }),
                    ),
                  if (_tipoPedido == 'para_llevar' &&
                      _carrito.isNotEmpty &&
                      !_estimandoTotal &&
                      _totalEstimadoServidor == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _errorEstimacion ??
                            'Foody debe calcular el total antes de dividir el pago.',
                        key: const ValueKey<String>('pos-error-estimacion'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _scheme.error,
                        ),
                      ),
                    ),
                  if (_pagoMixto && _tipoPedido == 'para_llevar') ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey<String>('pos-metodo-mixto-1'),
                      initialValue: _metodoPago,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago 1',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'efectivo',
                          child: Text('Efectivo'),
                        ),
                        DropdownMenuItem(
                          value: 'tarjeta',
                          child: Text('Tarjeta'),
                        ),
                      ],
                      onChanged: (v) => setState(
                        () => _metodoPago = v ?? _metodoPago,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey<String>('pos-monto-mixto-1'),
                      controller: _montoMixto1Ctrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Monto 1',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: const ValueKey<String>('pos-metodo-mixto-2'),
                      initialValue: _metodoPago2,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Método de pago 2',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'tarjeta',
                          child: Text('Tarjeta'),
                        ),
                        DropdownMenuItem(
                          value: 'efectivo',
                          child: Text('Efectivo'),
                        ),
                      ],
                      onChanged: (v) => setState(
                        () => _metodoPago2 = v ?? _metodoPago2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey<String>('pos-monto-mixto-2'),
                      controller: _montoMixto2Ctrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Monto 2',
                        isDense: true,
                      ),
                    ),
                  ],
                  if (_pagoMixto && _errorPagoMixto != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _errorPagoMixto!,
                        key: const ValueKey<String>('pos-error-pago-mixto'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _errorPagoMixto!.startsWith('Actualizando')
                              ? _scheme.onSurfaceVariant
                              : _scheme.error,
                        ),
                      ),
                    ),
                  if (!_pagoMixto || _tipoPedido != 'para_llevar')
                    DropdownButtonFormField<String>(
                      key: const ValueKey<String>('pos-metodo-pago'),
                      initialValue: _metodoPago,
                      isDense: true,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _etiquetaMetodoPago,
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'efectivo',
                          child: Text('Efectivo'),
                        ),
                        DropdownMenuItem(
                          value: 'tarjeta',
                          child: Text('Tarjeta'),
                        ),
                        DropdownMenuItem(
                          value: 'transferencia',
                          child: Text('Transferencia'),
                        ),
                        DropdownMenuItem(
                          value: 'nequi',
                          child: Text('Nequi'),
                        ),
                        DropdownMenuItem(
                          value: 'pendiente',
                          child: Text('Pendiente'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _metodoPago = v ?? _metodoPago),
                    ),
                  if (!_pagoMixto || _tipoPedido != 'para_llevar')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _ayudaMetodoPago,
                        key: const ValueKey<String>('pos-ayuda-pago'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_tipoPedido == 'para_llevar' &&
                      _metodoPago != 'pendiente') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _propinaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Propina voluntaria',
                        helperText: 'Aparte del total del pedido',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Divider(height: 1, color: _scheme.outlineVariant),
          if (_carrito.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 32,
                    color: _scheme.onSurfaceVariant,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Agrega productos',
                    style: TextStyle(
                      fontSize: 13,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_carrito.length, (i) {
              final l = _carrito[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.nombre,
                        style: TextStyle(
                          fontSize: 13,
                          color: _scheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _btnQty(
                      Icons.remove,
                      label: 'Reducir cantidad de ${l.nombre}',
                      key: ValueKey<String>('pos-qty-decrease-$i'),
                      onTap: () => _cambiarCantidad(i, -1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        key: ValueKey<String>('pos-qty-value-$i'),
                        '${l.cantidad}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _scheme.onSurface,
                        ),
                      ),
                    ),
                    _btnQty(
                      Icons.add,
                      label: 'Aumentar cantidad de ${l.nombre}',
                      key: ValueKey<String>('pos-qty-increase-$i'),
                      onTap: () => _cambiarCantidad(i, 1),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _moneda.format(l.subtotalPara(_tipoPedido)),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _notaCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Nota para cocina…',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: _scheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.notes,
                      size: 18,
                      color: _scheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: _scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: _scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _totalEstimadoServidor == null
                            ? 'Aproximado'
                            : 'Total estimado',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _scheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _estimandoTotal
                          ? 'Calculando…'
                          : _moneda
                              .format(_totalEstimadoServidor ?? _totalVisual),
                      key: const ValueKey<String>('pos-total-estimado'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.pedidoIdAgregar != null
                      ? 'El pedido existente conserva su total; aquí ves solo los productos que agregas.'
                      : _carrito.isEmpty
                          ? 'Agrega productos para cotizar el pedido.'
                          : _estimandoTotal
                              ? 'Calculando precio y promociones con Foody…'
                              : _totalEstimadoServidor != null
                                  ? 'Total calculado por Foody; se valida nuevamente al confirmar.'
                                  : _tipoPedido == 'domicilio' &&
                                          _direccionCtrl.text.trim().isEmpty
                                      ? 'Ingresa la dirección para incluir la tarifa de domicilio.'
                                      : 'No se pudo cotizar ahora. El total mostrado es aproximado.',
                  key: const ValueKey<String>('pos-ayuda-estimacion'),
                  style: TextStyle(
                    fontSize: 11,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
                if (_requiereCotizacionParaConfirmar &&
                    _carrito.isNotEmpty &&
                    !_estimandoTotal &&
                    _totalEstimadoServidor == null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _carrito.isEmpty
                          ? null
                          : () => _programarEstimacion(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar cotización'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _carrito.isEmpty ||
                          _enviando ||
                          _bloqueadoPorCotizacion ||
                          (_pagoMixto && _errorPagoMixto != null)
                      ? null
                      : _confirmarPedido,
                  style: FilledButton.styleFrom(
                    backgroundColor: _scheme.primary,
                    foregroundColor: _scheme.onPrimary,
                    disabledBackgroundColor: _scheme.outlineVariant,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmar pedido →'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnQty(
    IconData icon, {
    required String label,
    required Key key,
    required VoidCallback onTap,
  }) {
    return SizedBox.square(
      key: key,
      dimension: 44,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: _scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                  color: _scheme.surfaceContainerHighest,
                ),
                child: Icon(icon, size: 15, color: _scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
