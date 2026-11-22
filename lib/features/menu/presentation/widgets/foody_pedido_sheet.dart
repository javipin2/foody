import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Bottom sheet arrastrable: abre alto y hace un rebote corto para
/// señalizar que se puede subir/bajar.
class FoodyPedidoSheet extends StatefulWidget {
  const FoodyPedidoSheet({
    super.key,
    required this.builder,
    this.initialChildSize = 0.88,
    this.minChildSize = 0.48,
    this.maxChildSize = 0.95,
  });

  final Widget Function(
    BuildContext context,
    ScrollController scrollController,
  ) builder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  @override
  State<FoodyPedidoSheet> createState() => _FoodyPedidoSheetState();
}

class _FoodyPedidoSheetState extends State<FoodyPedidoSheet> {
  final _drag = DraggableScrollableController();
  bool _hintHecho = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reboteHint());
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  Future<void> _reboteHint() async {
    if (_hintHecho || !mounted) return;
    _hintHecho = true;
    // Espera a que el sheet se ancle tras la animación del modal.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !_drag.isAttached) return;

    final techo = widget.maxChildSize;
    final base = widget.initialChildSize;
    final pico = (base + 0.045).clamp(base, techo);

    try {
      await _drag.animateTo(
        pico,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || !_drag.isAttached) return;
      await _drag.animateTo(
        base,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
      );
    } catch (_) {
      // Sheet cerrado a mitad del hint.
    }
  }

  @override
  Widget build(BuildContext context) {
    // snapSizes: solo valores entre min y max (excluidos).
    final snaps = <double>[widget.initialChildSize];
    if (widget.initialChildSize < widget.maxChildSize - 0.02) {
      snaps.add(widget.maxChildSize - 0.01);
    }

    return DraggableScrollableSheet(
      controller: _drag,
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      snap: true,
      snapSizes: snaps,
      builder: (context, scrollController) {
        return widget.builder(context, scrollController);
      },
    );
  }
}

/// Manija más visible del sheet.
class FoodySheetHandle extends StatelessWidget {
  const FoodySheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: AnaliticaTokens.inkSoft.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}
