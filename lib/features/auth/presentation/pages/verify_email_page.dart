import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla post-registro esperando verificación de email.
///
/// TODO(sprint-1):
///   - Listener al stream auth.onAuthStateChange
///   - CTA "Reenviar email" (sin botón "Ya lo verifiqué" — P0-21)
///   - Transición automática a /onboarding/identity al detectar verificación
class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu email')),
      body: const Center(
        child: Text('Verifica tu email · Por implementar en Sprint 1'),
      ),
    );
  }
}
