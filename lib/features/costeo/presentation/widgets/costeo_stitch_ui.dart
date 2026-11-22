import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Paleta Costos / Márgenes (Stitch): teal salud · ámbar aviso · coral acento.
class CosteoStitch {
  CosteoStitch._();

  static const Color teal = Color(0xFF2EC4B6);
  static const Color amber = Color(0xFFEAB308);
  static const Color coral = ColoresFoody.primario; // #FF6B35
  static const Color critico = Color(0xFFE11D48);
  static Color titulo(BuildContext c) =>
      SaaSTokens.esOscuro(c) ? const Color(0xFFFFC4A8) : ColoresFoody.primario;
}

enum CosteoRiesgoNivel { saludable, bajo, critico, sinDatos }

CosteoRiesgoNivel costeoNivelDe({
  required num? margenPct,
  required bool sinReceta,
  required double umbral,
}) {
  if (sinReceta || margenPct == null) return CosteoRiesgoNivel.sinDatos;
  if (margenPct >= umbral) return CosteoRiesgoNivel.saludable;
  if (margenPct >= umbral * 0.65) return CosteoRiesgoNivel.bajo;
  return CosteoRiesgoNivel.critico;
}

Color costeoColorNivel(CosteoRiesgoNivel n) => switch (n) {
      CosteoRiesgoNivel.saludable => CosteoStitch.teal,
      CosteoRiesgoNivel.bajo => CosteoStitch.amber,
      CosteoRiesgoNivel.critico => CosteoStitch.critico,
      CosteoRiesgoNivel.sinDatos => const Color(0xFF9CA3AF),
    };

/// Chip de margen con glow suave (lista / detalle).
class CosteoMargenBadge extends StatelessWidget {
  const CosteoMargenBadge({
    super.key,
    required this.nivel,
    this.margenPct,
    this.compacto = false,
  });

  final CosteoRiesgoNivel nivel;
  final num? margenPct;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = costeoColorNivel(nivel);
    final label = nivel == CosteoRiesgoNivel.sinDatos
        ? 'Sin costear'
        : '${margenPct!.toStringAsFixed(0)}%';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 8 : 10,
        vertical: compacto ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: SaaSTokens.esOscuro(context) ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compacto ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: c,
              letterSpacing: -0.2,
            ),
          ),
          if (nivel == CosteoRiesgoNivel.saludable) ...[
            const SizedBox(width: 4),
            Icon(Icons.trending_up_rounded, size: 14, color: c),
          ] else if (nivel == CosteoRiesgoNivel.critico ||
              nivel == CosteoRiesgoNivel.bajo) ...[
            const SizedBox(width: 4),
            Icon(Icons.warning_amber_rounded, size: 13, color: c),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta resumen superior: SALUDABLE / MARGEN BAJO / SIN COSTEAR.
class CosteoStatusSummaryCard extends StatelessWidget {
  const CosteoStatusSummaryCard({
    super.key,
    required this.titulo,
    required this.cantidad,
    required this.leyenda,
    required this.nivel,
    this.onTap,
  });

  final String titulo;
  final int cantidad;
  final String leyenda;
  final CosteoRiesgoNivel nivel;
  final VoidCallback? onTap;

  IconData get _icono => switch (nivel) {
        CosteoRiesgoNivel.saludable => Icons.check_rounded,
        CosteoRiesgoNivel.bajo => Icons.priority_high_rounded,
        CosteoRiesgoNivel.critico => Icons.warning_amber_rounded,
        CosteoRiesgoNivel.sinDatos => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = costeoColorNivel(nivel);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SaaSTokens.borderSoft(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                        color: SaaSTokens.inkMuted(context),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.withValues(alpha: 0.5)),
                    ),
                    child: Icon(_icono, size: 16, color: c),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$cantidad',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1,
                  color: SaaSTokens.ink(context),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      leyenda,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill de filtro (Todos activo = naranja Foody).
class CosteoFiltroPill extends StatelessWidget {
  const CosteoFiltroPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? CosteoStitch.coral
            : SaaSTokens.surfaceMuted(context),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: selected
                  ? null
                  : Border.all(color: SaaSTokens.border(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : SaaSTokens.inkMuted(context),
                  ),
                ),
                if (dot != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card «Estado Financiero» del detalle (margen actual + rentabilidad).
class CosteoEstadoFinancieroCard extends StatelessWidget {
  const CosteoEstadoFinancieroCard({
    super.key,
    required this.margenPct,
    required this.nivel,
    required this.umbral,
    this.onAjustar,
    this.variacionCostos30d,
  });

  final num? margenPct;
  final CosteoRiesgoNivel nivel;
  final double umbral;
  final VoidCallback? onAjustar;
  /// Solo UI: si null, no se muestra (sin inventar datos).
  final num? variacionCostos30d;

  String get _rentabilidad => switch (nivel) {
        CosteoRiesgoNivel.saludable => 'Excelente',
        CosteoRiesgoNivel.bajo => 'Ajustable',
        CosteoRiesgoNivel.critico => 'En riesgo',
        CosteoRiesgoNivel.sinDatos => 'Sin datos',
      };

  @override
  Widget build(BuildContext context) {
    final c = costeoColorNivel(nivel);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_outlined,
                size: 18,
                color: SaaSTokens.inkMuted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estado Financiero',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SaaSTokens.ink(context),
                  ),
                ),
              ),
              if (onAjustar != null)
                IconButton(
                  tooltip: 'Ajustar margen',
                  onPressed: onAjustar,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.more_horiz,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'MARGEN ACTUAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: SaaSTokens.inkMuted(context),
            ),
          ),
          const SizedBox(height: 10),
          CosteoMargenBadge(nivel: nivel, margenPct: margenPct),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Rentabilidad',
                style: TextStyle(
                  fontSize: 13,
                  color: SaaSTokens.inkMuted(context),
                ),
              ),
              const Spacer(),
              Text(
                _rentabilidad,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Umbral sede: ${umbral.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11.5,
              color: SaaSTokens.inkSoft(context),
            ),
          ),
          if (variacionCostos30d != null) ...[
            const SizedBox(height: 8),
            Text(
              'Variación costos (30d): '
              '${variacionCostos30d! >= 0 ? '↑' : '↓'} '
              '${variacionCostos30d!.abs().toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: variacionCostos30d! >= 0
                    ? CosteoStitch.critico
                    : CosteoStitch.teal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniatura de plato (lista / preview).
class CosteoThumbPlato extends StatelessWidget {
  const CosteoThumbPlato({
    super.key,
    this.imagenUrl,
    this.size = 52,
    this.radius = 10,
  });

  final String? imagenUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imagenUrl?.trim();
    final tiene = url != null && url.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: SaaSTokens.surfaceMuted(context),
        child: tiene
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round().clamp(64, 512),
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Icon(
      Icons.restaurant_outlined,
      size: size * 0.42,
      color: SaaSTokens.inkSoft(context),
    );
  }
}

/// Fila lista desktop estilo Stitch (thumb + costo + precio sug. + badge).
class CosteoListaFilaStitch extends StatelessWidget {
  const CosteoListaFilaStitch({
    super.key,
    required this.nombre,
    required this.categoria,
    required this.costoLabel,
    required this.precioSugLabel,
    required this.nivel,
    this.margenPct,
    this.imagenUrl,
    this.seleccionado = false,
    this.onTap,
  });

  final String nombre;
  final String categoria;
  final String costoLabel;
  final String precioSugLabel;
  final CosteoRiesgoNivel nivel;
  final num? margenPct;
  final String? imagenUrl;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seleccionado
              ? CosteoStitch.coral.withValues(alpha: 0.55)
              : SaaSTokens.borderSoft(context),
          width: seleccionado ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                CosteoThumbPlato(imagenUrl: imagenUrl, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: SaaSTokens.ink(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        categoria,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: SaaSTokens.inkMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _metaCol(context, 'Costo', costoLabel),
                const SizedBox(width: 18),
                _metaCol(context, 'Precio sug.', precioSugLabel),
                const SizedBox(width: 14),
                if (nivel == CosteoRiesgoNivel.sinDatos)
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CosteoStitch.teal,
                      side: const BorderSide(color: CosteoStitch.teal),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('+ Receta'),
                  )
                else
                  CosteoMargenBadge(nivel: nivel, margenPct: margenPct),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaCol(BuildContext context, String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          k,
          style: TextStyle(
            fontSize: 11,
            color: SaaSTokens.inkSoft(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          v,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: SaaSTokens.ink(context),
          ),
        ),
      ],
    );
  }
}

/// Card lista móvil estilo Stitch.
class CosteoListaCardMovil extends StatelessWidget {
  const CosteoListaCardMovil({
    super.key,
    required this.nombre,
    required this.subtitulo,
    required this.nivel,
    this.margenPct,
    this.sinDatos = false,
    this.onTap,
    this.onAjustar,
  });

  final String nombre;
  final String subtitulo;
  final CosteoRiesgoNivel nivel;
  final num? margenPct;
  final bool sinDatos;
  final VoidCallback? onTap;
  final VoidCallback? onAjustar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: SaaSTokens.ink(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (sinDatos)
                      OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CosteoStitch.teal,
                          side: const BorderSide(color: CosteoStitch.teal),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('+ Receta'),
                      )
                    else
                      CosteoMargenBadge(nivel: nivel, margenPct: margenPct),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitulo,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle:
                              sinDatos ? FontStyle.italic : FontStyle.normal,
                          color: SaaSTokens.inkMuted(context),
                        ),
                      ),
                    ),
                    if (!sinDatos &&
                        (nivel == CosteoRiesgoNivel.bajo ||
                            nivel == CosteoRiesgoNivel.critico) &&
                        onAjustar != null)
                      TextButton.icon(
                        onPressed: onAjustar,
                        style: TextButton.styleFrom(
                          foregroundColor: CosteoStitch.amber,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Ajustar'),
                      )
                    else if (!sinDatos)
                      Text(
                        'Ver Receta ›',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CosteoStitch.teal,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preview izquierdo del detalle (foto + badges + precio).
class CosteoPreviewHeroCard extends StatelessWidget {
  const CosteoPreviewHeroCard({
    super.key,
    required this.nombre,
    required this.precioLabel,
    this.imagenUrl,
    this.categoria,
    this.idCorto,
    this.esPremium = false,
  });

  final String nombre;
  final String precioLabel;
  final String? imagenUrl;
  final String? categoria;
  final String? idCorto;
  final bool esPremium;

  @override
  Widget build(BuildContext context) {
    final url = imagenUrl?.trim();
    final tiene = url != null && url.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (tiene)
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    errorBuilder: (_, __, ___) => _imgPh(context),
                  )
                else
                  _imgPh(context),
                if (idCorto != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        idCorto!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SaaSTokens.ink(context),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (categoria != null && categoria!.isNotEmpty)
                      _pill(
                        context,
                        categoria!.toUpperCase(),
                        const Color(0xFF3B82F6),
                      ),
                    if (esPremium)
                      _pill(context, 'PREMIUM', CosteoStitch.coral),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'PRECIO CARTA',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  precioLabel,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: SaaSTokens.ink(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPh(BuildContext context) {
    return ColoredBox(
      color: SaaSTokens.surfaceMuted(context),
      child: Icon(
        Icons.restaurant_menu_outlined,
        size: 48,
        color: SaaSTokens.inkSoft(context),
      ),
    );
  }

  Widget _pill(BuildContext context, String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: c,
        ),
      ),
    );
  }
}

/// Barra inferior: costo · margen objetivo · precio sugerido · aplicar.
class CosteoPricingActionBar extends StatelessWidget {
  const CosteoPricingActionBar({
    super.key,
    required this.costoLabel,
    required this.precioSugLabel,
    required this.margenObjetivo,
    required this.onCambiarMargen,
    required this.onAplicar,
    this.guardando = false,
    this.puedeAplicar = true,
  });

  final String costoLabel;
  final String precioSugLabel;
  final double margenObjetivo;
  final VoidCallback onCambiarMargen;
  final VoidCallback onAplicar;
  final bool guardando;
  final bool puedeAplicar;

  @override
  Widget build(BuildContext context) {
    final riesgo = margenObjetivo < 25;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth >= 640;
          final bloqueCosto = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COSTO TOTAL',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: SaaSTokens.inkMuted(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                costoLabel,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: SaaSTokens.ink(context),
                ),
              ),
            ],
          );
          final bloqueMargen = InkWell(
            onTap: onCambiarMargen,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MARGEN OBJETIVO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: SaaSTokens.inkMuted(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        riesgo ? 'Riesgo' : 'Óptimo',
                        style: TextStyle(
                          fontSize: 11,
                          color: SaaSTokens.inkSoft(context),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            activeTrackColor: CosteoStitch.coral,
                            inactiveTrackColor: SaaSTokens.border(context),
                            thumbColor: CosteoStitch.coral,
                          ),
                          child: Slider(
                            value: margenObjetivo.clamp(5, 80),
                            min: 5,
                            max: 80,
                            onChanged: (_) => onCambiarMargen(),
                          ),
                        ),
                      ),
                      Text(
                        '${margenObjetivo.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: SaaSTokens.ink(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          final bloquePrecio = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CosteoStitch.teal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CosteoStitch.teal.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRECIO SUGERIDO',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: CosteoStitch.teal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  precioSugLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: SaaSTokens.ink(context),
                  ),
                ),
              ],
            ),
          );
          final btn = FilledButton.icon(
            onPressed: !puedeAplicar || guardando ? null : onAplicar,
            style: FilledButton.styleFrom(
              backgroundColor: CosteoStitch.coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.upload_rounded, size: 18),
            label: Text(
              guardando ? 'Aplicando…' : 'Aplicar a la carta',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );

          if (ancho) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: bloqueCosto),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: bloqueMargen),
                const SizedBox(width: 12),
                bloquePrecio,
                const SizedBox(width: 12),
                btn,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bloqueCosto,
              const SizedBox(height: 12),
              bloqueMargen,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: bloquePrecio),
                  const SizedBox(width: 10),
                  btn,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
