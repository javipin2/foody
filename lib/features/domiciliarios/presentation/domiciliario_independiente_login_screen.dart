import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_independientes_repository.dart';

/// Login domiciliario independiente (Sprint 7).
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
      await DomiciliariosIndependientesRepository.login(
        email: _email.text.trim(),
        contrasena: _pass.text,
      );
      if (mounted) context.go('/domiciliario/independiente');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'login'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Domiciliario Foody')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delivery_dining, size: 64, color: ColoresFoody.primario),
                const SizedBox(height: 16),
                const Text(
                  'Repartidor independiente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _cargando ? null : _ingresar,
                    child: _cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ingresar'),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/domiciliario/registro'),
                  child: const Text('Crear cuenta repartidor'),
                ),
                TextButton(
                  onPressed: () => context.go('/admin/login'),
                  child: const Text('Soy staff del restaurante'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
