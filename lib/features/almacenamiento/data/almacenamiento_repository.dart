import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/modelos/respuesta_api.dart';
import 'package:reserva_canchas/core/red/cliente_dio.dart';
/// Subida de imágenes vía NestJS → Sharp → Supabase Storage.
class AlmacenamientoRepository {
  AlmacenamientoRepository({Dio? dio})
      : _dio = dio ?? ClienteDio.instancia(conAuthStaff: true);

  final Dio _dio;

  /// Comprime en backend y actualiza `productos.imagen_url`.
  Future<String> subirImagenProducto({
    required String productoId,
    required String sucursalId,
    required List<int> bytes,
    String nombreArchivo = 'foto.jpg',
  }) async {
    final form = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(
        bytes,
        filename: nombreArchivo,
      ),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/almacenamiento/productos/$productoId/imagen',
      data: form,
      queryParameters: {'sucursal_id': sucursalId},
      options: Options(
        // ClienteDio fuerza application/json; multipart necesita boundary automático.
        contentType: 'multipart/form-data',
        headers: {Headers.contentTypeHeader: null},
      ),
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final url = envoltura.datos!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('El servidor no devolvió URL de imagen');
    }
    return url;
  }

  /// Sube imagen genérica (p. ej. antes de crear promoción).
  Future<String> subirImagen({
    required String sucursalId,
    required List<int> bytes,
    required String tipo,
    String? entidadId,
    String nombreArchivo = 'foto.jpg',
  }) async {
    final form = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
    });
    final params = <String, dynamic>{
      'sucursal_id': sucursalId,
      'tipo': tipo,
    };
    if (entidadId != null) params['entidad_id'] = entidadId;

    final r = await _dio.post<Map<String, dynamic>>(
      '/almacenamiento/imagen',
      data: form,
      queryParameters: params,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {Headers.contentTypeHeader: null},
      ),
    );
    return _urlDeRespuesta(r.data);
  }

  /// Video de estado (máx 20 MB / 30 s en cliente).
  Future<String> subirVideo({
    required String sucursalId,
    required List<int> bytes,
    String tipo = 'promocion',
    String nombreArchivo = 'estado.mp4',
  }) async {
    final form = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/almacenamiento/video',
      data: form,
      queryParameters: {
        'sucursal_id': sucursalId,
        'tipo': tipo,
      },
      options: Options(
        contentType: 'multipart/form-data',
        headers: {Headers.contentTypeHeader: null},
      ),
    );
    return _urlDeRespuesta(r.data);
  }

  String _urlDeRespuesta(Map<String, dynamic>? data) {
    if (data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      data,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final url = envoltura.datos!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('El servidor no devolvió URL');
    }
    return url;
  }

  /// Actualiza `promociones.imagen_url` tras subir a Storage.
  Future<String> subirImagenPromocion({
    required String promocionId,
    required String sucursalId,
    required List<int> bytes,
    String nombreArchivo = 'foto.jpg',
  }) async {
    final form = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      '/almacenamiento/promociones/$promocionId/imagen',
      data: form,
      queryParameters: {'sucursal_id': sucursalId},
      options: Options(
        contentType: 'multipart/form-data',
        headers: {Headers.contentTypeHeader: null},
      ),
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final url = envoltura.datos!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('El servidor no devolvió URL de imagen');
    }
    return url;
  }

  Future<String> subirImagenCombo({
    required String comboId,
    required String sucursalId,
    required List<int> bytes,
    String nombreArchivo = 'foto.jpg',
  }) async {
    return _subirEntidad(
      ruta: '/almacenamiento/combos/$comboId/imagen',
      sucursalId: sucursalId,
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
  }

  Future<String> subirImagenCategoria({
    required String categoriaId,
    required String sucursalId,
    required List<int> bytes,
    String nombreArchivo = 'foto.jpg',
  }) async {
    return _subirEntidad(
      ruta: '/almacenamiento/categorias/$categoriaId/imagen',
      sucursalId: sucursalId,
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    );
  }

  Future<String> _subirEntidad({
    required String ruta,
    required String sucursalId,
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final form = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(bytes, filename: nombreArchivo),
    });
    final r = await _dio.post<Map<String, dynamic>>(
      ruta,
      data: form,
      queryParameters: {'sucursal_id': sucursalId},
      options: Options(
        contentType: 'multipart/form-data',
        headers: {Headers.contentTypeHeader: null},
      ),
    );
    if (r.data == null) throw Exception('Respuesta vacía');
    final envoltura = RespuestaApi<Map<String, dynamic>>.fromJson(
      r.data!,
      (raw) => Map<String, dynamic>.from(raw as Map<String, dynamic>),
    );
    if (!envoltura.exito || envoltura.datos == null) {
      throw Exception(envoltura.mensaje);
    }
    final url = envoltura.datos!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('El servidor no devolvió URL de imagen');
    }
    return url;
  }
}
