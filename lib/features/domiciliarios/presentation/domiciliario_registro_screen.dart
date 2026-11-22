import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auth/presentation/widgets/auth_form_estilo.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_independientes_repository.dart';

/// Registro público de domiciliario independiente (estado pendiente_verificacion).
class DomiciliarioRegistroScreen extends StatefulWidget {
  const DomiciliarioRegistroScreen({super.key});

  @override
  State<DomiciliarioRegistroScreen> createState() =>
      _DomiciliarioRegistroScreenState();
}

class _DomiciliarioRegistroScreenState extends State<DomiciliarioRegistroScreen> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _telefono = TextEditingController();
  final _vehiculo = TextEditingController();
  final _placa = TextEditingController();
  bool _cargando = false;
  bool _ocultar = true;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _pass.dispose();
    _telefono.dispose();
    _vehiculo.dispose();
    _placa.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_nombre.text.trim().length < 2 ||
        _email.text.trim().isEmpty ||
        _pass.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa nombre, email y contraseña (mín. 6)'),
        ),
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      await DomiciliariosIndependientesRepository.registrar(
        nombre: _nombre.text.trim(),
        email: _email.text.trim(),
        contrasena: _pass.text,
        telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        tipoVehiculo:
            _vehiculo.text.trim().isEmpty ? null : _vehiculo.text.trim(),
        placa: _placa.text.trim().isEmpty ? null : _placa.text.trim(),
      );
      if (!mounted) return;
      context.go('/domiciliario/documentos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'registro')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const estiloCampo = TextStyle(fontSize: 14, color: AnaliticaTokens.ink);

    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AnaliticaTokens.surface,
                    AnaliticaTokens.canvas,
                    AnaliticaTokens.surfaceMuted.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Volver',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AnaliticaTokens.ink,
                ),
                onPressed: _cargando
                    ? null
                    : () => context.go('/domiciliario/login'),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.surface,
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                    border: Border.all(color: AnaliticaTokens.border),
                    boxShadow: AnaliticaTokens.shadowLift,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AnaliticaTokens.ink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Únete como repartidor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AnaliticaTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cuenta independiente — revisión por admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AnaliticaTokens.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _nombre,
                        style: estiloCampo,
                        decoration: AuthFormEstilo.campo(
                          label: 'Nombre completo',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: estiloCampo,
                        decoration: AuthFormEstilo.campo(
                          label: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: _ocultar,
                        style: estiloCampo,
                        decoration: AuthFormEstilo.campo(
                          label: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _ocultar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AnaliticaTokens.inkSoft,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        style: estiloCampo,
                        decoration: AuthFormEstilo.campo(
                          label: 'Teléfono (opcional)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vehiculo,
                        style: estiloCampo,
                        decoration: AuthFormEstilo.campo(
                          label: 'Tipo de vehículo (opcional)',
                          prefixIcon: const Icon(Icons.two_wheeler_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _placa,
                        style: estiloCampo,
                        decoration: AuthFormEstilo.campo(
                          label: 'Placa (opcional)',
                          prefixIcon: const Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: _cargando ? null : _registrar,
                          style: FilledButton.styleFrom(
                            backgroundColor: AnaliticaTokens.ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AnaliticaTokens.r12,
                              ),
                            ),
                          ),
                          child: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enviar solicitud',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _cargando
                            ? null
                            : () => context.go('/domiciliario/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: AnaliticaTokens.inkMuted,
                        ),
                        child: const Text('Ya tengo cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de espera tras registro (cuenta pendiente de verificación).
class DomiciliarioEsperaScreen extends StatelessWidget {
  const DomiciliarioEsperaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              decoration: BoxDecoration(
                color: AnaliticaTokens.surface,
                borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                border: Border.all(color: AnaliticaTokens.border),
                boxShadow: AnaliticaTokens.shadowSoft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AnaliticaTokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 28,
                      color: AnaliticaTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Revisaremos tu cuenta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AnaliticaTokens.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Un administrador activará tu perfil. '
                    'Cuando esté listo podrás iniciar sesión.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AnaliticaTokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () => context.go('/domiciliario/login'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AnaliticaTokens.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AnaliticaTokens.r12,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Ir al login',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
