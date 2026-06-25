import 'dart:html' as html;

void mostrarNotificacionNavegador({
  required String titulo,
  required String cuerpo,
  Map<String, dynamic>? data,
  void Function(Map<String, dynamic>)? alTocar,
}) {
  if (html.Notification.permission != 'granted') return;
  final n = html.Notification(
    titulo,
    body: cuerpo,
    icon: '/icons/Icon-192.png',
  );
  if (alTocar != null && data != null) {
    n.onClick.listen((_) {
      alTocar(data);
      n.close();
    });
  }
}
