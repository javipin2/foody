import 'dart:html' as html;

/// Escucha clics en notificaciones mostradas por el service worker (segundo plano web).
void escucharClicksFcmWeb(void Function(Map<String, dynamic>) alTocar) {
  html.window.navigator.serviceWorker?.addEventListener('message', (event) {
    final data = (event as html.MessageEvent).data;
    if (data is! Map) return;
    if (data['type'] != 'FCM_NOTIFICATION_CLICK') return;
    final payload = data['data'];
    if (payload is Map) {
      alTocar(Map<String, dynamic>.from(payload));
    }
  });
}
