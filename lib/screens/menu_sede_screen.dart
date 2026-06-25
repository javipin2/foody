import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reserva_canchas/config/supabase_env.dart';
import 'package:reserva_canchas/models/ciudad.dart';
import 'package:reserva_canchas/models/lugar.dart';
import 'package:reserva_canchas/models/menu_catalogo.dart';
import 'package:reserva_canchas/providers/menu_cart_provider.dart';
import 'package:reserva_canchas/providers/sede_provider.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:reserva_canchas/services/menu_catalog_service.dart';
import 'package:reserva_canchas/services/pedido_service.dart';

import 'lugar_screen.dart';
import 'sede_screen.dart';

const _headerBackground = Color(0xFF111624);
const _buttonBackground = Color(0xFF1A2033);
const _accentTeal = Color(0xFF2DD4BF);
const _fabOrange = Color(0xFFFF7A1A);
const _pageBg = Color(0xFFF3F4F6);

/// Menú de productos de la sede (reemplaza la lista de canchas para visitantes).
class MenuSedeScreen extends StatefulWidget {
  final Ciudad ciudad;
  final Lugar lugar;

  const MenuSedeScreen({
    super.key,
    required this.ciudad,
    required this.lugar,
  });

  @override
  State<MenuSedeScreen> createState() => _MenuSedeScreenState();
}

class _MenuSedeScreenState extends State<MenuSedeScreen> {
  static final _money = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  List<MenuCategoria> _categorias = [];
  List<MenuProducto> _productos = [];
  String? _selectedCategoriaId;
  String _busqueda = '';
  bool _cargando = true;
  String? _error;
  late final TextEditingController _searchCtrl;
  bool _creandoPedido = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuCartProvider>().clear();
      _cargarMenu();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMenu() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    final sedeProv = context.read<SedeProvider>();
    await sedeProv.fetchSedes();
    if (!mounted) return;

    final sedeId = sedeProv.selectedSedeFirestoreId;
    if (sedeId == null || sedeId.isEmpty) {
      setState(() {
        _cargando = false;
        _error = 'No se pudo identificar la sede. Vuelve atrás y elige de nuevo.';
      });
      return;
    }

    if (!isSupabaseConfigured || !AppBackend.supabaseReady) {
      setState(() {
        _cargando = false;
        _categorias = [];
        _productos = [];
      });
      return;
    }

    try {
      final svc = MenuCatalogService.instance;
      final cats = await svc.fetchCategorias(sedeId);
      final prods = await svc.fetchProductos(sedeId);
      if (!mounted) return;
      setState(() {
        _categorias = cats;
        _productos = prods;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar el menú. Revisa internet y la configuración de Supabase.\n($e)';
      });
    }
  }

  void _volver() {
    final sedeProvider = context.read<SedeProvider>();
    final cantSedes = sedeProvider.sedes.length;
    if (cantSedes <= 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (context) =>
              LugarScreen(ciudad: widget.ciudad, restartAmbientMusic: false),
        ),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            SedeScreen(ciudad: widget.ciudad, lugar: widget.lugar),
      ),
    );
  }

  Future<void> _abrirUbicacion(double lat, double lng) async {
    final urls = [
      Uri.parse('google.navigation:q=$lat,$lng'),
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    ];
    for (final url in urls) {
      if (await canLaunchUrl(url)) {
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa')),
      );
    }
  }

  List<MenuProducto> get _productosFiltrados {
    Iterable<MenuProducto> it = _productos;
    if (_selectedCategoriaId != null) {
      it = it.where((p) => p.categoriaId == _selectedCategoriaId);
    }
    final q = _busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((p) {
        final n = p.nombre.toLowerCase();
        final d = (p.descripcion ?? '').toLowerCase();
        return n.contains(q) || d.contains(q);
      });
    }
    return it.toList();
  }

  void _abrirCarrito() {
    final cart = context.read<MenuCartProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<MenuCartProvider>(
              builder: (context, c, _) {
                if (c.lines.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Tu pedido está vacío',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca + en un producto para agregarlo.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            'Tu pedido',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              cart.clear();
                              Navigator.pop(context);
                            },
                            child: const Text('Vaciar'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ...cart.lines.values.map((line) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: line.imagenUrl != null &&
                                        line.imagenUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: Image.network(
                                          line.imagenUrl!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.fastfood),
                                        ),
                                      )
                                    : const Icon(Icons.fastfood),
                                title: Text(line.nombre),
                                subtitle: Text(
                                  '${_money.format(line.precioUnit)} × ${line.cantidad}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () {
                                        cart.setQuantity(
                                          line.productoId,
                                          line.cantidad - 1,
                                        );
                                        if (cart.lines.isEmpty) {
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                    Text('${line.cantidad}'),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        cart.setQuantity(
                                          line.productoId,
                                          line.cantidad + 1,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          ListTile(
                            title: const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: Text(
                              _money.format(cart.totalPrice),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: FilledButton(
                              onPressed: _creandoPedido
                                  ? null
                                  : () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final cartProvider =
                                          context.read<MenuCartProvider>();
                                      final sedeId = context
                                          .read<SedeProvider>()
                                          .selectedSedeId;
                                      if (sedeId == null || sedeId.isEmpty) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'No se pudo identificar la sede del pedido.'),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() => _creandoPedido = true);
                                      try {
                                        final pedidoId = await PedidoService
                                            .instance
                                            .crearPedido(
                                          lugarId: widget.lugar.id,
                                          sedeId: sedeId,
                                          items: c.lines.values,
                                        );
                                        cartProvider.clear();
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Pedido creado: ${pedidoId.substring(0, 8)}...',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'No se pudo crear el pedido: $e'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(
                                              () => _creandoPedido = false);
                                        }
                                      }
                                    },
                              child: _creandoPedido
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Confirmar pedido'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sedeProvider = context.watch<SedeProvider>();
    final selectedSede = sedeProvider.selectedSede;
    final sede = sedeProvider.sedes.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s != null && s['nombre'] == selectedSede,
          orElse: () => null,
        );
    final latitud = sede?['latitud'] as double?;
    final longitud = sede?['longitud'] as double?;
    final tieneUbicacion = latitud != null && longitud != null;

    return WillPopScope(
      onWillPop: () async {
        _volver();
        return false;
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        floatingActionButton: Consumer<MenuCartProvider>(
          builder: (context, cart, _) {
            return FloatingActionButton(
              backgroundColor: _fabOrange,
              onPressed: _abrirCarrito,
              child: Badge(
                isLabelVisible: cart.totalItems > 0,
                label: Text('${cart.totalItems}'),
                child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              ),
            );
          },
        ),
        body: Stack(
          children: [
            Container(color: _headerBackground),
            Column(
              children: [
                _buildHeader(
                  context,
                  selectedSede,
                  tieneUbicacion,
                  latitud,
                  longitud,
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    child: ColoredBox(
                      color: _pageBg,
                      child: _buildCuerpo(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String selectedSede,
    bool tieneUbicacion,
    double? latitud,
    double? longitud,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _buttonBackground,
                  foregroundColor: Colors.white,
                ),
                onPressed: _volver,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  widget.lugar.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _buttonBackground,
                  foregroundColor:
                      tieneUbicacion ? _accentTeal : Colors.white70,
                ),
                onPressed: tieneUbicacion && latitud != null && longitud != null
                    ? () => _abrirUbicacion(latitud, longitud)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ubicación de la sede no disponible'),
                          ),
                        );
                      },
                icon: const Icon(Icons.location_on_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.storefront_rounded,
                  color: _accentTeal, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedSede.isNotEmpty ? selectedSede.toUpperCase() : 'SEDE',
                  style: const TextStyle(
                    color: _accentTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (!isSupabaseConfigured || !AppBackend.supabaseReady) {
      return _panelConfigSupabase();
    }
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _cargarMenu,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarMenu,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Categorías',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Pedido',
                    onPressed: _abrirCarrito,
                    icon: const Icon(Icons.receipt_long_outlined),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildChips()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          if (_productosFiltrados.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      _productos.isEmpty
                          ? 'Aun no hay platos en el menu de esta sede.\nEn Supabase inserta filas en menu_categorias y menu_productos usando sede_id de la tabla sedes.'
                          : 'Nada coincide con el filtro o la búsqueda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = _productosFiltrados[index];
                    return _ProductoCard(
                      producto: p,
                      money: _money,
                      onAdd: () {
                        HapticFeedback.lightImpact();
                        context.read<MenuCartProvider>().addProduct(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${p.nombre} agregado'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _productosFiltrados.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelConfigSupabase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.settings_ethernet, size: 48),
          const SizedBox(height: 16),
          Text(
            'Conectar Supabase',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            '1. Crea un proyecto en supabase.com.\n'
            '2. Ve a Project Settings → API y copia la URL del proyecto y la clave anon public.\n'
            '3. Pégalos en el archivo lib/config/supabase_env.dart (kSupabaseUrl y kSupabaseAnonKey).\n'
            '4. En SQL Editor, ejecuta supabase/sql/000_schema_completo.sql.\n'
            '5. Ejecuta supabase/sql/010_seed_demo.sql para cargar datos base y demo.\n'
            '6. Inserta o ajusta categorias/productos reales con sede_id de la tabla sedes.\n'
            '7. Vuelve a abrir la app.',
          ),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: const Text('Todas'),
              selected: _selectedCategoriaId == null,
              onSelected: (_) =>
                  setState(() => _selectedCategoriaId = null),
              selectedColor: Colors.black87,
              labelStyle: TextStyle(
                color: _selectedCategoriaId == null
                    ? Colors.white
                    : Colors.black87,
              ),
              checkmarkColor: Colors.white,
            ),
          ),
          ..._categorias.map((c) {
            final sel = _selectedCategoriaId == c.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(c.nombre),
                selected: sel,
                onSelected: (_) => setState(() {
                  _selectedCategoriaId = sel ? null : c.id;
                }),
                selectedColor: Colors.black87,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : Colors.black87,
                ),
                checkmarkColor: Colors.white,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  final MenuProducto producto;
  final NumberFormat money;
  final VoidCallback onAdd;

  const _ProductoCard({
    required this.producto,
    required this.money,
    required this.onAdd,
  });

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: producto.imagenUrl != null &&
                      producto.imagenUrl!.isNotEmpty
                  ? Image.network(
                      producto.imagenUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((producto.descripcion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      producto.descripcion!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    money.format(producto.precio),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: const Color(0xFFE0F2FE),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAdd,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.add, color: Color(0xFF0284C7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade200,
      child: Icon(Icons.fastfood, color: Colors.grey.shade500),
    );
  }
}
