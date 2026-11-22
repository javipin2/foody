import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Shell visual compartido para formularios admin (insumos, menú, costeo…).
/// Patrón: cards suaves, métricas claras, ancho responsive. Sin lógica de negocio.

class FoodyFormEstilo {
  FoodyFormEstilo._();

  static const radio = 16.0;
  static const radioCampo = 12.0;

  static InputDecoration campo({
    required String label,
    String? hint,
    String? helper,
    String? suffix,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool denso = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixText: suffix,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: denso,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioCampo),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioCampo),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radioCampo),
        borderSide: const BorderSide(color: ColoresFoody.primario, width: 1.5),
      ),
    );
  }
}

/// Diálogo responsive con título, subtítulo opcional y contenido scrolleable.
class FoodyDialogoShell extends StatelessWidget {
  const FoodyDialogoShell({
    super.key,
    required this.titulo,
    required this.contenido,
    required this.acciones,
    this.subtitulo,
    this.maxWidth = 520,
    this.maxHeightFactor = 0.88,
  });

  final String titulo;
  final String? subtitulo;
  final Widget contenido;
  final List<Widget> acciones;
  final double maxWidth;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ancho = size.width.clamp(280.0, maxWidth);
    final altoMax = size.height * maxHeightFactor;

    return AlertDialog(
      backgroundColor: ColoresFoody.grisSuave,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FoodyFormEstilo.radio + 4),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ColoresFoody.texto,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitulo!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: ancho,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: altoMax - 140),
          child: SingleChildScrollView(
            child: contenido,
          ),
        ),
      ),
      actions: acciones,
    );
  }
}

/// Sección con card blanca (agrupa campos relacionados).
class FoodyFormSeccion extends StatelessWidget {
  const FoodyFormSeccion({
    super.key,
    required this.titulo,
    required this.hijo,
    this.subtitulo,
    this.icono,
    this.trailing,
    this.acento,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final Widget hijo;
  final Widget? trailing;
  final Color? acento;

  @override
  Widget build(BuildContext context) {
    final color = acento ?? ColoresFoody.primario;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FoodyFormEstilo.radio),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: [
                if (icono != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icono, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ColoresFoody.texto,
                        ),
                      ),
                      if (subtitulo != null)
                        Text(
                          subtitulo!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: hijo,
          ),
        ],
      ),
    );
  }
}

/// Fila de métricas tipo «tarjeta KPI» (costo, margen, etc.).
class FoodyFormMetricas extends StatelessWidget {
  const FoodyFormMetricas({
    super.key,
    required this.items,
  });

  final List<FoodyMetricaItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final estrecho = c.maxWidth < 340;
        if (estrecho) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _chip(items[i], expand: true),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _chip(items[i], expand: false)),
            ],
          ],
        );
      },
    );
  }

  Widget _chip(FoodyMetricaItem item, {required bool expand}) {
    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.etiqueta,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }
}

class FoodyMetricaItem {
  const FoodyMetricaItem({
    required this.etiqueta,
    required this.valor,
    this.color = ColoresFoody.primario,
  });

  final String etiqueta;
  final String valor;
  final Color color;
}

/// Campos en fila que en móvil se apilan (evita RIGHT OVERFLOW).
class FoodyFormCamposAdaptativos extends StatelessWidget {
  const FoodyFormCamposAdaptativos({
    super.key,
    required this.campos,
    this.breakpoint = 380,
    this.separacion = 10,
  });

  final List<Widget> campos;
  final double breakpoint;
  final double separacion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < campos.length; i++) ...[
                if (i > 0) SizedBox(height: separacion),
                campos[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < campos.length; i++) ...[
              if (i > 0) SizedBox(width: separacion),
              Expanded(child: campos[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Badge pequeño de estado.
class FoodyFormBadge extends StatelessWidget {
  const FoodyFormBadge({
    super.key,
    required this.texto,
    this.color = ColoresFoody.secundario,
  });

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
