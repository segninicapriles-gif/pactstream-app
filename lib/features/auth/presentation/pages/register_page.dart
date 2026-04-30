import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registro en 3 pasos (placeholder).
///
/// TODO(sprint-1): implementar wizard real con:
///   - Paso 1: datos personales (nombre, email, tel, password)
///   - Paso 2: rol + datos profesionales/empresa
///   - Paso 3: aceptación legal + crear cuenta + envío email verificación
///
/// Apoyarse en:
///   - lib/data/datasources/supabase/supabase_client.dart
///   - Tabla legal_consents para registrar aceptaciones (RGPD)
class RegisterPage extends ConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Registro · Por implementar en Sprint 1\n\nVer Design Handoff §3.1 y mockups F-01 a F-02 + capturas Registro - Paso 1, 2, 3.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
