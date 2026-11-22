import 'package:flutter/material.dart';
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

  static ({Color fondo, Color texto}) chipEstado(String estado) {
    switch (estado) {
      case 'confirmado':
      case 'pendiente':
        return (
          fondo: const Color(0xFFEAF3DE),
          texto: const Color(0xFF3B6D11),
        );
      case 'en_cocina':
        return (
          fondo: const Color(0xFFFAEEDA),
          texto: const Color(0xFF854F0B),
        );
      case 'listo':
        return (
          fondo: const Color(0xFFE6F1FB),
          texto: const Color(0xFF185FA5),
        );
      case 'pagando':
        return (
          fondo: const Color(0xFFFBEAF0),
          texto: const Color(0xFF993556),
        );
      case 'asignado':
      case 'en_camino':
        return (
          fondo: const Color(0xFFEEEDFE),
          texto: const Color(0xFF534AB7),
        );
      case 'pendiente_aprobacion':
        return (
          fondo: const Color(0xFFFAEEDA),
          texto: const Color(0xFF854F0B),
        );
      default:
        return (fondo: AnaliticaTokens.surfaceMuted, texto: textoSecundario);
    }
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

/// Tarjeta blanca; [acentoIzquierdo] = barra lateral sin romper el radius.
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
    final cuerpo = Container(
      decoration: OperacionUi.tarjeta(
        esquema: usarTema ? Theme.of(context).colorScheme : null,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AnaliticaTokens.ink,
                    height: 1.1,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OperacionUi.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (acciones.isNotEmpty)
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: acciones,
              ),
            ),
        ],
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
    final fg = seleccionado ? Colors.white : AnaliticaTokens.inkMuted;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: seleccionado ? AnaliticaTokens.ink : AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seleccionado ? AnaliticaTokens.ink : AnaliticaTokens.border,
        ),
        boxShadow: seleccionado ? null : AnaliticaTokens.shadowSoft,
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
              color: seleccionado ? Colors.white : AnaliticaTokens.ink,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
  });

  final List<(String id, String etiqueta)> opciones;
  final String seleccionada;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: opciones.map((o) {
        final activa = o.$1 == seleccionada;
        return Material(
          color: activa ? AnaliticaTokens.ink : AnaliticaTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => onCambio(o.$1),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activa ? AnaliticaTokens.ink : AnaliticaTokens.border,
                ),
              ),
              child: Text(
                o.$2,
                style: TextStyle(
                  fontSize: 12,
                  color: activa ? Colors.white : AnaliticaTokens.inkMuted,
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AnaliticaTokens.border),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AnaliticaTokens.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, color: AnaliticaTokens.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AnaliticaTokens.inkSoft,
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
    final colores = OperacionUi.chipEstado(estado);
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
    // ponytail: ink seleccionado (línea Analítica); solo POS nuevo pedido.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: opciones.map((o) {
          final activa = o.$1 == seleccionada;
          return Material(
            color: activa ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              onTap: () => onCambio(o.$1),
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 11),
                child: Text(
                  o.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: activa ? Colors.white : const Color(0xFF6B7280),
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
    this.color = const Color(0xFFFAEEDA),
    this.colorTexto = const Color(0xFF854F0B),
  });

  final String mensaje;
  final String? accion;
  final VoidCallback? onAccion;
  final Color color;
  final Color colorTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colorTexto),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(fontSize: 12, color: colorTexto),
            ),
          ),
          if (accion != null && onAccion != null)
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(
                foregroundColor: colorTexto,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(accion!, style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
