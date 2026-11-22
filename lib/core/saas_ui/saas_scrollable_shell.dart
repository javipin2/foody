import 'package:flutter/material.dart';

/// Shell de módulo admin: la cabecera (títulos, KPIs, banners) scrollea
/// fuera de vista al desplazar el [body]; el body queda con el espacio útil.
///
/// Evita Column(header fijo + Expanded) que deja poco alto para listas.
///
/// Uso típico:
/// - [header]: título, subtítulo, cards de resumen
/// - [body]: `TabBar` + `TabBarView`, o master-detail con `ListView` primario
class SaasScrollableShell extends StatelessWidget {
  const SaasScrollableShell({
    super.key,
    required this.header,
    required this.body,
    this.padding = EdgeInsets.zero,
    this.physics,
  });

  /// Bloques superiores que desaparecen al scrollear.
  final List<Widget> header;

  /// Zona de trabajo. Preferir un scrollable vertical primario
  /// (`ListView` / `CustomScrollView`) o `Column(TabBar, Expanded(TabBarView))`.
  final Widget body;

  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      physics: physics,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          for (final w in header)
            SliverToBoxAdapter(
              child: Padding(padding: padding, child: w),
            ),
        ];
      },
      body: body,
    );
  }
}
