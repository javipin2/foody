import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Tokens visuales del rediseño operativo (alineado a AnaliticaTokens).
class OperacionUi {
  OperacionUi._();

  static const fondoPagina = AnaliticaTokens.canvas;
  static const borde = AnaliticaTokens.border;
  static const textoSecundario = AnaliticaTokens.inkMuted;
  static const textoTerciario = AnaliticaTokens.inkSoft;
  static const primarioSuave = AnaliticaTokens.surfaceMuted;
  static const primarioOscuro = AnaliticaTokens.ink;

  /// Borde uniforme (seguro con [BorderRadius]).
  static BoxDecoration tarjeta({ColorScheme? esquema}) {
    return BoxDecoration(
      color: esquema?.surfaceContainerLow ?? AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: esquema?.outlineVariant ?? borde),
      boxShadow: esquema == null ? AnaliticaTokens.shadowSoft : null,
    );
  }

  static ({Color fondo, Color texto}) chipEstado(
    BuildContext context,
    String estado,
  ) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final (color, fondoClaro, textoClaro) = switch (estado) {
      'confirmado' || 'pendiente' => (
          SaaSTokens.positivo,
          const Color(0xFFEAF3DE),
          const Color(0xFF3B6D11),
        ),
      'en_cocina' || 'pendiente_aprobacion' => (
          SaaSTokens.prioridadMedia,
          const Color(0xFFFAEEDA),
          const Color(0xFF854F0B),
        ),
      'listo' => (
          SaaSTokens.pedidos,
          const Color(0xFFE6F1FB),
          const Color(0xFF185FA5),
        ),
      'pagando' => (
          SaaSTokens.negativo,
          const Color(0xFFFBEAF0),
          const Color(0xFF993556),
        ),
      'asignado' || 'en_camino' => (
          SaaSTokens.clientes,
          const Color(0xFFEEEDFE),
          const Color(0xFF534AB7),
        ),
      _ => (
          scheme.onSurfaceVariant,
          scheme.surfaceContainer,
          scheme.onSurfaceVariant
        ),
    };
    return (
      fondo: oscuro ? color.withValues(alpha: 0.2) : fondoClaro,
      texto: oscuro ? Color.lerp(color, Colors.white, 0.46)! : textoClaro,
    );
  }

  static String etiquetaEstado(String estado) {
    const mapa = {
      'pendiente_aprobacion': 'Por aprobar',
      'pendiente': 'Pendiente',
      'confirmado': 'Confirmado',
      'en_cocina': 'En cocina',
      'listo': 'Listo',
      'pagando': 'Pagando',
      'asignado': 'Asignado',
      'en_camino': 'En camino',
    };
    return mapa[estado] ?? estado;
  }
}

/// Tarjeta de operación con superficie y borde del tema activo.
class OperacionTarjeta extends StatelessWidget {
  const OperacionTarjeta({
    super.key,
    required this.child,
    this.acentoIzquierdo,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.usarTema = false,
  });

  final Widget child;
  final Color? acentoIzquierdo;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool usarTema;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cuerpo = Container(
      decoration: OperacionUi.tarjeta(
        esquema: usarTema ? scheme : null,
      ),
      child: acentoIzquierdo == null
          ? Padding(padding: padding, child: child)
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3, color: acentoIzquierdo),
                    Expanded(child: Padding(padding: padding, child: child)),
                  ],
                ),
              ),
            ),
    );
    if (onTap == null && onLongPress == null) return cuerpo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: cuerpo,
      ),
    );
  }
}

class OperacionPageHeader extends StatelessWidget {
  const OperacionPageHeader({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acciones = const [],
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = constraints.maxWidth < FoodyBreakpoints.expanded;
          final theme = Theme.of(context);
          final encabezado = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.25,
                  height: 1.15,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          );
          if (acciones.isEmpty) return encabezado;
          final accionesWidget = Wrap(
            alignment: compacto ? WrapAlignment.start : WrapAlignment.end,
            spacing: SaaSTokens.s8,
            runSpacing: SaaSTokens.s8,
            children: acciones,
          );
          if (compacto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                encabezado,
                const SizedBox(height: SaaSTokens.s12),
                Align(alignment: Alignment.centerRight, child: accionesWidget),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: encabezado),
              const SizedBox(width: SaaSTokens.s16),
              Flexible(child: accionesWidget),
            ],
          );
        },
      ),
    );
  }
}

class OperacionStatChip extends StatelessWidget {
  const OperacionStatChip({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.colorPunto,
    this.icono,
    this.onTap,
    this.seleccionado = false,
  });

  final String etiqueta;
  final String valor;
  final Color? colorPunto;
  final IconData? icono;
  final VoidCallback? onTap;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fondo = seleccionado ? scheme.onSurface : scheme.surface;
    final fg = seleccionado ? scheme.surface : scheme.onSurfaceVariant;
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SaaSTokens.duracionControl;
    final child = AnimatedContainer(
      duration: duracion,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: onTap == null ? 0 : 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(SaaSTokens.r8),
        border: Border.all(
          color: seleccionado ? scheme.onSurface : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (colorPunto != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorPunto,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icono != null) ...[
            Icon(icono, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaaSTokens.r8),
      child: child,
    );
  }
}

class OperacionPillTabs extends StatelessWidget {
  const OperacionPillTabs({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.onCambio,
    this.scrollable = false,
  });

  final List<(String id, String etiqueta)> opciones;
  final String seleccionada;
  final ValueChanged<String> onCambio;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fondoSeleccionado = scheme.onSurface;
    final textoSeleccionado = scheme.surface;
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SaaSTokens.duracionControl;
    final pills = opciones.map((o) {
      final activa = o.$1 == seleccionada;
      return Semantics(
        button: true,
        selected: activa,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
          child: InkWell(
            onTap: () => onCambio(o.$1),
            borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
            child: AnimatedContainer(
              duration: duracion,
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: activa ? fondoSeleccionado : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
                border: Border.all(
                  color: activa ? fondoSeleccionado : scheme.outlineVariant,
                ),
              ),
              child: Text(
                o.$2,
                style: TextStyle(
                  fontSize: 12,
                  color: activa ? textoSeleccionado : scheme.onSurfaceVariant,
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
    if (scrollable) {
      return FoodyScrollHorizontalFade(
        child: SizedBox(
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < pills.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  pills[i],
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 6, children: pills);
  }
}

class OperacionRoleNavItem {
  const OperacionRoleNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// Navegación compacta compartida por las vistas operativas de cada rol.
class OperacionRoleNavBar extends StatelessWidget {
  const OperacionRoleNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compactTop = false,
  });

  final List<OperacionRoleNavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compactTop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SaaSTokens.duracionControl;
    final tabs = [
      for (var i = 0; i < destinations.length; i++)
        Expanded(
          child: _OperacionRoleNavDestination(
            key: ValueKey<String>('operacion-role-nav-$i'),
            item: destinations[i],
            selected: i == selectedIndex,
            compactTop: compactTop,
            duration: duration,
            onTap: () => onDestinationSelected(i),
          ),
        ),
    ];
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: compactTop
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
            bottom: compactTop
                ? BorderSide(color: scheme.outlineVariant)
                : BorderSide.none,
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: !compactTop,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compactTop ? 16 : 8,
              vertical: compactTop ? 4 : 6,
            ),
            child: compactTop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Row(children: tabs),
                    ),
                  )
                : Row(children: tabs),
          ),
        ),
      ),
    );
  }
}

class _OperacionRoleNavDestination extends StatelessWidget {
  const _OperacionRoleNavDestination({
    super.key,
    required this.item,
    required this.selected,
    required this.compactTop,
    required this.duration,
    required this.onTap,
  });

  final OperacionRoleNavItem item;
  final bool selected;
  final bool compactTop;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              constraints: BoxConstraints(minHeight: compactTop ? 48 : 56),
              padding: EdgeInsets.symmetric(
                horizontal: compactTop ? 14 : 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
                border: Border.all(
                  color: selected ? scheme.outlineVariant : Colors.transparent,
                ),
              ),
              child: compactTop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.selectedIcon ?? item.icon,
                            size: 18, color: foreground),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.selectedIcon ?? item.icon,
                            size: 20, color: foreground),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class OperacionBusqueda extends StatelessWidget {
  const OperacionBusqueda({
    super.key,
    required this.controller,
    this.hint = 'Buscar…',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(SaaSTokens.r8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OperacionStatusChip extends StatelessWidget {
  const OperacionStatusChip({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final colores = OperacionUi.chipEstado(context, estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colores.fondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        OperacionUi.etiquetaEstado(estado),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colores.texto,
        ),
      ),
    );
  }
}

class OperacionMetricCard extends StatelessWidget {
  const OperacionMetricCard({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.subtitulo,
    this.colorValor,
  });

  final String etiqueta;
  final String valor;
  final String? subtitulo;
  final Color? colorValor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: OperacionUi.tarjeta(esquema: scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorValor ?? scheme.onSurface,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class OperacionTipoToggle extends StatelessWidget {
  const OperacionTipoToggle({
    super.key,
    required this.opciones,
    required this.seleccionada,
    required this.onCambio,
  });

  final List<(String id, String etiqueta)> opciones;
  final String seleccionada;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duracion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SaaSTokens.duracionControl;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(SaaSTokens.r8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: opciones.map((o) {
          final activa = o.$1 == seleccionada;
          return Semantics(
            button: true,
            selected: activa,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(SaaSTokens.r8),
              child: InkWell(
                onTap: () => onCambio(o.$1),
                borderRadius: BorderRadius.circular(SaaSTokens.r8),
                child: AnimatedContainer(
                  duration: duracion,
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 48),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: activa ? scheme.onSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(SaaSTokens.r8),
                  ),
                  child: Text(
                    o.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: activa ? scheme.surface : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class OperacionAviso extends StatelessWidget {
  const OperacionAviso({
    super.key,
    required this.mensaje,
    this.accion,
    this.onAccion,
    this.color,
    this.colorTexto,
  });

  final String mensaje;
  final String? accion;
  final VoidCallback? onAccion;
  final Color? color;
  final Color? colorTexto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = color ?? const Color(0xFFFAEEDA);
    final texto = colorTexto ?? const Color(0xFF854F0B);
    final fondoTema = oscuro
        ? Color.alphaBlend(fondo.withValues(alpha: 0.22), scheme.surface)
        : fondo;
    final textoTema = oscuro ? Color.lerp(texto, Colors.white, 0.42)! : texto;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fondoTema,
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mensajeWidget = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: textoTema),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(fontSize: 12, color: textoTema, height: 1.4),
                ),
              ),
            ],
          );
          if (accion == null || onAccion == null) return mensajeWidget;
          final boton = TextButton(
            onPressed: onAccion,
            style: TextButton.styleFrom(
              foregroundColor: textoTema,
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(accion!),
          );
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mensajeWidget,
                Align(alignment: Alignment.centerRight, child: boton),
              ],
            );
          }
          return Row(
            children: [Expanded(child: mensajeWidget), boton],
          );
        },
      ),
    );
  }
}
