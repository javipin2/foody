import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/promociones/presentation/promociones_ciudad_stories_bar.dart';
import 'package:reserva_canchas/features/restaurantes/data/restaurantes_repository.dart';
import 'package:reserva_canchas/features/restaurantes/domain/restaurante_model.dart';

class RestaurantesScreenFoody extends StatefulWidget {
  const RestaurantesScreenFoody({
    super.key,
    required this.ciudadSlug,
    required this.ciudadNombre,
  });

  final String ciudadSlug;
  final String ciudadNombre;

  @override
  State<RestaurantesScreenFoody> createState() =>
      _RestaurantesScreenFoodyState();
}

class _RestaurantesScreenFoodyState extends State<RestaurantesScreenFoody> {
  final _repositorio = RestaurantesRepository();
  final _busquedaController = TextEditingController();
  late Future<List<RestauranteModel>> _futureRestaurantes;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _futureRestaurantes = _repositorio.listarPorCiudad(widget.ciudadSlug);
    _busquedaController.addListener(() {
      setState(() => _filtro = _busquedaController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _reintentar() {
    setState(() {
      _futureRestaurantes = _repositorio.listarPorCiudad(widget.ciudadSlug);
    });
  }

  List<RestauranteModel> _filtrar(List<RestauranteModel> lista) {
    if (_filtro.isEmpty) return lista;
    return lista.where((r) {
      final nombre = r.nombre.toLowerCase();
      final desc = (r.descripcion ?? '').toLowerCase();
      return nombre.contains(_filtro) || desc.contains(_filtro);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresFoody.fondo,
      appBar: AppBar(
        title: Text(widget.ciudadNombre),
        backgroundColor: ColoresFoody.fondo,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: ColoresFoody.primario,
        onRefresh: () async {
          setState(() {
            _futureRestaurantes =
                _repositorio.listarPorCiudad(widget.ciudadSlug);
          });
          await _futureRestaurantes;
        },
        child: FutureBuilder<List<RestauranteModel>>(
          future: _futureRestaurantes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _ErrorEstado(
                    mensaje: 'No pudimos cargar los restaurantes',
                    detalle: '${snapshot.error}',
                    onReintentar: _reintentar,
                  ),
                ],
              );
            }

            final todos = snapshot.data ?? [];
            final restaurantes = _filtrar(todos);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: PromocionesCiudadStoriesBar(
                    ciudadSlug: widget.ciudadSlug,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SearchBar(
                      controller: _busquedaController,
                      hintText: 'Buscar restaurante…',
                      leading: const Icon(Icons.search),
                      trailing: _filtro.isNotEmpty
                          ? [
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _busquedaController.clear(),
                              ),
                            ]
                          : null,
                      backgroundColor: WidgetStateProperty.all(
                        ColoresFoody.tarjeta,
                      ),
                    ),
                  ),
                ),
                if (todos.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No hay restaurantes disponibles'),
                    ),
                  )
                else if (restaurantes.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('Sin resultados para tu búsqueda'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: restaurantes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _RestauranteCard(
                          restaurante: restaurantes[index],
                          onTap: () {
                            context.push(
                              '/restaurantes/${restaurantes[index].id}/sucursales'
                              '?nombre=${Uri.encodeComponent(restaurantes[index].nombre)}',
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RestauranteCard extends StatelessWidget {
  const _RestauranteCard({
    required this.restaurante,
    required this.onTap,
  });

  final RestauranteModel restaurante;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final banner = restaurante.bannerUrl;
    final logo = restaurante.logoUrl;

    return Material(
      color: ColoresFoody.tarjeta,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner != null && banner.isNotEmpty)
                    Image.network(
                      banner,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _bannerPlaceholder(),
                    )
                  else
                    _bannerPlaceholder(),
                  Positioned(
                    left: 12,
                    bottom: -24,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: ColoresFoody.tarjeta, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: logo != null && logo.isNotEmpty
                            ? Image.network(
                                logo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _logoPlaceholder(),
                              )
                            : _logoPlaceholder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurante.nombre,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (restaurante.descripcion != null &&
                            restaurante.descripcion!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            restaurante.descripcion!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ColoresFoody.gris,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: ColoresFoody.gris,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColoresFoody.primario.withValues(alpha: 0.85),
            ColoresFoody.secundario.withValues(alpha: 0.75),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.restaurant, color: Colors.white54, size: 40),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return ColoredBox(
      color: ColoresFoody.primario.withValues(alpha: 0.12),
      child: Icon(Icons.restaurant, color: ColoresFoody.primario, size: 28),
    );
  }
}

class _ErrorEstado extends StatelessWidget {
  const _ErrorEstado({
    required this.mensaje,
    required this.detalle,
    required this.onReintentar,
  });

  final String mensaje;
  final String detalle;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mensaje, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(detalle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
