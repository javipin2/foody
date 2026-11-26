import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Etiqueta de sección (estilo guía costeo).
class CosteoEtiquetaSeccion extends StatelessWidget {
  const CosteoEtiquetaSeccion({
    super.key,
    required this.titulo,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AnaliticaTokens.inkSoft,
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              style: const TextStyle(
                fontSize: 12,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta «lo que ve el cliente».
class CosteoPlatoClienteCard extends StatelessWidget {
  const CosteoPlatoClienteCard({
    super.key,
    required this.nombre,
    required this.precio,
    this.compacto = false,
    this.onMargen,
  });

  final String nombre;
  final String precio;

  /// Cabecera densa (móvil / colapsada).
  final bool compacto;
  final VoidCallback? onMargen;

  @override
  Widget build(BuildContext context) {
    if (compacto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AnaliticaTokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AnaliticaTokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: AnaliticaTokens.ink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AnaliticaTokens.ink,
                    ),
                  ),
                  const Text(
                    'Precio de venta',
                    style: TextStyle(
                      fontSize: 11,
                      color: AnaliticaTokens.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              precio,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AnaliticaTokens.ink,
              ),
            ),
            if (onMargen != null)
              IconButton(
                tooltip: 'Margen objetivo',
                visualDensity: VisualDensity.compact,
                onPressed: onMargen,
                icon: const Icon(Icons.tune, size: 20),
                color: AnaliticaTokens.inkMuted,
              ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AnaliticaTokens.border),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AnaliticaTokens.ink,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AnaliticaTokens.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Lo que ve el cliente: nombre y precio.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          precio,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AnaliticaTokens.ink,
                          ),
                        ),
                        const Text(
                          'precio de venta',
                          style: TextStyle(
                            fontSize: 11,
                            color: AnaliticaTokens.inkSoft,
                          ),
                        ),
                        if (onMargen != null)
                          TextButton.icon(
                            onPressed: onMargen,
                            style: TextButton.styleFrom(
                              foregroundColor: AnaliticaTokens.inkMuted,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text(
                              'Margen objetivo',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CosteoFlechaFlujo extends StatelessWidget {
  const CosteoFlechaFlujo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child:
            Icon(Icons.arrow_downward, color: Colors.grey.shade400, size: 28),
      ),
    );
  }
}

/// Secuencia de trabajo de una receta. Los pasos son una guía visual y no
/// implican que el producto ya tenga esa configuración guardada.
class CosteoFlujoReceta extends StatelessWidget {
  const CosteoFlujoReceta({super.key, this.pasoActivo = 1});

  final int pasoActivo;

  static const _pasos = [
    'Ingredientes',
    'Preparaciones',
    'Empaques',
    'Acompañamientos',
    'Costo y margen',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoDisponible = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compacto = anchoDisponible < 620;
        final anchoPaso = compacto ? 104.0 : anchoDisponible / _pasos.length;
        return SingleChildScrollView(
          key: const ValueKey('costeo-flujo-receta'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: compacto ? anchoPaso * _pasos.length : anchoDisponible,
            child: Row(
              children: [
                for (var i = 0; i < _pasos.length; i++)
                  SizedBox(
                    width: anchoPaso,
                    child: _PasoReceta(
                      numero: i + 1,
                      titulo: _pasos[i],
                      activo: i + 1 == pasoActivo,
                      ultimo: i == _pasos.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PasoReceta extends StatelessWidget {
  const _PasoReceta({
    required this.numero,
    required this.titulo,
    required this.activo,
    required this.ultimo,
  });

  final int numero;
  final String titulo;
  final bool activo;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AnaliticaTokens.ventas : AnaliticaTokens.border;
    final texto = activo ? AnaliticaTokens.ink : AnaliticaTokens.inkMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (numero > 1)
              Expanded(
                child: Container(height: 1, color: AnaliticaTokens.border),
              ),
            Container(
              key: activo ? ValueKey('costeo-paso-activo-$numero') : null,
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo ? AnaliticaTokens.ventas : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: activo ? 0 : 1.2),
              ),
              child: Text(
                '$numero',
                style: TextStyle(
                  color: activo ? Colors.white : texto,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            if (!ultimo)
              Expanded(
                child: Container(height: 1, color: AnaliticaTokens.border),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: texto,
              fontSize: 11,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge de categoría en receta (naranja / verde / beige).
class CosteoBadgeGrupo extends StatelessWidget {
  const CosteoBadgeGrupo({
    super.key,
    required this.texto,
    required this.color,
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
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

/// Línea de resumen de costo (solo lectura).
class CosteoLineaResumen extends StatelessWidget {
  const CosteoLineaResumen({
    super.key,
    required this.nombre,
    required this.detalle,
    required this.total,
    this.detallePrecio,
    this.extra,
    this.etiqueta,
  });

  final String nombre;
  final String detalle;
  final String total;
  final String? detallePrecio;
  final Widget? extra;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AnaliticaTokens.ink,
                        ),
                      ),
                    ),
                    if (etiqueta != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AnaliticaTokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          etiqueta!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AnaliticaTokens.inkSoft,
                  ),
                ),
                if (extra != null) ...[
                  const SizedBox(height: 6),
                  extra!,
                ],
              ],
            ),
          ),
          if (detallePrecio != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: Text(
                detallePrecio!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AnaliticaTokens.inkSoft,
                ),
              ),
            ),
          Text(
            total,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AnaliticaTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloque agrupado de líneas de receta.
class CosteoGrupoReceta extends StatefulWidget {
  const CosteoGrupoReceta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.colorBadge,
    required this.lineas,
    this.numero,
    this.inicialmenteExpandido = true,
  });

  final String titulo;
  final String subtitulo;
  final Color colorBadge;
  final List<Widget> lineas;
  final int? numero;
  final bool inicialmenteExpandido;

  @override
  State<CosteoGrupoReceta> createState() => _CosteoGrupoRecetaState();
}

class _CosteoGrupoRecetaState extends State<CosteoGrupoReceta> {
  late bool _expandido;

  @override
  void initState() {
    super.initState();
    _expandido = widget.inicialmenteExpandido;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lineas.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaaSTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.numero != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.colorBadge,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${widget.numero}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.titulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SaaSTokens.ink(context),
                      ),
                    ),
                    Text(
                      widget.subtitulo,
                      style: TextStyle(
                        fontSize: 11,
                        color: SaaSTokens.inkMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SaaSTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(SaaSTokens.radioPill),
                ),
                child: Text(
                  '${widget.lineas.length}',
                  style: TextStyle(
                    color: SaaSTokens.inkMuted(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                expanded: _expandido,
                label: _expandido
                    ? 'Contraer ${widget.titulo}'
                    : 'Expandir ${widget.titulo}',
                child: IconButton(
                  key: ValueKey(
                      'alternar-grupo-costeo-${widget.numero ?? widget.titulo}'),
                  tooltip: _expandido ? 'Contraer sección' : 'Expandir sección',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _expandido = !_expandido),
                  icon: Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    color: SaaSTokens.inkMuted(context),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: SaaSTokens.duracionTransicion,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expandido
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.lineas,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Pie con costo total, food cost y margen.
class CosteoResumenPie extends StatelessWidget {
  const CosteoResumenPie({
    super.key,
    required this.tituloCosto,
    required this.costoTotal,
    required this.foodCostPct,
    required this.margenBruto,
    required this.margenPct,
    required this.colorFoodCost,
    this.lineasExtra = const [],
    this.numero,
  });

  final String tituloCosto;
  final String costoTotal;
  final double? foodCostPct;
  final String margenBruto;
  final String margenPct;
  final Color colorFoodCost;
  final List<Widget> lineasExtra;
  final int? numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AnaliticaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (numero != null) ...[
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AnaliticaTokens.inventario,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$numero',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Costo y margen',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AnaliticaTokens.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...lineasExtra,
          LayoutBuilder(
            builder: (context, constraints) {
              const estiloTitulo = TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.ink,
              );
              const estiloCosto = TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AnaliticaTokens.ink,
              );
              if (constraints.maxWidth < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tituloCosto, style: estiloTitulo),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(costoTotal, style: estiloCosto),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: Text(tituloCosto, style: estiloTitulo)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      costoTotal,
                      textAlign: TextAlign.end,
                      style: estiloCosto,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final estrecho = c.maxWidth < 420;
              final kpis = [
                Expanded(
                  child: _kpiMini(
                    'Food cost',
                    foodCostPct != null
                        ? '${foodCostPct!.toStringAsFixed(1)}%'
                        : '—',
                    colorFoodCost,
                    foodCostPct != null ? (foodCostPct! / 100).clamp(0, 1) : 0,
                  ),
                ),
                SizedBox(width: estrecho ? 8 : 12),
                Expanded(
                  child: _kpiMini(
                    'Margen bruto',
                    margenBruto,
                    AnaliticaTokens.inventario,
                    null,
                  ),
                ),
                SizedBox(width: estrecho ? 8 : 12),
                Expanded(
                  child: _kpiMini(
                    'Margen %',
                    margenPct,
                    AnaliticaTokens.inventario,
                    null,
                  ),
                ),
              ];
              return Row(children: kpis);
            },
          ),
        ],
      ),
    );
  }

  Widget _kpiMini(String label, String valor, Color color, double? progreso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AnaliticaTokens.inkSoft,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (progreso != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 5,
              backgroundColor: AnaliticaTokens.borderSoft,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

/// Pasos guía compactos (insumos / costeo).
/// NAV-MC-05: colapsable y descartable; recuerda preferencia si [preferenciaKey].
class GuiaPasosCompacta extends StatefulWidget {
  const GuiaPasosCompacta({
    super.key,
    required this.pasos,
    this.preferenciaKey,
  });

  final List<String> pasos;

  /// Si no es null, guarda colapsado/oculto en SharedPreferences.
  final String? preferenciaKey;

  @override
  State<GuiaPasosCompacta> createState() => _GuiaPasosCompactaState();
}

class _GuiaPasosCompactaState extends State<GuiaPasosCompacta> {
  bool _expandida = true;
  bool _ocultarParaSiempre = false;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferencia();
  }

  Future<void> _cargarPreferencia() async {
    final key = widget.preferenciaKey;
    if (key == null) {
      setState(() => _listo = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ocultarParaSiempre = prefs.getBool('${key}_ocultar') ?? false;
      _expandida = prefs.getBool('${key}_expandida') ?? true;
      _listo = true;
    });
  }

  Future<void> _guardar() async {
    final key = widget.preferenciaKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${key}_ocultar', _ocultarParaSiempre);
    await prefs.setBool('${key}_expandida', _expandida);
  }

  @override
  Widget build(BuildContext context) {
    if (!_listo) return const SizedBox.shrink();

    if (_ocultarParaSiempre) {
      return Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: 'Mostrar orden recomendado',
          onPressed: () {
            setState(() {
              _ocultarParaSiempre = false;
              _expandida = true;
            });
            _guardar();
          },
          icon: const Icon(Icons.help_outline, color: AnaliticaTokens.inkMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AnaliticaTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                size: 16,
                color: AnaliticaTokens.inkMuted,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Orden recomendado',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AnaliticaTokens.ink,
                    fontSize: 12.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: _expandida ? 'Ocultar pasos' : 'Ver pasos',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _expandida = !_expandida);
                  _guardar();
                },
                icon: Icon(
                  _expandida ? Icons.expand_less : Icons.expand_more,
                  color: AnaliticaTokens.inkSoft,
                ),
              ),
              IconButton(
                tooltip: 'No volver a mostrar',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _ocultarParaSiempre = true);
                  _guardar();
                },
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AnaliticaTokens.inkSoft,
                ),
              ),
            ],
          ),
          if (_expandida) ...[
            const SizedBox(height: 4),
            ...widget.pasos.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.key + 1}.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AnaliticaTokens.ink,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
