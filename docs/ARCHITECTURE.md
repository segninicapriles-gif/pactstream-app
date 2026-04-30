# PactStream · Decisiones arquitecturales

> Documento vivo. Cuando cambies una decisión arquitectural importante, anótala aquí con fecha.

## Por qué Flutter + Supabase

Decidimos pivotar de la stack original (FlutterFlow + Firebase per spec MVP v2.1) a Flutter nativo + Supabase tras evaluar:

- **Flutter** vs React Native vs Next.js+Capacitor → Flutter ofrece mejor consistencia cross-platform (iOS+Android+Web+Desktop) con un solo codebase, native performance para cámara/GPS/biometría (críticos para evidencias), y mismo motor que FlutterFlow (transición bidireccional posible).
- **Supabase** vs Firebase → La naturaleza relacional del producto (pacto = transacción financiera + jurídica con foreign keys, transacciones multi-tabla, RLS complejo) encaja mejor con Postgres que con Firestore. Detalle en `../PactStream_Data_Model.docx` §1.

## Patrón de carpetas: Clean Architecture · Feature-first

```
lib/
├── core/         ← infraestructura transversal (theme, routing, errors, utils)
├── data/         ← acceso a datos (Supabase, servicios externos)
├── domain/       ← lógica de negocio pura (entities, usecases)
├── features/     ← una carpeta por área funcional
│   └── <feature>/
│       ├── presentation/
│       │   ├── pages/
│       │   └── widgets/
│       ├── application/   ← Riverpod providers
│       └── data/          ← repositorios específicos del feature
└── shared/       ← componentes reusables del design system
```

**Regla de dependencia**: `core` y `domain` no dependen de nadie. `data` puede usar `domain`. `features` pueden usar `core`, `domain`, `data` y `shared`. Nunca al revés.

## State management: Riverpod 2.x

- Providers anotados con `@riverpod` para code generation.
- `AsyncValue<T>` para todos los estados que vienen del backend.
- Un provider por concepto, no por widget.

## Routing: GoRouter

Todas las rutas en `lib/core/routing/app_router.dart` con constantes en `AppRoutes`.

Patrón de redirección:
- Sin sesión + ruta protegida → `/login`
- Con sesión + KYC pendiente + ruta protegida → `/onboarding/identity`
- Con sesión + KYC ok → home según rol

## Decisiones de datos

### Importes monetarios
**SIEMPRE** en céntimos (BIGINT en Postgres → `int` en Dart). Nunca FLOAT. Conversión a euros solo en presentación (`AppFormatters.moneyShort/moneyLong`).

### Timestamps
**SIEMPRE** TIMESTAMPTZ en UTC en Postgres. Conversión a zona local solo en presentación. Para timestamps forenses (audit log, certificados) usar ISO 8601.

### IDs
UUIDs v4 generados en cliente o servidor. Nunca exponer secuencias autoincrementales (revelan volumen).

## Capa de datos

```
Widget → Provider (Riverpod) → Repository → DataSource → Supabase / API externa
```

- Los **DataSources** son delgados; solo serializan/deserializan.
- Los **Repositories** mapean errores HTTP/SQL a `AppException`s del dominio.
- Las **Entities** del dominio son `freezed` immutables. No conocen Postgres ni JSON.

## Manejo de errores

Toda la app define excepciones tipadas en `lib/core/errors/`:
- `AppException` (base abstracta)
- `NetworkException`
- `AuthException`
- `ValidationException`
- `BusinessRuleException`

Sentry captura las que escapan del UI thread. Las que se muestran al usuario van por SnackBar (errores recuperables) o pantalla dedicada (errores críticos).

## Theming

Tokens del design system v1.0 en `lib/core/theme/`:
- `app_colors.dart` — paleta brand + ink + semánticos
- `app_typography.dart` — Nunito con escala 11-72
- `app_spacing.dart` — sistema de 4 puntos
- `app_radius.dart` — 6 niveles
- `app_shadows.dart` — soft, medium, high, glow

**Regla**: ningún color, fuente, espacio o radio hardcoded fuera de estos archivos. Cualquier excepción es un bug.

## Integraciones externas

Cada servicio externo tiene su wrapper en `lib/data/services/`:
- `OnfidoService` — KYC/KYB
- `SignaturitService` — firma electrónica eIDAS
- `MangopayService` — wrapper para llamar Edge Functions de Supabase
- `NotificationService` — FCM + email transaccional

**Patrón**: nunca llamar a las APIs externas directamente desde el cliente Flutter para escrituras críticas. Pasar siempre por una Edge Function de Supabase que valide + firme la operación.

## Convenciones de código

- **Idioma**: nombres de variables/funciones/clases en inglés. Strings de UI en español (es-ES).
- **Naming**: camelCase para variables, PascalCase para clases, snake_case para constantes top-level.
- **Imports**: agrupados (Dart core, packages externos, archivos del proyecto), ordenados alfabéticamente.
- **Strings**: comilla simple `'hola'` siempre. Doble solo si el string contiene `'`.
- **Trailing comma**: siempre que el formatter ayude a separar líneas.
- **No comments rule**: el código se autoexplica con buenos nombres. Los comentarios son para *por qué*, no *qué*.
- **TODO**: prefijar con sprint correspondiente — `// TODO(sprint-2): ...`.

## Tests

- **Unit**: en `test/unit/` mirroring `lib/`. Cobertura objetivo: >70% en `data/` y `domain/`.
- **Widget**: en `test/widget/`. Para componentes reusables y pantallas críticas.
- **Integration**: en `test/integration_test/`. Smoke tests del happy path.
- **Golden**: en `test/goldens/`. Para componentes visuales del design system.

CI ejecuta todos en cada PR. Las migraciones de Supabase se aplican a una DB de test efímera.

## Internacionalización

MVP es solo es-ES. Estructura preparada para futuro:
- ARB files en `lib/l10n/`
- `flutter gen-l10n` para generar.

V2 añadirá pt-PT (Portugal). V3 catalán.

## Rendimiento

- Limit lazy loading en listas largas (`.builder` constructors siempre).
- Imágenes en CDN con `cached_network_image`.
- Build modes: `--profile` para medir, `--release` para deploy.
- Web: tree-shaking automático en `--release`. Bundle objetivo < 2 MB inicial.

## Seguridad

- **Secrets**: en `.env`, nunca en código. Validar en CI que `.env` no está commiteado (gitignore).
- **JWT**: persistencia en `flutter_secure_storage` (Keychain iOS / EncryptedSharedPreferences Android).
- **Datos sensibles**: DNI/NIE cifrados a nivel de aplicación antes de enviar a Postgres (DD-02 del Data Model doc).
- **Biometría**: opcional, configurable desde perfil.
- **Certificate pinning**: V2, cuando integremos Mangopay y Signaturit en producción.

## Deploy

- **Web**: GitHub Actions → Vercel. URL: `app.pactstream.io`.
- **iOS**: Xcode Cloud o Codemagic. App Store Connect.
- **Android**: GitHub Actions → Play Console (track interno → producción).

CI/CD en Sprint 4. Hasta entonces, deploys manuales.

## Qué no hicimos (intencionalmente)

- **GraphQL**: usaríamos `supabase_flutter` directamente. Cuando el schema crezca > 50 tablas, evaluar GraphQL/Relay.
- **Modular monorepo**: con > 1 app sí (PactStream + admin app), por ahora único proyecto.
- **Custom design system package**: por ahora, los componentes están en `lib/shared/widgets`. Si Tomato u otra empresa del grupo quiere reusar el DS, extraer a paquete propio.
- **Microservicios**: el backend es Supabase. Edge Functions cubren la lógica server-side. Cuando alguna lógica supere 100 LoC en una function, evaluar dedicated backend en Cloud Run.

---

Última actualización: 2026-04-29 — Setup inicial.
