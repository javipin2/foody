import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reserva_canchas/core/dispositivo/dispositivo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'capability de dispositivo es aleatoria, persiste y no reutiliza device id',
      () async {
    SharedPreferences.setMockInitialValues({});

    final deviceId = await DispositivoService.obtenerDeviceId();
    final capability = await DispositivoService.obtenerCapability();
    final capabilityPersistida = await DispositivoService.obtenerCapability();

    expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(capability), isTrue);
    expect(capability, isNot(deviceId));
    expect(capabilityPersistida, capability);
  });

  test('registro envía capability por header y no dentro del body', () async {
    SharedPreferences.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.invalid'));
    RequestOptions? enviada;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          enviada = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              data: {
                'exito': true,
                'datos': {'registrado': true},
              },
            ),
          );
        },
      ),
    );

    await DispositivoService.registrarEnBackend(dio: dio);

    final capability = enviada!.headers['X-Foody-Device-Capability'] as String;
    expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(capability), isTrue);
    expect(enviada!.data, isNot(contains('device_capability')));
    expect(enviada!.data, isNot(contains(capability)));
  });
}
