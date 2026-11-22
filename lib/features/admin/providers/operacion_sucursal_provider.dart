import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado operativo compartido (caja + invalidación pedidos/mesas).
/// FL-STATE-01/02: no sustituye repos locales; solo sincroniza hermanos.
class OperacionSucursalState {
  const OperacionSucursalState({
    this.epochPedidos = 0,
    this.cajaAbierta = false,
    this.cajaId,
  });

  /// Incrementa → mesas/kanban recargan.
  final int epochPedidos;
  final bool cajaAbierta;
  final String? cajaId;

  OperacionSucursalState copiarCon({
    int? epochPedidos,
    bool? cajaAbierta,
    String? cajaId,
    bool limpiarCajaId = false,
  }) {
    return OperacionSucursalState(
      epochPedidos: epochPedidos ?? this.epochPedidos,
      cajaAbierta: cajaAbierta ?? this.cajaAbierta,
      cajaId: limpiarCajaId ? null : (cajaId ?? this.cajaId),
    );
  }
}

class OperacionSucursalNotifier extends StateNotifier<OperacionSucursalState> {
  OperacionSucursalNotifier() : super(const OperacionSucursalState());

  void invalidarPedidos() {
    state = state.copiarCon(epochPedidos: state.epochPedidos + 1);
  }

  void publicarCaja(Map<String, dynamic>? caja) {
    if (caja == null) {
      state = state.copiarCon(cajaAbierta: false, limpiarCajaId: true);
      return;
    }
    state = state.copiarCon(
      cajaAbierta: true,
      cajaId: caja['id']?.toString(),
    );
  }
}

final operacionSucursalProvider = StateNotifierProvider<
    OperacionSucursalNotifier, OperacionSucursalState>((ref) {
  return OperacionSucursalNotifier();
});
