import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auth/presentation/widgets/auth_form_estilo.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_independientes_repository.dart';

/// Login domiciliario independiente — shell Analítica; API intacta.
class DomiciliarioIndependienteLoginScreen extends StatefulWidget {
  const DomiciliarioIndependienteLoginScreen({super.key});

  @override
  State<DomiciliarioIndependienteLoginScreen> createState() =>
      _DomiciliarioIndependienteLoginScreenState();
}

class _DomiciliarioIndependienteLoginScreenState
    extends State<DomiciliarioIndependienteLoginScreen> {
  final _email = TextEditingController(text: 'repartidor@foody.demo');
  final _pass = TextEditingController(text: '123456');
  bool _cargando = false;
  bool _ocultar = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    setState(() => _cargando = true);
    try {
      final resultado = await DomiciliariosIndependientesRepository.login(
        email: _email.text.trim(),
        contrasena: _pass.text,
      );
      if (!mounted) return;
      if (resultado.estadoCuenta == 'pendiente_verificacion') {
        context.go('/domiciliario/documentos');
      } else {
        context.go('/domiciliario/independiente');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'login')),
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.surface,
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                    border: Border.all(color: AnaliticaTokens.border),
                    boxShadow: AnaliticaTokens.shadowLift,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 16),
                      const Text(
                        'Foody',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AnaliticaTokens.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Repartidor independiente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AnaliticaTokens.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
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
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 46,
                        child: FilledButton(
                          onPressed: _cargando ? null : _ingresar,
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Ingresar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/domiciliario/registro'),
                        style: TextButton.styleFrom(
                          foregroundColor: AnaliticaTokens.ink,
                        ),
                        child: const Text(
                          'Crear cuenta repartidor',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/admin/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: AnaliticaTokens.inkMuted,
                        ),
                        child: const Text('Soy staff del restaurante'),
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
