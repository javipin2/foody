import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/promociones/data/promocion_vistos_service.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';
import 'package:reserva_canchas/features/promociones/presentation/promocion_story_viewer.dart';
import 'package:reserva_canchas/features/promociones/presentation/widgets/promo_story_anillo.dart';

/// Barra de estados por ciudad: **un anillo por restaurante** (WhatsApp).
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
  Set<String> _vistos = {};

  @override
  void initState() {
    super.initState();
    _future = _repo.listarGruposStoriesCiudad(widget.ciudadSlug);
    _cargarVistos();
  }

  Future<void> _cargarVistos() async {
    final ids = await PromocionVistosService.idsVistos();
    if (mounted) setState(() => _vistos = ids);
  }

  Future<void> _abrirGrupo(Map<String, dynamic> grupo) async {
    final promos = PromocionesRepository.promosDeGrupo(grupo);
    if (promos.isEmpty) return;
    var idx = promos.indexWhere((p) => !_vistos.contains(p['id'] as String?));
    if (idx < 0) idx = 0;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => PromocionStoryViewer(
          promociones: promos,
          indiceInicial: idx,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
    await _cargarVistos();
  }

  String? _previewUrl(Map<String, dynamic> grupo, List<Map<String, dynamic>> promos) {
    final logo = grupo['logo_url'] as String?;
    if (promos.isEmpty) return logo;
    final primera = promos.first;
    final tipo = (primera['tipo_media'] as String?) ?? 'imagen';
    if (tipo == 'video') return logo;
    final url = primera['imagen_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    return logo;
  }

  bool _grupoVisto(List<Map<String, dynamic>> promos) {
    if (promos.isEmpty) return true;
    return promos.every((p) => _vistos.contains(p['id'] as String? ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 118,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final grupos = List<Map<String, dynamic>>.from(snapshot.data!);
        // No vistos primero (como WhatsApp).
        grupos.sort((a, b) {
          final pa = PromocionesRepository.promosDeGrupo(a);
          final pb = PromocionesRepository.promosDeGrupo(b);
          final va = _grupoVisto(pa);
          final vb = _grupoVisto(pb);
          if (va == vb) return 0;
          return va ? 1 : -1;
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AnaliticaTokens.ink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Estados',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AnaliticaTokens.ink,
                        ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '· 24 h',
                    style: TextStyle(
                      fontSize: 12,
                      color: AnaliticaTokens.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: grupos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final grupo = grupos[i];
                  final promos = PromocionesRepository.promosDeGrupo(grupo);
                  final nombre =
                      (grupo['restaurante_nombre'] as String?)?.trim() ??
                          'Restaurante';
                  return PromoStoryAnillo(
                    imagenUrl: _previewUrl(grupo, promos),
                    etiqueta: nombre,
                    visto: _grupoVisto(promos),
                    onTap: () => _abrirGrupo(grupo),
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
