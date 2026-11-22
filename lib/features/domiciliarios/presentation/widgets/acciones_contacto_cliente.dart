import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Normaliza teléfono CO a dígitos (wa.me / tel).
String normalizarTelefonoDigitos(String raw) {
  final solo = raw.replaceAll(RegExp(r'[^\d+]'), '');
  var d = solo.replaceAll('+', '');
  if (d.startsWith('57') && d.length >= 12) return d;
  if (d.length == 10) return '57$d';
  return d;
}

/// Sheet: llamar, WhatsApp, copiar, agregar contacto.
Future<void> mostrarAccionesContactoCliente(
  BuildContext context, {
  required String telefono,
  String? nombre,
}) async {
  final limpio = telefono.trim();
  if (limpio.isEmpty) return;
  final digitos = normalizarTelefonoDigitos(limpio);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  nombre?.trim().isNotEmpty == true
                      ? 'Contactar a ${nombre!.trim()}'
                      : 'Contactar cliente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Llamar'),
                subtitle: Text(limpio),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _lanzarTel(context, limpio);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('WhatsApp · mensaje'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _lanzarUri(
                    context,
                    Uri.parse('https://wa.me/$digitos'),
                    fallback: limpio,
                    okMsg: 'Número copiado (abre WhatsApp en el móvil)',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_in_talk_outlined),
                title: const Text('WhatsApp · llamada'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Intent de llamada WA; si falla, abre chat.
                  final ok = await _lanzarUri(
                    context,
                    Uri.parse('whatsapp://call?phone=$digitos'),
                    silent: true,
                  );
                  if (!ok && context.mounted) {
                    await _lanzarUri(
                      context,
                      Uri.parse('https://wa.me/$digitos'),
                      fallback: limpio,
                      okMsg: 'Número copiado',
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copiar número'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: limpio));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Teléfono copiado')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('Agregar contacto'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final label = nombre?.trim() ?? 'Cliente';
                  if (kIsWeb) {
                    await Clipboard.setData(
                      ClipboardData(text: '$label · $limpio'),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Datos copiados para agregar contacto'),
                        ),
                      );
                    }
                    return;
                  }
                  // ponytail: sin plugin contacts; tel + snackbar guía al usuario.
                  await launchUrl(Uri(scheme: 'tel', path: limpio));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Guarda el contacto desde la app Teléfono ($limpio)',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _lanzarTel(BuildContext context, String telefono) async {
  final uri = Uri(scheme: 'tel', path: telefono);
  if (!kIsWeb && await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return;
  }
  await Clipboard.setData(ClipboardData(text: telefono));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? 'Teléfono copiado (en web no se puede llamar)'
              : 'Teléfono copiado',
        ),
      ),
    );
  }
}

Future<bool> _lanzarUri(
  BuildContext context,
  Uri uri, {
  String? fallback,
  String? okMsg,
  bool silent = false,
}) async {
  try {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  if (silent) return false;
  if (fallback != null) {
    await Clipboard.setData(ClipboardData(text: fallback));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(okMsg ?? 'Copiado')),
      );
    }
  }
  return false;
}
