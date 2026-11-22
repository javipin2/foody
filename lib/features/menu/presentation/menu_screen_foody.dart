import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/core/tema/foody_formato.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/mesa/data/mesa_repository.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_producto_sheet.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_combo_sheet.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/features/pedidos/providers/carrito_provider.dart';
import 'package:reserva_canchas/features/promociones/presentation/promociones_stories_bar.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menú Foody — UI del legacy (chips, búsqueda, cards) con datos NestJS.
class MenuScreenFoody extends ConsumerStatefulWidget {
  const MenuScreenFoody({
    super.key,
    required this.sucursalId,
    required this.sucursalNombre,
    this.mesaId,
    this.mesaNombre,
    this.productoIdDestino,
  });

  final String sucursalId;
  final String sucursalNombre;
  final String? mesaId;
  final String? mesaNombre;
  /// Deep-link desde story con producto vinculado.
  final String? productoIdDestino;

  @override
  ConsumerState<MenuScreenFoody> createState() => _MenuScreenFoodyState();
}

class _MenuScreenFoodyState extends ConsumerState<MenuScreenFoody> {
  final _repositorio = MenuRepository();
  final _mesaRepo = MesaRepository();
  final _busquedaCtrl = TextEditingController();
  late Future<MenuModel> _futureMenu;
  String? _categoriaId;
  String _busqueda = '';
  RealtimeChannel? _canalCatalogo;
  PollRealtimeRespaldo? _pollRespaldo;
  int _pedidosActivosMesa = 0;
  double _totalPendienteMesa = 0;
  bool _abroProductoDestino = false;

  static final _formatoMoneda = FoodyFormato.moneda;

  @override
  void initState() {
    super.initState();
    _futureMenu = _repositorio.obtenerPorSucursal(widget.sucursalId);
    if (AppBackend.supabaseReady) {
      _canalCatalogo = FoodyRealtime.suscribirCatalogo(
        widget.sucursalId,
        onCatalogoActualizado: _reintentar,
        onReconectado: _reintentar,
      );
    }
    // RT-FALL-01: poll si cae catalogo_disponibilidad.
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) _reintentar();
    });
    unawaited(_pollRespaldo!.iniciar());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(carritoProvider.notifier).configurarSucursal(widget.sucursalId);
      if (widget.mesaId != null && widget.mesaNombre != null) {
        MesaSesionService.activar(
          mesaId: widget.mesaId!,
          mesaNombre: widget.mesaNombre!,
          sucursalId: widget.sucursalId,
          sucursalNombre: widget.sucursalNombre,
        );
        unawaited(_refrescarPedidosActivosMesa());
      }
    });
  }

  Future<void> _refrescarPedidosActivosMesa() async {
    if (widget.mesaId == null) return;
    final sesion = await MesaSesionService.obtener();
    final token = sesion?.qrToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _pedidosActivosMesa = sesion?.pedidosActivos ?? 0);
      return;
    }
    try {
      final r = await _mesaRepo.resumenPedidosMesaQr(token);
      await MesaSesionService.actualizarPedidosActivos(r.activos);
      if (mounted) {
        setState(() {
          _pedidosActivosMesa = r.activos;
          _totalPendienteMesa = r.totalPendiente;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pedidosActivosMesa = sesion?.pedidosActivos ?? 0);
      }
    }
  }

  void _reintentar() {
    setState(() {
      _futureMenu = _repositorio.obtenerPorSucursal(widget.sucursalId);
    });
  }

  Future<void> _salirDeMesa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Terminaste en esta mesa?'),
        content: const Text(
          'Cierras la sesión de mesa. Para pedir de nuevo, escanea el QR de la mesa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir pidiendo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminé'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await MesaSesionService.limpiar();
    ref.read(carritoProvider.notifier).limpiar();
    if (!mounted) return;
    final ruta = await CiudadPreferenceService.rutaHomeCliente();
    if (mounted) context.go(ruta);
  }

  @override
  void dispose() {
    _pollRespaldo?.detener();
    FoodyRealtime.liberarCanal(_canalCatalogo);
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<ProductoMenuModel> _productosFiltrados(MenuModel menu) {
    var lista = [
      for (final c in menu.categorias)
        for (final p in c.productos)
          if (!p.esEncargo) p.conCategoria(c.id),
    ];

    if (_categoriaId != null) {
      lista = lista.where((p) => p.categoriaId == _categoriaId).toList();
    }
    final q = _busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista
          .where(
            (p) =>
                p.nombre.toLowerCase().contains(q) ||
                (p.descripcion ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return lista;
  }

  List<ProductoMenuModel> _encargos(MenuModel menu) {
    return [
      for (final c in menu.categorias)
        for (final p in c.productos)
          if (p.esEncargo) p.conCategoria(c.id),
    ];
  }

  void _agregarProducto(ProductoMenuModel producto, MenuModel menu) {
    if (!producto.disponible) return;
    DetalleProductoSheet.mostrar(
      context,
      producto: producto,
      sugerenciasBebidas: menu.productoEsDeCategoriaBebidas(producto)
          ? const []
          : menu.productosBebidasVendibles(excluirId: producto.id),
      onAgregar: (lineas) {
        for (final linea in lineas) {
          _confirmarAgregado(linea);
        }
      },
    );
  }

  void _agregarCombo(ComboMenuModel combo, MenuModel menu) {
    if (!combo.disponible) return;
    final tops = <OpcionMenuModel>[];
    final seenT = <String>{};
    for (final ci in combo.items) {
      if (ci.tipoItem != 'producto' || ci.itemId == null) continue;
      for (final p in menu.todosLosProductos) {
        if (p.id != ci.itemId) continue;
        for (final t in p.toppings) {
          if (seenT.add(t.id)) tops.add(t);
        }
      }
    }
    DetalleComboSheet.mostrar(
      context,
      combo: combo,
      toppingsDisponibles: tops,
      sugerenciasBebidas: menu.productosBebidasVendibles(),
      onAgregar: (lineas) {
        for (final linea in lineas) {
          _confirmarAgregado(linea);
        }
      },
    );
  }

  void _irACarrito() {
    var q = 'sucursalNombre=${Uri.encodeComponent(widget.sucursalNombre)}';
    if (widget.mesaId != null) {
      q += '&mesa_id=${widget.mesaId}';
      if (widget.mesaNombre != null) {
        q += '&mesa_nombre=${Uri.encodeComponent(widget.mesaNombre!)}';
      }
    }
    context.push('/carrito/${widget.sucursalId}?$q');
  }

  void _confirmarAgregado(LineaCarrito linea) {
    HapticFeedback.lightImpact();
    ref.read(carritoProvider.notifier).agregarLinea(linea);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${linea.nombre} en el carrito'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AnaliticaTokens.ink,
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: _irACarrito,
        ),
      ),
    );
  }

  void _abrirProductoDestinoSiAplica(MenuModel menu) {
    final pid = widget.productoIdDestino;
    if (pid == null || pid.isEmpty || _abroProductoDestino) return;
    _abroProductoDestino = true;
    ProductoMenuModel? producto;
    for (final p in menu.todosLosProductos) {
      if (p.id == pid) {
        producto = p;
        break;
      }
    }
    if (producto == null || !producto.disponible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _agregarProducto(producto!, menu);
    });
  }

  @override
  Widget build(BuildContext context) {
    // FL-WIDGET-02: no watch del carrito aquí — solo la barra inferior (Consumer).
    return PopScope(
      canPop: widget.mesaId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.mesaId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Estás en una mesa. Usa «Salir de mesa» si quieres cambiar de restaurante.',
              ),
            ),
          );
        }
      },
      child: Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      floatingActionButton: null,
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final resumen = ref.watch(
            carritoProvider.select((c) => (c.totalItems, c.totalPrecio)),
          );
          if (resumen.$1 <= 0) return const SizedBox.shrink();
          return Material(
              elevation: 0,
              color: AnaliticaTokens.surface,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AnaliticaTokens.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r12),
                      ),
                    ),
                    onPressed: _irACarrito,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ver carrito · ${resumen.$1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          FoodyFormato.monedaDe(resumen.$2),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
        },
      ),
      body: FutureBuilder<MenuModel>(
        future: _futureMenu,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return FoodyEstadoUi.cargando(mensaje: 'Cargando menú…');
          }
          if (snapshot.hasError) {
            return FoodyEstadoUi.error(
              mensaje: mensajeErrorCliente(
                snapshot.error!,
                contexto: 'cargar el menú',
              ),
              onReintentar: _reintentar,
            );
          }

          final menu = snapshot.data!;
          _abrirProductoDestinoSiAplica(menu);
          if (!menu.sucursal.horarioActivo) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.sucursalNombre} está cerrado en este momento.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ),
            );
          }

          final productos = _productosFiltrados(menu);
          final encargos = _encargos(menu);

          return RefreshIndicator(
            onRefresh: () async {
              _reintentar();
              await _futureMenu;
              await _refrescarPedidosActivosMesa();
            },
            child: CustomScrollView(
              slivers: [
                if (widget.mesaNombre != null)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AnaliticaTokens.surface,
                            borderRadius:
                                BorderRadius.circular(AnaliticaTokens.r12),
                            border: Border.all(color: AnaliticaTokens.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.table_restaurant_rounded,
                                color: AnaliticaTokens.ink
                                    .withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mesa ${widget.mesaNombre} · ${widget.sucursalNombre}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AnaliticaTokens.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_pedidosActivosMesa > 0)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AnaliticaTokens.surfaceMuted,
                              borderRadius:
                                  BorderRadius.circular(AnaliticaTokens.r12),
                              border: Border.all(color: AnaliticaTokens.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AnaliticaTokens.ink,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _pedidosActivosMesa == 1
                                        ? 'Cuenta de mesa activa · ${_formatoMoneda.format(_totalPendienteMesa)} pendiente. '
                                            'Puedes seguir pidiendo; todo se suma a la misma cuenta.'
                                        : 'Cuenta unificada: $_pedidosActivosMesa pedidos · '
                                            '${_formatoMoneda.format(_totalPendienteMesa)} pendiente. '
                                            'Los nuevos ítems se agregan a esta mesa.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AnaliticaTokens.inkMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AnaliticaTokens.surface,
                  foregroundColor: AnaliticaTokens.ink,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  centerTitle: false,
                  titleSpacing: 0,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Menú',
                        style: TextStyle(
                          color: AnaliticaTokens.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        widget.sucursalNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AnaliticaTokens.ink,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                  actions: widget.mesaId != null
                      ? [
                          TextButton.icon(
                            onPressed: _salirDeMesa,
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Terminé'),
                            style: TextButton.styleFrom(
                              foregroundColor: AnaliticaTokens.ink,
                            ),
                          ),
                        ]
                      : null,
                ),
                SliverToBoxAdapter(
                  child: PromocionesStoriesBar(
                    sucursalId: widget.sucursalId,
                    sucursalNombre: widget.sucursalNombre,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _busquedaCtrl,
                      onChanged: (v) => setState(() => _busqueda = v),
                      style: const TextStyle(
                        color: AnaliticaTokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar plato o bebida…',
                        hintStyle: const TextStyle(
                          color: AnaliticaTokens.inkSoft,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AnaliticaTokens.inkMuted,
                        ),
                        filled: true,
                        fillColor: AnaliticaTokens.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          borderSide:
                              const BorderSide(color: AnaliticaTokens.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          borderSide:
                              const BorderSide(color: AnaliticaTokens.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          borderSide: const BorderSide(
                            color: AnaliticaTokens.ink,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final vacio = ref.watch(
                      carritoProvider.select((c) => c.totalItems == 0),
                    );
                    if (!vacio) {
                      return const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      );
                    }
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(
                          'Toca + para armar tu pedido. Puedes agregar extras al plato.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AnaliticaTokens.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: FoodyScrollHorizontalFade(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _chipCategoria('Todas', _categoriaId == null, () {
                            setState(() => _categoriaId = null);
                          }),
                          for (final c in menu.categorias)
                            _chipCategoria(
                              c.nombre,
                              _categoriaId == c.id,
                              () => setState(() {
                                _categoriaId =
                                    _categoriaId == c.id ? null : c.id;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (encargos.isNotEmpty &&
                    _categoriaId == null &&
                    _busqueda.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Encargos',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AnaliticaTokens.ink,
                                ),
                          ),
                          const Text(
                            'Requieren confirmación del restaurante',
                            style: TextStyle(
                              fontSize: 12,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...encargos.map(
                            (p) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: AnaliticaTokens.surfaceMuted,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AnaliticaTokens.r12),
                                side: const BorderSide(
                                  color: AnaliticaTokens.border,
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  p.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AnaliticaTokens.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  p.disponible
                                      ? (p.descripcion ?? '')
                                      : 'Agotado',
                                  style: const TextStyle(
                                    color: AnaliticaTokens.inkMuted,
                                  ),
                                ),
                                trailing: p.disponible
                                    ? IconButton(
                                        icon: const Icon(Icons.add_circle),
                                        color: AnaliticaTokens.ink,
                                        onPressed: () =>
                                            _agregarProducto(p, menu),
                                      )
                                    : Chip(
                                        label: const Text('Agotado'),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor:
                                            AnaliticaTokens.surfaceMuted,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (menu.combos.isNotEmpty &&
                    _categoriaId == null &&
                    _busqueda.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Combos',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AnaliticaTokens.ink,
                                ),
                          ),
                          const SizedBox(height: 8),
                          ...menu.combos.map(
                            (combo) => Opacity(
                              opacity: combo.disponible ? 1 : 0.55,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                color: AnaliticaTokens.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AnaliticaTokens.r12,
                                  ),
                                  side: const BorderSide(
                                    color: AnaliticaTokens.border,
                                  ),
                                ),
                                child: ListTile(
                                  leading: combo.imagenUrl != null &&
                                          combo.imagenUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: combo.imagenUrl!,
                                            width: 56,
                                            height: 56,
                                            memCacheWidth:
                                                (56 * MediaQuery.devicePixelRatioOf(context))
                                                    .round(),
                                            memCacheHeight:
                                                (56 * MediaQuery.devicePixelRatioOf(context))
                                                    .round(),
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const Icon(
                                              Icons.fastfood_rounded,
                                              color: AnaliticaTokens.inkMuted,
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                              Icons.fastfood_rounded,
                                              color: AnaliticaTokens.inkMuted,
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(
                                          backgroundColor:
                                              AnaliticaTokens.surfaceMuted,
                                          child: Icon(
                                            Icons.layers_rounded,
                                            color: AnaliticaTokens.ink
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                  title: Text(
                                    combo.nombre,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AnaliticaTokens.ink,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (!combo.disponible) 'Agotado',
                                      _formatoMoneda.format(combo.precioFijo),
                                      if (combo.resumenItems.isNotEmpty)
                                        combo.resumenItems
                                      else if ((combo.descripcion ?? '')
                                          .isNotEmpty)
                                        combo.descripcion!,
                                    ].join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AnaliticaTokens.inkMuted,
                                    ),
                                  ),
                                  trailing: combo.disponible
                                      ? _BotonAgregarRapido(
                                          onTap: () =>
                                              _agregarCombo(combo, menu),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (productos.isEmpty && menu.combos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: FoodyEstadoUi.vacio(
                      titulo: _tituloVacioCategoria(menu),
                      subtitulo: _subtituloVacioCategoria(menu),
                      icono: Icons.search_off_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final p = productos[index];
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(
                              milliseconds: 220 + (index.clamp(0, 8) * 28),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, child) {
                              return Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - t)),
                                  child: child,
                                ),
                              );
                            },
                            child: _TarjetaProducto(
                              producto: p,
                              formato: _formatoMoneda,
                              onAgregar: () => _agregarProducto(p, menu),
                            ),
                          );
                        },
                        childCount: productos.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }

  String _tituloVacioCategoria(MenuModel menu) {
    final cat = _categoriaSeleccionada(menu);
    if (cat != null && _esCategoriaBebidas(cat.nombre)) {
      return 'No hay bebidas publicadas como producto';
    }
    return 'No hay platos con ese filtro';
  }

  String _subtituloVacioCategoria(MenuModel menu) {
    final cat = _categoriaSeleccionada(menu);
    if (cat != null && _esCategoriaBebidas(cat.nombre)) {
      return 'El restaurante debe crear jugos o gaseosas como producto '
          'en esta categoría (no solo como extra del plato)';
    }
    return 'Prueba otra categoría o búsqueda';
  }

  CategoriaMenuModel? _categoriaSeleccionada(MenuModel menu) {
    final id = _categoriaId;
    if (id == null) return null;
    for (final c in menu.categorias) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool _esCategoriaBebidas(String nombre) {
    final n = nombre.trim().toLowerCase();
    return n.contains('bebida') || n.contains('jugo') || n.contains('bebidas');
  }

  Widget _chipCategoria(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
        showCheckmark: false,
        selectedColor: AnaliticaTokens.ink,
        backgroundColor: AnaliticaTokens.surface,
        side: BorderSide(
          color: selected ? AnaliticaTokens.ink : AnaliticaTokens.border,
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AnaliticaTokens.ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Botón + con micro-rebote al tocar (feedback táctil de pedido).
class _BotonAgregarRapido extends StatefulWidget {
  const _BotonAgregarRapido({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BotonAgregarRapido> createState() => _BotonAgregarRapidoState();
}

class _BotonAgregarRapidoState extends State<_BotonAgregarRapido> {
  double _scale = 1;

  Future<void> _tap() async {
    HapticFeedback.selectionClick();
    setState(() => _scale = 0.86);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (mounted) setState(() => _scale = 1);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: AnaliticaTokens.ink,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _tap,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.formato,
    required this.onAgregar,
  });

  final ProductoMenuModel producto;
  final NumberFormat formato;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    final disponible = producto.disponible;
    return Opacity(
      opacity: disponible ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
        color: AnaliticaTokens.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disponible ? onAgregar : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
              border: Border.all(color: AnaliticaTokens.border),
              boxShadow: AnaliticaTokens.shadowSoft,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _imagen(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                producto.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AnaliticaTokens.ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (!disponible)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AnaliticaTokens.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Agotado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AnaliticaTokens.inkMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if ((producto.descripcion ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            producto.descripcion!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                        ],
                        if (producto.tienePersonalizacion) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Personalizable · extras',
                            style: TextStyle(
                              fontSize: 11,
                              color: AnaliticaTokens.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          formato.format(producto.precio),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AnaliticaTokens.ink,
                            fontSize: 14,
                          ),
                        ),
                        if (producto.tienePrecioLlevarDistinto)
                          Text(
                            'Llevar ${formato.format(producto.precioParaLlevar!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (disponible) ...[
                    const SizedBox(width: 8),
                    _BotonAgregarRapido(onTap: onAgregar),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
            ),
    );
  }

  Widget _imagen(BuildContext context) {
    final url = producto.imagenUrl;
    if (url != null && url.isNotEmpty) {
      final cache = (72 * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 72,
          height: 72,
          memCacheWidth: cache,
          memCacheHeight: cache,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AnaliticaTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      ),
      child: const Icon(
        Icons.restaurant_rounded,
        color: AnaliticaTokens.inkSoft,
      ),
    );
  }
}
