import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
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
        const SnackBar(content: Text('Completa nombre, email y contraseña (mín. 6)')),
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
        tipoVehiculo: _vehiculo.text.trim().isEmpty ? null : _vehiculo.text.trim(),
        placa: _placa.text.trim().isEmpty ? null : _placa.text.trim(),
      );
      if (!mounted) return;
      context.go('/domiciliario/espera');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'registro'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro repartidor')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.delivery_dining, size: 56, color: ColoresFoody.primario),
                const SizedBox(height: 12),
                Text(
                  'Únete como repartidor independiente',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _ocultar,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vehiculo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de vehículo (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _placa,
                  decoration: const InputDecoration(
                    labelText: 'Placa (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar solicitud'),
                ),
                TextButton(
                  onPressed: () => context.go('/domiciliario/login'),
                  child: const Text('Ya tengo cuenta'),
                ),
              ],
            ),
          ),
        ),
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
      appBar: AppBar(title: const Text('Solicitud enviada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 72, color: ColoresFoody.secundario),
              const SizedBox(height: 20),
              Text(
                'Revisaremos tu cuenta',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Un administrador activará tu perfil. '
                'Cuando esté listo podrás iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => context.go('/domiciliario/login'),
                child: const Text('Ir al login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
