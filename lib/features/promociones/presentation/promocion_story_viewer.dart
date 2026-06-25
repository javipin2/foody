import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';

class PromocionStoryViewer extends StatefulWidget {
  const PromocionStoryViewer({
    super.key,
    required this.promociones,
    this.indiceInicial = 0,
  });

  final List<Map<String, dynamic>> promociones;
  final int indiceInicial;

  @override
  State<PromocionStoryViewer> createState() => _PromocionStoryViewerState();
}

class _PromocionStoryViewerState extends State<PromocionStoryViewer> {
  final _repo = PromocionesRepository();
  late final PageController _pageController;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial;
    _pageController = PageController(initialPage: _indice);
    _registrarVista(_indice);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _registrarVista(int i) async {
    if (i < 0 || i >= widget.promociones.length) return;
    final id = widget.promociones[i]['id'] as String?;
    if (id == null) return;
    try {
      await _repo.registrarVista(id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.promociones.length,
            onPageChanged: (i) {
              setState(() => _indice = i);
              _registrarVista(i);
            },
            itemBuilder: (context, i) {
              final p = widget.promociones[i];
              final url = p['imagen_url'] as String? ?? '';
              final titulo = p['titulo'] as String? ?? '';
              final desc = p['descripcion'] as String? ?? '';
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (url.isNotEmpty)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: ColoresFoody.primario),
                        );
                      },
                      errorBuilder: (_, __, ___) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'No se pudo cargar la imagen.\nPrueba con una URL directa (.jpg/.png) en admin.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.local_offer, color: Colors.white54, size: 64),
                    ),
                  if (titulo.isNotEmpty || desc.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (titulo.isNotEmpty)
                              Text(
                                titulo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                desc,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.promociones.length > 1)
                    Text(
                      '${_indice + 1}/${widget.promociones.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
          if (widget.promociones.length > 1)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                child: Row(
                  children: List.generate(widget.promociones.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _indice
                              ? ColoresFoody.primario
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
