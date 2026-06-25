import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/menu/domain/menu_model.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_producto_sheet.dart';
import 'package:reserva_canchas/features/menu/presentation/widgets/detalle_combo_sheet.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/features/pedidos/providers/carrito_provider.dart';
import 'package:reserva_canchas/features/promociones/presentation/promociones_stories_bar.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';
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
  });

  final String sucursalId;
  final String sucursalNombre;
  final String? mesaId;
  final String? mesaNombre;

  @override
  ConsumerState<MenuScreenFoody> createState() => _MenuScreenFoodyState();
}

class _MenuScreenFoodyState extends ConsumerState<MenuScreenFoody> {
  final _repositorio = MenuRepository();
  final _busquedaCtrl = TextEditingController();
  late Future<MenuModel> _futureMenu;
  String? _categoriaId;
  String _busqueda = '';
  RealtimeChannel? _canalCatalogo;

  final _formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _futureMenu = _repositorio.obtenerPorSucursal(widget.sucursalId);
    if (AppBackend.supabaseReady) {
      _canalCatalogo = FoodyRealtime.suscribirCatalogo(
        widget.sucursalId,
        onCatalogoActualizado: _reintentar,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(carritoProvider.notifier).configurarSucursal(widget.sucursalId);
      if (widget.mesaId != null && widget.mesaNombre != null) {
        MesaSesionService.activar(
          mesaId: widget.mesaId!,
          mesaNombre: widget.mesaNombre!,
          sucursalId: widget.sucursalId,
          sucursalNombre: widget.sucursalNombre,
        );
      }
    });
  }

  Future<void> _salirDeMesa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de la mesa?'),
        content: const Text(
          'Podrás elegir otra ciudad o restaurante. '
          'Si tienes un pedido pendiente, sigue en cocina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await MesaSesionService.limpiar();
    ref.read(carritoProvider.notifier).limpiar();
    if (!mounted) return;
    context.go('/cliente');
  }

  @override
  void dispose() {
    _canalCatalogo?.unsubscribe();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _reintentar() {
    setState(() {
      _futureMenu = _repositorio.obtenerPorSucursal(widget.sucursalId);
    });
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

  void _agregarProducto(ProductoMenuModel producto) {
    if (!producto.disponible) return;
    DetalleProductoSheet.mostrar(
      context,
      producto: producto,
      onAgregar: (linea) => _confirmarAgregado(linea),
    );
  }

  void _agregarCombo(ComboMenuModel combo) {
    if (!combo.disponible) return;
    DetalleComboSheet.mostrar(
      context,
      combo: combo,
      onAgregar: (linea) => _confirmarAgregado(linea),
    );
  }

  void _confirmarAgregado(LineaCarrito linea) {
    HapticFeedback.lightImpact();
    ref.read(carritoProvider.notifier).agregarLinea(linea);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${linea.nombre} agregado'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoProvider);

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
      backgroundColor: const Color(0xFFF3F4F6),
      floatingActionButton: carrito.totalItems > 0
          ? FloatingActionButton.extended(
              backgroundColor: ColoresFoody.primario,
              onPressed: () {
                var q =
                    'sucursalNombre=${Uri.encodeComponent(widget.sucursalNombre)}';
                if (widget.mesaId != null) {
                  q += '&mesa_id=${widget.mesaId}';
                  if (widget.mesaNombre != null) {
                    q += '&mesa_nombre=${Uri.encodeComponent(widget.mesaNombre!)}';
                  }
                }
                context.push('/carrito/${widget.sucursalId}?$q');
              },
              label: Text('Carrito (${carrito.totalItems})'),
              icon: const Icon(Icons.shopping_bag_outlined),
            )
          : null,
      body: FutureBuilder<MenuModel>(
        future: _futureMenu,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reintentar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final menu = snapshot.data!;
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
            },
            child: CustomScrollView(
              slivers: [
                if (widget.mesaNombre != null)
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColoresFoody.secundario.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.table_restaurant,
                              color: ColoresFoody.secundario),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mesa ${widget.mesaNombre} · ${widget.sucursalNombre}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: _salirDeMesa,
                            child: const Text('Salir'),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 120,
                  backgroundColor: const Color(0xFF111624),
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.sucursalNombre,
                      style: const TextStyle(fontSize: 16),
                    ),
                    background: Container(
                      color: const Color(0xFF111624),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                      child: Text(
                        'Menú',
                        style: TextStyle(
                          color: ColoresFoody.secundario.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: PromocionesStoriesBar(sucursalId: widget.sucursalId),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _busquedaCtrl,
                      onChanged: (v) => setState(() => _busqueda = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar plato',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Requieren confirmación del restaurante',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...encargos.map(
                            (p) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: ColoresFoody.acento.withValues(alpha: 0.2),
                              child: ListTile(
                                title: Text(p.nombre),
                                subtitle: Text(p.descripcion ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  color: ColoresFoody.primario,
                                  onPressed: () => _agregarProducto(p),
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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...menu.combos.map(
                            (combo) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(combo.nombre),
                                subtitle: Text(
                                  combo.resumenItems.isEmpty
                                      ? combo.descripcion ?? ''
                                      : combo.resumenItems,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatoMoneda.format(combo.precioFijo),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ColoresFoody.primario,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      color: ColoresFoody.primario,
                                      onPressed: () => _agregarCombo(combo),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (productos.isEmpty && menu.combos.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No hay productos con ese filtro')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final p = productos[index];
                          return _TarjetaProducto(
                            producto: p,
                            formato: _formatoMoneda,
                            onAgregar: () => _agregarProducto(p),
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

  Widget _chipCategoria(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: ColoresFoody.primario,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
        ),
        checkmarkColor: Colors.white,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _imagen(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if ((producto.descripcion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      producto.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (producto.tienePersonalizacion) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Personalizable',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColoresFoody.secundario.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formato.format(producto.precio),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColoresFoody.primario,
                    ),
                  ),
                  if (producto.tienePrecioLlevarDistinto)
                    Text(
                      'Llevar ${formato.format(producto.precioParaLlevar!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Material(
              color: ColoresFoody.primario.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAgregar,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.add, color: ColoresFoody.primario),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagen() {
    final url = producto.imagenUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
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
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.fastfood, color: Colors.grey.shade500),
    );
  }
}
