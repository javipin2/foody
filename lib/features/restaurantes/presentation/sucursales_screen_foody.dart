import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cliente/presentation/foody_scaffold_cliente.dart';
import 'package:reserva_canchas/features/restaurantes/data/restaurantes_repository.dart';
import 'package:reserva_canchas/features/restaurantes/domain/sucursal_model.dart';

class SucursalesScreenFoody extends StatefulWidget {
  const SucursalesScreenFoody({
    super.key,
    required this.restauranteId,
    required this.restauranteNombre,
  });

  final String restauranteId;
  final String restauranteNombre;

  @override
  State<SucursalesScreenFoody> createState() => _SucursalesScreenFoodyState();
}

class _SucursalesScreenFoodyState extends State<SucursalesScreenFoody> {
  final _repositorio = RestaurantesRepository();
  late Future<List<SucursalModel>> _futureSucursales;

  /// Evita re-disparar auto-nav al volver atrás (loop sede única).
  bool _yaRedirigioUnica = false;

  @override
  void initState() {
    super.initState();
    _futureSucursales = _repositorio.listarSucursales(widget.restauranteId);
  }

  void _reintentar() {
    setState(() {
      _futureSucursales = _repositorio.listarSucursales(widget.restauranteId);
      _yaRedirigioUnica = false;
    });
  }

  void _irAMenu(SucursalModel sucursal, {required bool reemplazar}) {
    final ruta = '/menu/${sucursal.id}'
        '?nombre=${Uri.encodeComponent(sucursal.nombre)}';
    if (reemplazar) {
      // Back desde menú vuelve a lista de lugares, no a esta pantalla fantasma.
      context.pushReplacement(ruta);
    } else {
      context.push(ruta);
    }
  }

  void _autoIrSiUnicaSede(List<SucursalModel> sucursales) {
    if (sucursales.length != 1 || _yaRedirigioUnica) return;
    _yaRedirigioUnica = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _irAMenu(sucursales.first, reemplazar: true);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              widget.restauranteNombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AnaliticaTokens.ink,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Elegí una sede',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ],
        ),
      ),
      body: ColoredBox(
        color: AnaliticaTokens.canvas,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: FutureBuilder<List<SucursalModel>>(
              future: _futureSucursales,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return FoodyEstadoUi.cargando(mensaje: 'Cargando sedes…');
                }
                if (snapshot.hasError) {
                  return FoodyEstadoUi.error(
                    mensaje: mensajeErrorCliente(
                      snapshot.error!,
                      contexto: 'cargar las sedes',
                    ),
                    onReintentar: _reintentar,
                  );
                }

                final sucursales = snapshot.data ?? [];
                if (sucursales.isEmpty) {
                  return FoodyEstadoUi.vacio(
                    titulo: 'Sin sedes activas',
                    subtitulo:
                        'Este restaurante no tiene sedes disponibles ahora.',
                    icono: Icons.store_mall_directory_outlined,
                  );
                }

                if (sucursales.length == 1) {
                  _autoIrSiUnicaSede(sucursales);
                  return FoodyEstadoUi.cargando(mensaje: 'Abriendo menú…');
                }

                return RefreshIndicator(
                  color: AnaliticaTokens.ink,
                  onRefresh: () async => _reintentar(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: sucursales.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _SedeCard(
                        sucursal: sucursales[index],
                        onTap: () => _irAMenu(
                          sucursales[index],
                          reemplazar: false,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SedeCard extends StatelessWidget {
  const _SedeCard({required this.sucursal, required this.onTap});

  final SucursalModel sucursal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final direccion = (sucursal.direccion ?? '').trim();
    final subtitulo = direccion.isNotEmpty ? direccion : 'Ver menú y pedir';

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AnaliticaTokens.ink.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AnaliticaTokens.surfaceMuted,
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: AnaliticaTokens.ink.withValues(alpha: 0.72),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sucursal.nombre,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AnaliticaTokens.inkMuted,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ver menú',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
