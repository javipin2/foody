import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';
import 'package:reserva_canchas/features/promociones/presentation/promocion_story_viewer.dart';

/// Barra de historias agregadas por ciudad (todas las sucursales).
class PromocionesCiudadStoriesBar extends StatefulWidget {
  const PromocionesCiudadStoriesBar({super.key, required this.ciudadSlug});

  final String ciudadSlug;

  @override
  State<PromocionesCiudadStoriesBar> createState() =>
      _PromocionesCiudadStoriesBarState();
}

class _PromocionesCiudadStoriesBarState
    extends State<PromocionesCiudadStoriesBar> {
  final _repo = PromocionesRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listarStoriesCiudad(widget.ciudadSlug);
  }

  void _abrir(int index, List<Map<String, dynamic>> promos) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PromocionStoryViewer(
          promociones: promos,
          indiceInicial: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final promos = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Promociones',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ColoresFoody.gris,
                    ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: promos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = promos[i];
                  final titulo =
                      (p['titulo'] as String?)?.trim() ??
                      (p['restaurante_nombre'] as String?)?.trim() ??
                      'Promo';
                  final url = p['imagen_url'] as String? ?? '';
                  return GestureDetector(
                    onTap: () => _abrir(i, promos),
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  ColoresFoody.primario,
                                  ColoresFoody.secundario,
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: ClipOval(
                                  child: url.isNotEmpty
                                      ? Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.local_offer,
                                            color: ColoresFoody.primario,
                                          ),
                                        )
                                      : Icon(
                                          Icons.local_offer,
                                          color: ColoresFoody.primario,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, height: 1.2),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
