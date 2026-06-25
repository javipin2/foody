import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_link_config.dart';
import 'programador_deep_link_service.dart';

class SharedLugarPayload {
  final String lugarId;
  final String? ciudadId;

  const SharedLugarPayload({
    required this.lugarId,
    this.ciudadId,
  });
}

class SharedLugarLinkService {
  static const _pendingLugarIdKey = 'pending_shared_lugar_id';
  static const _pendingCiudadIdKey = 'pending_shared_ciudad_id';
  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _sub;

  static Future<void> initialize() async {
    try {
      // Web: capturar parámetros actuales de la URL.
      if (kIsWeb) {
        _capturePendingFromUri(Uri.base);
        await ProgramadorDeepLinkService.captureFromUri(Uri.base);
        return;
      }

      _appLinks ??= AppLinks();

      final initial = await _appLinks!.getInitialLink();
      if (initial != null) {
        await _capturePendingFromUri(initial);
        await ProgramadorDeepLinkService.captureFromUri(initial);
      }

      _sub?.cancel();
      _sub = _appLinks!.uriLinkStream.listen(
        (uri) async {
          await _capturePendingFromUri(uri);
          await ProgramadorDeepLinkService.captureFromUri(uri);
        },
        onError: (Object e) {
          debugPrint('SharedLugarLinkService uriLinkStream error: $e');
        },
      );
    } catch (e) {
      debugPrint('SharedLugarLinkService initialize error: $e');
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Uri buildShareUri({
    required String lugarId,
    required String ciudadId,
  }) {
    return Uri(
      scheme: AppLinkConfig.shareScheme,
      host: AppLinkConfig.shareHost,
      path: AppLinkConfig.sharePath,
      queryParameters: {
        'lugarId': lugarId,
        'ciudadId': ciudadId,
      },
    );
  }

  static Future<void> _capturePendingFromUri(Uri uri) async {
    final payload = _payloadFromUri(uri);
    if (payload == null) return;
    await savePending(payload);
  }

  static SharedLugarPayload? _payloadFromUri(Uri uri) {
    final qp = _allQueryParams(uri);
    final rawLugarId = (qp['lugarId'] ?? qp['lugar'] ?? '').trim();
    final rawCiudadId = (qp['ciudadId'] ?? qp['ciudad'] ?? '').trim();

    final isLugarPath = uri.pathSegments.contains('lugar');
    final isCustomLugarHost = uri.host.toLowerCase() == AppLinkConfig.customHost;
    if (!isLugarPath && !isCustomLugarHost && rawLugarId.isEmpty) {
      return null;
    }

    if (rawLugarId.isEmpty) return null;
    return SharedLugarPayload(
      lugarId: rawLugarId,
      ciudadId: rawCiudadId.isNotEmpty ? rawCiudadId : null,
    );
  }

  static Map<String, String> _allQueryParams(Uri uri) {
    final merged = <String, String>{}..addAll(uri.queryParameters);

    // Soporte extra para URLs hash de web: /#/ruta?lugarId=...&ciudadId=...
    final fragment = uri.fragment;
    final idx = fragment.indexOf('?');
    if (idx >= 0 && idx < fragment.length - 1) {
      final fragQuery = fragment.substring(idx + 1);
      final fragParams = Uri.splitQueryString(fragQuery);
      merged.addAll(fragParams);
    }
    return merged;
  }

  static Future<void> savePending(SharedLugarPayload payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingLugarIdKey, payload.lugarId);
    if (payload.ciudadId != null && payload.ciudadId!.trim().isNotEmpty) {
      await prefs.setString(_pendingCiudadIdKey, payload.ciudadId!.trim());
    } else {
      await prefs.remove(_pendingCiudadIdKey);
    }
  }

  static Future<SharedLugarPayload?> peekPending() async {
    final prefs = await SharedPreferences.getInstance();
    final lugarId = (prefs.getString(_pendingLugarIdKey) ?? '').trim();
    if (lugarId.isEmpty) return null;
    final ciudadId = (prefs.getString(_pendingCiudadIdKey) ?? '').trim();
    return SharedLugarPayload(
      lugarId: lugarId,
      ciudadId: ciudadId.isNotEmpty ? ciudadId : null,
    );
  }

  static Future<SharedLugarPayload?> consumePending() async {
    final payload = await peekPending();
    if (payload == null) return null;
    await clearPending();
    return payload;
  }

  static Future<SharedLugarPayload?> consumeIfMatchesCity(String ciudadId) async {
    final payload = await peekPending();
    if (payload == null) return null;
    final targetCiudad = payload.ciudadId;
    if (targetCiudad != null && targetCiudad.isNotEmpty && targetCiudad != ciudadId) {
      return null;
    }
    await clearPending();
    return payload;
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingLugarIdKey);
    await prefs.remove(_pendingCiudadIdKey);
  }
}
