import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cliente/presentation/foody_scaffold_cliente.dart';
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

  void _abrir(RestauranteModel r) {
    context.push(
      '/restaurantes/${r.id}/sucursales'
      '?nombre=${Uri.encodeComponent(r.nombre)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final maxW = FoodyBreakpoints.maxContentCliente;

    return FoodyScaffoldCliente(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AnaliticaTokens.surface,
        foregroundColor: AnaliticaTokens.ink,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ciudadNombre,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AnaliticaTokens.ink,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Lugares cerca de ti',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert, color: AnaliticaTokens.inkMuted),
            onSelected: (value) {
              if (value == 'cambiar_ciudad') {
                context.go('/cliente');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'cambiar_ciudad',
                child: Text('Cambiar ciudad'),
              ),
            ],
          ),
        ],
      ),
      body: ColoredBox(
        color: AnaliticaTokens.canvas,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: RefreshIndicator(
              color: AnaliticaTokens.ink,
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
                    return FoodyEstadoUi.cargando(
                      mensaje: 'Cargando lugares…',
                    );
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        FoodyEstadoUi.error(
                          mensaje: mensajeErrorHttp(
                            snapshot.error!,
                            contexto: 'cargar restaurantes',
                          ),
                          onReintentar: _reintentar,
                        ),
                      ],
                    );
                  }

                  final todos = snapshot.data ?? [];
                  final restaurantes = _filtrar(todos);
                  final cols = FoodyBreakpoints.esLarge(ancho)
                      ? 3
                      : (FoodyBreakpoints.esExpanded(ancho) ? 2 : 1);
                  final bannerAlto = FoodyBreakpoints.esLarge(ancho)
                      ? 156.0
                      : (FoodyBreakpoints.esExpanded(ancho) ? 140.0 : 132.0);
                  // Portada + solape logo (~28) + pie (padding 30+12 + texto ~34).
                  final cardAlto = bannerAlto + 100;

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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AnaliticaTokens.surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AnaliticaTokens.border),
                              boxShadow: AnaliticaTokens.shadowSoft,
                            ),
                            child: TextField(
                              controller: _busquedaController,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AnaliticaTokens.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar restaurante…',
                                hintStyle: const TextStyle(
                                  color: AnaliticaTokens.inkSoft,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AnaliticaTokens.inkSoft,
                                ),
                                suffixIcon: _filtro.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          color: AnaliticaTokens.inkSoft,
                                        ),
                                        onPressed: _busquedaController.clear,
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (todos.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: FoodyEstadoUi.vacio(
                            titulo: 'Aún no hay lugares aquí',
                            subtitulo: 'Prueba otra ciudad o vuelve más tarde',
                            icono: Icons.storefront_outlined,
                            etiquetaAccion: 'Cambiar ciudad',
                            onAccion: () => context.go('/cliente'),
                          ),
                        )
                      else if (restaurantes.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: FoodyEstadoUi.vacio(
                            titulo: 'Sin resultados',
                            subtitulo: 'Prueba otro nombre',
                            icono: Icons.search_off_outlined,
                          ),
                        )
                      else if (cols == 1)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          sliver: SliverList.separated(
                            itemCount: restaurantes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              return _RestauranteCard(
                                restaurante: restaurantes[index],
                                bannerAlto: bannerAlto,
                                onTap: () => _abrir(restaurantes[index]),
                              );
                            },
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              mainAxisExtent: cardAlto,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _RestauranteCard(
                                  restaurante: restaurantes[index],
                                  bannerAlto: bannerAlto,
                                  onTap: () => _abrir(restaurantes[index]),
                                );
                              },
                              childCount: restaurantes.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestauranteCard extends StatelessWidget {
  const _RestauranteCard({
    required this.restaurante,
    required this.onTap,
    this.bannerAlto = 132,
  });

  final RestauranteModel restaurante;
  final VoidCallback onTap;
  final double bannerAlto;

  static const _logoSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final banner = restaurante.bannerUrl;
    final logo = restaurante.logoUrl;
    final tieneLogo = logo != null && logo.isNotEmpty;
    final subtitulo = (restaurante.descripcion ?? '').trim().isNotEmpty
        ? restaurante.descripcion!.trim()
        : 'Ver menú y sedes';

    return Material(
      color: AnaliticaTokens.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: bannerAlto,
                    width: double.infinity,
                    child: banner != null && banner.isNotEmpty
                        ? Image.network(
                            banner,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: bannerAlto,
                            alignment: Alignment.center,
                            cacheWidth: 900,
                            errorBuilder: (_, __, ___) => _bannerPlaceholder(),
                          )
                        : _bannerPlaceholder(),
                  ),
                  // Anillo blanco vía padding (border+clip llenaba el círculo y ocultaba el borde).
                  Positioned(
                    left: 14,
                    bottom: -_logoSize / 2.4,
                    child: Container(
                      width: _logoSize,
                      height: _logoSize,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AnaliticaTokens.ink.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: tieneLogo
                            ? Image.network(
                                logo,
                                fit: BoxFit.cover,
                                width: _logoSize,
                                height: _logoSize,
                                alignment: Alignment.center,
                                cacheWidth: 240,
                                errorBuilder: (_, __, ___) =>
                                    _logoPlaceholder(),
                              )
                            : _logoPlaceholder(),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 30, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurante.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AnaliticaTokens.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AnaliticaTokens.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AnaliticaTokens.ink,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ver menú',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerPlaceholder() {
    return const ColoredBox(
      color: AnaliticaTokens.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: AnaliticaTokens.inkSoft,
          size: 40,
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return const ColoredBox(
      color: AnaliticaTokens.surfaceMuted,
      child: Icon(
        Icons.storefront_rounded,
        color: AnaliticaTokens.ink,
        size: 26,
      ),
    );
  }
}
