import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';

class CarritoState {
  const CarritoState({
    this.sucursalId,
    this.lineas = const {},
  });

  final String? sucursalId;
  final Map<String, LineaCarrito> lineas;

  int get totalItems =>
      lineas.values.fold(0, (sum, l) => sum + l.cantidad);

  double get totalPrecio =>
      lineas.values.fold(0.0, (sum, l) => sum + l.subtotal);

  CarritoState copiarCon({
    String? sucursalId,
    Map<String, LineaCarrito>? lineas,
  }) {
    return CarritoState(
      sucursalId: sucursalId ?? this.sucursalId,
      lineas: lineas ?? this.lineas,
    );
  }
}

class CarritoNotifier extends StateNotifier<CarritoState> {
  CarritoNotifier() : super(const CarritoState());

  void configurarSucursal(String sucursalId) {
    if (state.sucursalId != null && state.sucursalId != sucursalId) {
      state = CarritoState(sucursalId: sucursalId);
    } else {
      state = state.copiarCon(sucursalId: sucursalId);
    }
  }

  void agregarLinea(LineaCarrito linea) {
    final actual = state.lineas[linea.clave];
    final nuevas = Map<String, LineaCarrito>.from(state.lineas);
    if (actual != null) {
      nuevas[linea.clave] = actual.copiarCon(cantidad: actual.cantidad + linea.cantidad);
    } else {
      nuevas[linea.clave] = linea;
    }
    state = state.copiarCon(lineas: nuevas);
  }

  void quitarUno(String clave) {
    final actual = state.lineas[clave];
    if (actual == null) return;
    final nuevas = Map<String, LineaCarrito>.from(state.lineas);
    if (actual.cantidad <= 1) {
      nuevas.remove(clave);
    } else {
      nuevas[clave] = actual.copiarCon(cantidad: actual.cantidad - 1);
    }
    state = state.copiarCon(lineas: nuevas);
  }

  void limpiar() {
    state = CarritoState(sucursalId: state.sucursalId);
  }
}

final carritoProvider =
    StateNotifierProvider<CarritoNotifier, CarritoState>((ref) {
  return CarritoNotifier();
});
