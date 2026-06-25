import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';

const _nombresDia = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

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
        backgroundColor: error ? ColoresFoody.error : ColoresFoody.exito,
      ),
    );
  }

  Future<void> _editarHorario(Map<String, dynamic> h) async {
    final aperturaCtrl = TextEditingController(
      text: _formatearHora(h['hora_apertura']),
    );
    final cierreCtrl = TextEditingController(
      text: _formatearHora(h['hora_cierre']),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_nombreDia(h['dia_semana'])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aperturaCtrl,
              decoration: const InputDecoration(
                labelText: 'Apertura (HH:MM)',
                hintText: '08:00',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cierreCtrl,
              decoration: const InputDecoration(
                labelText: 'Cierre (HH:MM)',
                hintText: '22:00',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) {
      aperturaCtrl.dispose();
      cierreCtrl.dispose();
      return;
    }

    final apertura = aperturaCtrl.text.trim();
    final cierre = cierreCtrl.text.trim();
    aperturaCtrl.dispose();
    cierreCtrl.dispose();

    try {
      await _repo.actualizarHorario(
        '${h['id']}',
        horaApertura: apertura,
        horaCierre: cierre,
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: ColoresFoody.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Horarios de atención',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'El menú y los pedidos del cliente solo están disponibles dentro de estos horarios (zona America/Bogota).',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ..._horarios.map((h) {
            final activo = h['activo'] != false;
            final apertura = _formatearHora(h['hora_apertura']);
            final cierre = _formatearHora(h['hora_cierre']);
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.schedule_outlined,
                  color: activo ? ColoresFoody.primario : Colors.grey,
                ),
                title: Text(_nombreDia(h['dia_semana'])),
                subtitle: Text(
                  activo ? '$apertura – $cierre' : 'Cerrado este día',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: activo,
                      onChanged: (v) => _toggleActivo(h, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: activo ? () => _editarHorario(h) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
