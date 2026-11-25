/// Validación inmediata de UI; Nest mantiene la regla autoritativa.
String? validarTelefonoCheckout(String? value, {required bool domicilio}) {
  if (!domicilio) return null;
  final telefono = value?.trim() ?? '';
  if (telefono.isEmpty) {
    return 'El teléfono es obligatorio para coordinar la entrega';
  }

  final digitos = telefono.replaceAll(RegExp(r'\D'), '').length;
  if (digitos < 7 || digitos > 15 || !RegExp(r'^\+?[\d\s().-]+$').hasMatch(telefono)) {
    return 'Ingresa un teléfono válido de 7 a 15 dígitos';
  }
  return null;
}
