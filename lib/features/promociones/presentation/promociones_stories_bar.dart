import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/promociones/data/promocion_vistos_service.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';
import 'package:reserva_canchas/features/promociones/presentation/promocion_story_viewer.dart';
import 'package:reserva_canchas/features/promociones/presentation/widgets/promo_story_anillo.dart';

/// Un solo anillo por sede: al abrir, se pasan todos los estados (WhatsApp).
class PromocionesStoriesBar extends StatefulWidget {
  const PromocionesStoriesBar({
    super.key,
    required this.sucursalId,
    this.sucursalNombre,
  });

  final String sucursalId;
  final String? sucursalNombre;

  @override
  State<PromocionesStoriesBar> createState() => _PromocionesStoriesBarState();
}

class _PromocionesStoriesBarState extends State<PromocionesStoriesBar> {
  final _repo = PromocionesRepository();
  late Future<List<Map<String, dynamic>>> _future;
  Set<String> _vistos = {};

  @override
  void initState() {
    super.initState();
    _future = _repo.listarActivas(widget.sucursalId);
    _cargarVistos();
  }

  Future<void> _cargarVistos() async {
    final ids = await PromocionVistosService.idsVistos();
    if (mounted) setState(() => _vistos = ids);
  }

  Future<void> _abrir(List<Map<String, dynamic>> promos) async {
    var idx = promos.indexWhere((p) => !_vistos.contains(p['id'] as String?));
    if (idx < 0) idx = 0;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, __, ___) => PromocionStoryViewer(
          promociones: promos,
          indiceInicial: idx,
          sucursalIdFallback: widget.sucursalId,
          sucursalNombreFallback: widget.sucursalNombre,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
    await _cargarVistos();
  }

  String? _preview(List<Map<String, dynamic>> promos) {
    if (promos.isEmpty) return null;
    final p = promos.first;
    if ((p['tipo_media'] as String?) == 'video') return null;
    final url = p['imagen_url'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 4);
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final promos = snapshot.data!;
        final todosVistos =
            promos.every((p) => _vistos.contains(p['id'] as String? ?? ''));
        // Etiqueta corta: el AppBar ya muestra el nombre de la sede.
        const etiqueta = 'Estados';

        return SizedBox(
          height: 100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: PromoStoryAnillo(
                imagenUrl: _preview(promos),
                etiqueta: etiqueta,
                tamano: 58,
                visto: todosVistos,
                onTap: () => _abrir(promos),
              ),
            ),
          ),
        );
      },
    );
  }
}
