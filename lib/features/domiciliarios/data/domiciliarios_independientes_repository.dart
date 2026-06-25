import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
import 'package:reserva_canchas/core/notificaciones/servicio_fcm_foody.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/auth/domain/login_resultado.dart';

class DomiciliariosIndependientesRepository {
  DomiciliariosIndependientesRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  static Future<void> registrar({
    required String nombre,
    required String email,
    required String contrasena,
    String? telefono,
    String? tipoVehiculo,
    String? placa,
    String? ciudadId,
  }) async {
    final dio = ClienteDio.instancia();
    final respuesta = await dio.post<Map<String, dynamic>>(
      '/auth/registro-domiciliario',
      data: {
        'nombre': nombre,
        'email': email,
        'contrasena': contrasena,
        if (telefono != null) 'telefono': telefono,
        if (tipoVehiculo != null) 'tipo_vehiculo': tipoVehiculo,
        if (placa != null) 'placa': placa,
        if (ciudadId != null) 'ciudad_id': ciudadId,
      },
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito) throw Exception(env.mensaje);
  }

  static Future<LoginResultado> login({
    required String email,
    required String contrasena,
  }) async {
    final dio = ClienteDio.instancia();
    final respuesta = await dio.post<Map<String, dynamic>>(
      '/auth/login-domiciliario',
      data: {'email': email, 'contrasena': contrasena},
    );
    final data = respuesta.data;
    if (data == null) throw Exception('Respuesta vacía');

    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);

    final d = env.datos!;
    final token = d['token'] as String;
    final dashboard = d['dashboard'] as String? ?? 'domiciliario_independiente';
    final rol = d['rol'] as String? ?? 'domiciliario_independiente';
    final permisos = (d['permisos'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final usuario = Map<String, dynamic>.from(
      d['usuario'] as Map<String, dynamic>? ?? {},
    );

    await SesionStaffService.guardar(
      token: token,
      dashboard: dashboard,
      rol: rol,
      permisos: permisos,
      usuario: usuario,
    );

    await ServicioFcmFoody.instancia.registrarTrasLoginStaff();

    return LoginResultado(
      dashboard: dashboard,
      rol: rol,
      permisos: permisos,
      usuario: usuario,
    );
  }

  Future<void> iniciarSesion({
    required double lat,
    required double lng,
    String? ciudadId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliarios/sesion/iniciar',
      data: {
        'lat': lat,
        'lng': lng,
        if (ciudadId != null) 'ciudad_id': ciudadId,
      },
    );
    _validar(r.data);
  }

  Future<List<Map<String, dynamic>>> ofertasActivas() async {
    final r = await _dio.get<Map<String, dynamic>>('/domiciliarios/ofertas-activas');
    return _parsearLista(r.data);
  }

  Future<Map<String, dynamic>> responderOferta(
    String ofertaId,
    String respuesta,
  ) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/domiciliarios/ofertas/$ofertaId/responder',
      data: {'respuesta': respuesta},
    );
    return _parsearMapa(r.data);
  }

  Future<List<Map<String, dynamic>>> pedidosActivos() async {
    final r = await _dio.get<Map<String, dynamic>>('/domiciliarios/pedidos-activos');
    return _parsearLista(r.data);
  }

  Future<void> marcarEnCamino(String pedidoId) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliarios/pedidos/$pedidoId/en-camino',
    );
    _validar(r.data);
  }

  Future<void> confirmarEntrega(String pedidoId) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/domiciliarios/pedidos/$pedidoId/confirmar-entrega',
    );
    _validar(r.data);
  }

  List<Map<String, dynamic>> _parsearLista(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<List<dynamic>>.fromJson(
      data,
      (raw) => raw as List<dynamic>,
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> _parsearMapa(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!env.exito || env.datos == null) throw Exception(env.mensaje);
    return env.datos!;
  }

  void _validar(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final env = RespuestaApi<void>.fromJson(data, (_) {});
    if (!env.exito) throw Exception(env.mensaje);
  }
}
