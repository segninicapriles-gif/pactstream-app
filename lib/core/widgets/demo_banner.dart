import 'package:flutter/material.dart';

import '../../data/datasources/supabase/supabase_client.dart';

/// Cinta «DEMO · datos simulados» para las cuentas de demostración.
///
/// Las cuentas demo del seed (`demo.constructora@pactstream.app`, etc.) usan
/// el dominio `pactstream.app`; cualquier otra cuenta no ve nada. Se monta
/// desde el `builder` de MaterialApp.router y reserva su propia franja
/// superior: el contenido recibe el padding de la barra de estado ya
/// consumido, así que ninguna pantalla se solapa con la cinta.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.child});

  final Widget child;

  static const _demoDomain = '@pactstream.app';

  // Antes de inicializar Supabase (tests, arranque) no hay sesión: sin cinta.
  static String? _currentEmail() {
    try {
      return SupabaseConfig.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  static Stream<Object?> _authStream() {
    try {
      return SupabaseConfig.authStream;
    } catch (_) {
      return const Stream<Object?>.empty();
    }
  }

  static bool _isDemo(String? email) =>
      email != null && email.toLowerCase().endsWith(_demoDomain);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authStream(),
      builder: (context, _) {
        if (!_isDemo(_currentEmail())) return child;

        final isEn = Localizations.localeOf(context).languageCode == 'en';
        final top = MediaQuery.paddingOf(context).top;
        return Column(
          children: [
            Material(
              color: const Color(0xFFB45309),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: top, bottom: 3),
                alignment: Alignment.center,
                child: Text(
                  isEn ? 'DEMO · simulated data' : 'DEMO · datos simulados',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
