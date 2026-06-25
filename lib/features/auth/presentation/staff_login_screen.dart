import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_staff_service.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login staff Foody (L01) — UI inspirada en admin_login_screen, datos vía NestJS.
class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _repo = AuthRepository();
  bool _cargando = false;
  bool _procesandoGoogle = false;
  bool _ocultar = true;

  late AnimationController _anim;
  late Animation<double> _fade;
  late AnimationController _shake;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = CurvedAnimation(parent: _shake, curve: Curves.elasticInOut);
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _procesarRetornoGoogle());
  }

  Future<void> _procesarRetornoGoogle() async {
    if (!AppBackend.supabaseReady || _cargando || _procesandoGoogle) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() => _procesandoGoogle = true);
    try {
      await GoogleOAuthStaffService.procesarRetornoEnLogin(context, _repo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'Google')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoGoogle = false);
    }
  }

  Future<void> _googleOAuth() async {
    if (!AppBackend.supabaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google no disponible en este entorno')),
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      await GoogleOAuthStaffService.iniciarOAuth(OAuthDestinoStaff.login);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'Google'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _shake.dispose();
    _email.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formKey.currentState!.validate()) {
      _shake.forward(from: 0).then((_) => _shake.reset());
      return;
    }
    setState(() => _cargando = true);
    try {
      final r = await _repo.login(
        email: _email.text.trim(),
        contrasena: _contrasena.text,
      );
      if (!mounted) return;
      irDashboardStaff(context, r.dashboard);
    } catch (e) {
      if (!mounted) return;
      _shake.forward(from: 0).then((_) => _shake.reset());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorHttp(e, contexto: 'iniciar sesión')),
          backgroundColor: ColoresFoody.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando || _procesandoGoogle;

    return Scaffold(
      backgroundColor: ColoresFoody.fondo,
      appBar: AppBar(
        title: const Text('Acceso staff'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: ocupado ? null : () => context.go('/cliente'),
        ),
      ),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fade,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final offset =
                        _shakeAnim.value * 8 * (_shake.status.isAnimating ? 1 : 0);
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant, size: 56, color: ColoresFoody.primario),
                              const SizedBox(height: 8),
                              Text(
                                'Foody Staff',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (v) =>
                                    v == null || !v.contains('@') ? 'Correo inválido' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _contrasena,
                                obscureText: _ocultar,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _ocultar ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(() => _ocultar = !_ocultar),
                                  ),
                                ),
                                validator: (v) =>
                                    v == null || v.length < 4 ? 'Mínimo 4 caracteres' : null,
                              ),
                              const SizedBox(height: 24),
                              if (AppBackend.supabaseReady) ...[
                                OutlinedButton.icon(
                                  onPressed: ocupado ? null : _googleOAuth,
                                  icon: const Icon(Icons.g_mobiledata, size: 28),
                                  label: const Text('Continuar con Google'),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Divider()),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Text('o'),
                                      ),
                                      Expanded(child: Divider()),
                                    ],
                                  ),
                                ),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: ocupado ? null : _ingresar,
                                  child: _cargando
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Ingresar'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'admin@foody.demo · super@foody.demo · cocina@foody.demo',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Cajero/mesero: créalos en Foody Control → Usuarios',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Contraseña demo: 123456',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'Repartidor: botón abajo → repartidor@foody.demo',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: ocupado ? null : () => context.go('/admin/registro'),
                                child: const Text('Crear restaurante gratis'),
                              ),
                              TextButton(
                                onPressed: ocupado ? null : () => context.go('/domiciliario/login'),
                                child: const Text('Soy repartidor independiente'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_procesandoGoogle)
            const ColoredBox(
              color: Color(0x88FFFFFF),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Conectando con Google...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
