import 'package:intl/intl.dart';

import '../models/horario.dart';
import '../models/reserva.dart';

/// Clave única de turno (fecha + cancha + hora normalizada). Misma lógica que Registro.
String claveTurnoReserva(Reserva r) {
  final fd = DateFormat('yyyy-MM-dd').format(
    DateTime(r.fecha.year, r.fecha.month, r.fecha.day),
  );
  final h = Horario.normalizarHora(r.horario.horaFormateada);
  return '${fd}_${r.cancha.id}_$h';
}

/// Combina reservas puntuales confirmadas con las generadas desde recurrentes,
/// evitando doble conteo cuando un documento en `reservas` ya cubre el mismo turno
/// que una virtual (misma lógica que [Admin_registro]).
///
/// [clavesPuntualesQueBloqueanRecurrente]: turnos con reserva individual **normal**
/// (no `precio_independiente_de_recurrencia`): no se añade la virtual.
List<Reserva> fusionarYDedupReservasConVirtualesRecurrentes({
  required List<Reserva> reservasPuntuales,
  required Set<String> clavesPuntualesQueBloqueanRecurrente,
  required List<Reserva> virtualesDesdeRecurrentes,
}) {
  final virtualesFiltradas = virtualesDesdeRecurrentes.where((v) {
    final k = claveTurnoReserva(v);
    if (clavesPuntualesQueBloqueanRecurrente.contains(k)) {
      return false;
    }
    return true;
  }).toList();

  final todas = <Reserva>[...reservasPuntuales, ...virtualesFiltradas];
  final map = <String, Reserva>{};
  for (final r in todas) {
    final k = claveTurnoReserva(r);
    if (!map.containsKey(k)) {
      map[k] = r;
    } else {
      final ex = map[k]!;
      if (ex.esReservaRecurrente && !r.esReservaRecurrente) {
        map[k] = r;
      }
    }
  }
  return map.values.toList();
}
