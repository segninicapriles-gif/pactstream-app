import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

/// Acceso corto a las cadenas localizadas: `context.l10n.loginTitle`.
///
/// Existe para que migrar una pantalla sea sustituir `'Iniciar sesión'` por
/// `context.l10n.loginTitle` — una edición local, sin tener que importar
/// `AppLocalizations` ni escribir `AppLocalizations.of(context)!` en cada línea.
///
/// El getter no es nulable (`nullable-getter: false` en `l10n.yaml`), así que si
/// alguien lo usa fuera del subárbol de `MaterialApp` el fallo es un error de
/// arranque claro y no un `null` que se propaga hasta la UI.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
