import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Home shell con bottom navigation a 4 tabs (P0-11 del design handoff).
///
/// El contenido del tab Inicio cambia por rol del usuario:
///   - Promotor: hero "En custodia" + tareas urgentes + obras activas
///   - Técnico: hero "Cola de validación" + KPIs
///   - Constructor: hero "Pendiente cobro" + hitos por subir
///
/// TODO(sprint-1): implementar dashboard por rol con datos reales.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.home_outlined, label: 'Inicio'),
    (icon: Icons.folder_outlined, label: 'Obras'),
    (icon: Icons.chat_outlined, label: 'Mensajes'),
    (icon: Icons.person_outline, label: 'Perfil'),
  ];

  Future<void> _signOut() async {
    await SupabaseConfig.client.auth.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PactStream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO(sprint-2): navegar a /notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 80, color: AppColors.psBlue),
              const SizedBox(height: 24),
              Text('Bienvenido a PactStream',
                  style: AppTypography.h2, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Tab actual: ${_tabs[_selectedIndex].label}',
                style: AppTypography.bodyS
                    .copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: 32),
              const Text(
                'Esto es el esqueleto inicial. Las pantallas reales se construyen en Sprint 1 según el plan del Design Handoff §8.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: _tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}
