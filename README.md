# PactStream

> La capa de confianza de la construcción europea. App Flutter + Supabase.

[![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-2.0-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/license-Proprietary-black)](LICENSE)

## ¿Qué es esto?

App móvil + web de PactStream — plataforma de gestión de obras de reforma residencial con custodia de pagos en escrow regulado y validación técnica de hitos.

Stack:

- **Frontend**: Flutter 3.27+ (iOS, Android, Web, macOS, Windows, Linux)
- **State management**: Riverpod 2.x
- **Routing**: GoRouter 14.x
- **Backend**: Supabase (Postgres + Auth + Storage + Edge Functions + Realtime)
- **Pagos**: Mangopay (vía Edge Functions)
- **Firma electrónica**: Signaturit (vía Edge Functions)
- **KYC/KYB**: Onfido (SDK móvil + verificación servidor)
- **Notificaciones**: Supabase Realtime + FCM (push) + Resend (email)
- **Errores**: Sentry
- **Analytics**: Posthog

## Estructura del proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── app.dart                     # MaterialApp + theme + router
├── core/                        # Infraestructura transversal
│   ├── theme/                   # Tokens del design system v1.0
│   ├── routing/                 # GoRouter con todas las rutas
│   ├── constants/
│   ├── utils/                   # Formatters (€, fechas, status)
│   └── errors/
├── data/                        # Capa de datos
│   ├── datasources/supabase/    # Cliente + queries
│   ├── repositories/            # Implementación
│   ├── services/                # Wrappers de Onfido/Signaturit/Mangopay
│   └── models/                  # DTOs (auto-generados desde Postgres)
├── domain/                      # Lógica de negocio pura
│   ├── entities/                # User, Pact, Milestone, Dispute
│   └── usecases/
├── features/                    # Una carpeta por área funcional
│   ├── auth/
│   ├── onboarding/
│   ├── dashboard/
│   ├── pact/
│   ├── milestone/
│   ├── dispute/
│   ├── profile/
│   └── notifications/
└── shared/widgets/              # Componentes reusables del DS
```

## Empezar

Lee `docs/SETUP.md` para el primer setup completo (instalar Flutter, crear proyecto Supabase, ejecutar migrations).

Lee `docs/ARCHITECTURE.md` para entender las decisiones arquitecturales.

## Quick start (si ya tienes el entorno listo)

```powershell
# 1. Clonar / abrir el proyecto
cd C:\Users\andre\Documents\Claude\Projects\PactStream\app

# 2. Inicializar Flutter (genera carpetas android/, ios/, etc.)
flutter create --org io.pactstream --project-name pactstream .

# 3. Instalar dependencias
flutter pub get

# 4. Copiar el archivo de entorno y rellenar
copy .env.example .env
# Editar .env con tus credenciales de Supabase

# 5. Ejecutar
flutter run -d chrome     # Web
flutter run               # iOS/Android (con dispositivo conectado)
```

## Convenciones

- Idioma del código: inglés. Idioma del producto: español (es-ES).
- Importes monetarios: BIGINT en céntimos (nunca FLOAT). Ver `core/utils/formatters.dart`.
- Timestamps: TIMESTAMPTZ siempre en UTC. Conversión a zona local solo en presentación.
- Estados: enums con string serializable (alineados con Postgres ENUMs).
- Tests: cobertura mínima 70% en `data/` y `domain/`.

## Estado del proyecto

🚧 **Pre-MVP** — esqueleto inicial. Sprint 1 arranca cuando se incorpore el CTO (Q3 2026).

Roadmap de sprints en `../PactStream_Design_Handoff.docx` §8.

## Documentos relacionados

Toda la documentación estratégica del producto está en el directorio padre `../`:

- `PactStream_Roadmap_MVP.docx` — plan estratégico
- `PactStream_Design_Handoff.docx` — handoff de diseño con 70+ findings
- `PactStream_Plantillas_Legales.docx` — contrato + privacidad + términos
- `PactStream_Schema.sql` — schema completo de Postgres
- `PactStream_Data_Model.docx` — explicación arquitectural del schema
- `PactStream_User_Research_Playbook.docx` — plan de investigación

## Licencia

Proprietary © 2026 PactStream Technologies, S.L. — Todos los derechos reservados.
