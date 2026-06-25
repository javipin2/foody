import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/horario.dart';
import '../providers/reserva_recurrente_provider.dart';

/// Indica si el turno (fecha + sede + cancha + hora) ya está ocupado por una
/// reserva puntual confirmada o por una regla recurrente activa para esa fecha.
///
/// [excluirDocumentoReservaId]: al editar, el documento actual de `reservas`.
/// [excluirRecurrenteReglaId]: si la reserva proviene de un fijo, la regla padre
/// para no contar el mismo cupo dos veces.
Future<bool> turnoEstaOcupado({
  required FirebaseFirestore firestore,
  required ReservaRecurrenteProvider recurrenteProvider,
  required DateTime fecha,
  required String sede,
  required String canchaId,
  required String lugarId,
  required String horarioFormateado,
  String? excluirDocumentoReservaId,
  String? excluirRecurrenteReglaId,
}) async {
  final horaN = Horario.normalizarHora(horarioFormateado);
  final fechaStr = DateFormat('yyyy-MM-dd').format(
    DateTime(fecha.year, fecha.month, fecha.day),
  );

  final snap = await firestore
      .collection('reservas')
      .where('fecha', isEqualTo: fechaStr)
      .where('cancha_id', isEqualTo: canchaId)
      .where('lugarId', isEqualTo: lugarId)
      .where('confirmada', isEqualTo: true)
      .get();

  for (final doc in snap.docs) {
    if (doc.id == excluirDocumentoReservaId) continue;
    final d = doc.data();
    if ((d['estado'] as String?) == 'devolucion') continue;
    if ((d['sede'] as String? ?? '') != sede) continue;
    final h = Horario.normalizarHora((d['horario'] as String?) ?? '');
    if (h == horaN) return true;
  }

  final recurrentes = recurrenteProvider.obtenerReservasActivasParaFecha(
    fecha,
    sede: sede,
    canchaId: canchaId,
  );
  for (final rr in recurrentes) {
    if (excluirRecurrenteReglaId != null && rr.id == excluirRecurrenteReglaId) {
      continue;
    }
    if (Horario.normalizarHora(rr.horario) == horaN) return true;
  }

  return false;
}
