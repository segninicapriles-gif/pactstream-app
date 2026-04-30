import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla F-01 del design handoff — Bridge pre-Onfido.
///
/// TODO(sprint-2):
///   - Hero icon escudo + check
///   - 3 bullets de beneficios
///   - CTA "Empezar verificación" → lanza Onfido SDK
///   - Secondary "Hacerlo más tarde" → vuelve a home con badge KYC pendiente
class KycIntroPage extends ConsumerWidget {
  const KycIntroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu identidad')),
      body: const Center(
        child: Text('KYC con Onfido · Por implementar en Sprint 2'),
      ),
    );
  }
}
