import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';

const _nombresDia = [
  'Domingo',
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
];

/// Horarios de apertura por día (admin/gerente).
class HorariosAdminScreen extends StatefulWidget {
  const HorariosAdminScreen({super.key, required this.sucursalId});

  final String? sucursalId;

  @override
  State<HorariosAdminScreen> createState() => _HorariosAdminScreenState();
}

class _HorariosAdminScreenState extends State<HorariosAdminScreen> {
  final _repo = SucursalesRepository();
  List<Map<String, dynamic>> _horarios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _formatearHora(dynamic valor) {
    final texto = valor?.toString() ?? '';
    if (texto.length >= 5) return texto.substring(0, 5);
    return texto;
  }

  Future<void> _cargar() async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal asignada';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.listarHorarios(sucursalId);
      if (!mounted) return;
      setState(() {
        _horarios = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar horarios');
      });
    }
  }

  void _avisar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? AnaliticaTokens.alertas : AnaliticaTokens.ink,
      ),
    );
  }

  TimeOfDay _parseHora(dynamic valor) {
    final texto = _formatearHora(valor);
    final partes = texto.split(':');
    if (partes.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(partes[0])?.clamp(0, 23) ?? 0,
        minute: int.tryParse(partes[1])?.clamp(0, 59) ?? 0,
      );
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  String _fmtHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Lista cada hora en punto (00:00 … 23:00). Si la actual no cae en la grilla, se incluye.
  List<TimeOfDay> _opcionesHora(TimeOfDay actual) {
    final opciones = <TimeOfDay>[
      for (var h = 0; h < 24; h++) TimeOfDay(hour: h, minute: 0),
    ];
    final enGrilla = opciones.any(
      (t) => t.hour == actual.hour && t.minute == actual.minute,
    );
    if (!enGrilla) {
      opciones.add(actual);
      opciones.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
    }
    return opciones;
  }

  Future<TimeOfDay?> _elegirHora(
    BuildContext ctx,
    TimeOfDay actual,
    String titulo,
  ) {
    return FoodyDialogo.mostrar<TimeOfDay>(
      context: ctx,
      builder: (dialogCtx) => _DialogoListaHoras(
        titulo: titulo,
        actual: actual,
        opciones: _opcionesHora(actual),
        formatear: _fmtHora,
      ),
    );
  }

  Future<void> _editarHorario(Map<String, dynamic> h) async {
    var apertura = _parseHora(h['hora_apertura']);
    var cierre = _parseHora(h['hora_cierre']);

    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> pickApertura() async {
            final t = await _elegirHora(ctx, apertura, 'Apertura');
            if (t != null) setDlg(() => apertura = t);
          }

          Future<void> pickCierre() async {
            final t = await _elegirHora(ctx, cierre, 'Cierre');
            if (t != null) setDlg(() => cierre = t);
          }

          return AlertDialog(
            title: Text(_nombreDia(h['dia_semana'])),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Toca una hora para elegirla de la lista',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AnaliticaTokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _BotonHora(
                    etiqueta: 'Apertura',
                    hora: _fmtHora(apertura),
                    onTap: pickApertura,
                  ),
                  const SizedBox(height: 10),
                  _BotonHora(
                    etiqueta: 'Cierre',
                    hora: _fmtHora(cierre),
                    onTap: pickCierre,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in const [
                        (
                          TimeOfDay(hour: 8, minute: 0),
                          TimeOfDay(hour: 22, minute: 0),
                        ),
                        (
                          TimeOfDay(hour: 10, minute: 0),
                          TimeOfDay(hour: 21, minute: 0),
                        ),
                        (
                          TimeOfDay(hour: 11, minute: 0),
                          TimeOfDay(hour: 23, minute: 0),
                        ),
                      ])
                        ActionChip(
                          label: Text(
                            '${_fmtHora(p.$1)}–${_fmtHora(p.$2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setDlg(() {
                            apertura = p.$1;
                            cierre = p.$2;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      await _repo.actualizarHorario(
        '${h['id']}',
        horaApertura: _fmtHora(apertura),
        horaCierre: _fmtHora(cierre),
      );
      _avisar('Horario actualizado');
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar horario'), error: true);
    }
  }

  String _nombreDia(dynamic dia) {
    final i = dia is int ? dia : int.tryParse('$dia') ?? 0;
    if (i >= 0 && i < _nombresDia.length) return _nombresDia[i];
    return 'Día $i';
  }

  Future<void> _toggleActivo(Map<String, dynamic> h, bool activo) async {
    try {
      await _repo.actualizarHorario('${h['id']}', activo: activo);
      setState(() => h['activo'] = activo);
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'actualizar horario'), error: true);
      await _cargar();
    }
  }

  int get _diasAbiertos =>
      _horarios.where((h) => h['activo'] != false).length;

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 20,
              8,
              compacto ? 12 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin / Sucursal',
                  style: TextStyle(
                    fontSize: 11,
                    color: AnaliticaTokens.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Horarios',
                            style: TextStyle(
                              fontSize: compacto ? 18 : 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: AnaliticaTokens.ink,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _cargando
                                ? 'Cargando…'
                                : '$_diasAbiertos días abiertos · zona America/Bogota',
                            style: const TextStyle(
                              color: AnaliticaTokens.inkMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _cargar,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.refresh,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'El menú y los pedidos del cliente solo están disponibles '
                  'dentro de estos horarios.',
                  style: TextStyle(
                    color: AnaliticaTokens.inkMuted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
        body: _cargando
            ? AnaliticaSkeleton.tab()
            : _error != null
                ? _estadoError()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: AnaliticaTokens.ink,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        compacto ? 12 : 20,
                        4,
                        compacto ? 12 : 20,
                        32,
                      ),
                      children: [
                        _resumenCliente(),
                        const SizedBox(height: 12),
                        ..._horarios.map(_tarjetaDia),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _estadoError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: AnaliticaTokens.alertas,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AnaliticaTokens.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _cargar,
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ink,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resumenCliente() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: AnaliticaTokens.border),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: AnaliticaTokens.inkMuted,
              ),
              SizedBox(width: 6),
              Text(
                'Vista cliente',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AnaliticaTokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _horarios.map((h) {
              final activo = h['activo'] != false;
              final nombre = _nombreDia(h['dia_semana']);
              final corto =
                  nombre.length >= 3 ? nombre.substring(0, 3) : nombre;
              final texto = activo
                  ? '$corto ${_formatearHora(h['hora_apertura'])}–${_formatearHora(h['hora_cierre'])}'
                  : '$corto cerrado';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activo
                      ? AnaliticaTokens.ink.withValues(alpha: 0.06)
                      : AnaliticaTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: activo
                        ? AnaliticaTokens.ink.withValues(alpha: 0.18)
                        : AnaliticaTokens.border,
                  ),
                ),
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: activo
                        ? AnaliticaTokens.ink
                        : AnaliticaTokens.inkSoft,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaDia(Map<String, dynamic> h) {
    final activo = h['activo'] != false;
    final apertura = _formatearHora(h['hora_apertura']);
    final cierre = _formatearHora(h['hora_cierre']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: InkWell(
          onTap: activo ? () => _editarHorario(h) : null,
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
              border: Border.all(color: AnaliticaTokens.border),
              boxShadow: AnaliticaTokens.shadowSoft,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: activo
                          ? AnaliticaTokens.ink.withValues(alpha: 0.06)
                          : AnaliticaTokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activo
                            ? AnaliticaTokens.ink.withValues(alpha: 0.15)
                            : AnaliticaTokens.border,
                      ),
                    ),
                    child: Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: activo
                          ? AnaliticaTokens.ink
                          : AnaliticaTokens.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombreDia(h['dia_semana']),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: activo
                                ? AnaliticaTokens.ink
                                : AnaliticaTokens.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activo ? '$apertura – $cierre' : 'Cerrado este día',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: activo
                                ? AnaliticaTokens.inkMuted
                                : AnaliticaTokens.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activo
                          ? AnaliticaTokens.inventario
                          : AnaliticaTokens.inkSoft,
                    ),
                  ),
                  Switch.adaptive(
                    value: activo,
                    activeTrackColor: AnaliticaTokens.ink,
                    onChanged: (v) => _toggleActivo(h, v),
                  ),
                  IconButton(
                    tooltip: activo ? 'Editar horario' : 'Activa el día primero',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: activo
                          ? AnaliticaTokens.inkMuted
                          : AnaliticaTokens.border,
                    ),
                    onPressed: activo ? () => _editarHorario(h) : null,
                    visualDensity: VisualDensity.compact,
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

class _DialogoListaHoras extends StatefulWidget {
  const _DialogoListaHoras({
    required this.titulo,
    required this.actual,
    required this.opciones,
    required this.formatear,
  });

  final String titulo;
  final TimeOfDay actual;
  final List<TimeOfDay> opciones;
  final String Function(TimeOfDay) formatear;

  @override
  State<_DialogoListaHoras> createState() => _DialogoListaHorasState();
}

class _DialogoListaHorasState extends State<_DialogoListaHoras> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final idx = widget.opciones.indexWhere(
      (t) => t.hour == widget.actual.hour && t.minute == widget.actual.minute,
    );
    _scroll = ScrollController(
      initialScrollOffset: ((idx < 0 ? 0 : idx) * 44.0).clamp(0, 99999),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 280,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Elige una hora de la lista',
              style: TextStyle(
                fontSize: 12.5,
                color: AnaliticaTokens.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AnaliticaTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AnaliticaTokens.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ListView.builder(
                    controller: _scroll,
                    itemExtent: 44,
                    itemCount: widget.opciones.length,
                    itemBuilder: (_, i) {
                      final t = widget.opciones[i];
                      final seleccionado = t.hour == widget.actual.hour &&
                          t.minute == widget.actual.minute;
                      return Material(
                        color: seleccionado
                            ? AnaliticaTokens.ink
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, t),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.formatear(t),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: seleccionado
                                          ? Colors.white
                                          : AnaliticaTokens.ink,
                                    ),
                                  ),
                                ),
                                if (seleccionado)
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _BotonHora extends StatelessWidget {
  const _BotonHora({
    required this.etiqueta,
    required this.hora,
    required this.onTap,
  });

  final String etiqueta;
  final String hora;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AnaliticaTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AnaliticaTokens.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hora,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AnaliticaTokens.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AnaliticaTokens.border),
                ),
                child: const Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: AnaliticaTokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
