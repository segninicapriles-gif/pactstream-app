# Setup de PactStream — guía paso a paso

> Tiempo estimado: 60-90 minutos la primera vez. Después, `flutter run` y listo.

Esta guía te lleva de 0 a "app corriendo en mi máquina conectada a una base de datos real". Está pensada para que la siga el CEO/CPO sin necesidad de un dev a su lado, aunque tener un dev cerca acelera el proceso.

## Pre-requisitos

| Herramienta | Versión | Por qué | Cómo instalar |
|---|---|---|---|
| Git | cualquier reciente | Control de versiones | https://git-scm.com/download/win |
| Flutter SDK | 3.27+ | Framework de la app | https://docs.flutter.dev/get-started/install/windows |
| Android Studio | 2024.x+ | Para emulador Android + tooling | https://developer.android.com/studio |
| Visual Studio Code | última | Editor recomendado | https://code.visualstudio.com/ |
| Cuenta Supabase | gratis | Backend | https://supabase.com (signup) |
| Cuenta Sentry | gratis dev | Error monitoring | https://sentry.io |
| Cuenta de Apple Developer | 99 €/año | Para publicar en App Store (Sprint 4+) | https://developer.apple.com |
| Cuenta Google Play Console | 25 € único | Para publicar en Play Store (Sprint 4+) | https://play.google.com/console |

## Parte 1 · Instalar Flutter en Windows

```powershell
# 1. Descargar Flutter SDK desde flutter.dev
#    Recomendado: extraer a C:\flutter

# 2. Añadir flutter\bin al PATH:
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\flutter\bin", [EnvironmentVariableTarget]::User)

# 3. Verificar instalación. Reiniciar PowerShell tras añadir al PATH.
flutter --version

# 4. Aceptar licencias Android y verificar el entorno
flutter doctor --android-licenses
flutter doctor

# Esperado: todos los checks en ✓ excepto opcionales (Xcode si no estás en Mac)
```

Si `flutter doctor` muestra algún ✗, sigue las indicaciones. Lo más común:
- Falta Android Studio + SDKs → instalar Android Studio + abrirlo + SDK Manager → Android 14 (API 34).
- Falta extensión de Flutter en VSCode → instalar "Flutter" + "Dart" desde marketplace.

## Parte 2 · Inicializar el proyecto Flutter

El esqueleto está en `C:\Users\andre\Documents\Claude\Projects\PactStream\app\` pero faltan las carpetas auto-generadas de plataformas (android/, ios/, web/, etc.). Las creamos con un único comando:

```powershell
cd C:\Users\andre\Documents\Claude\Projects\PactStream\app

# Genera carpetas de plataforma sin tocar lib/ (que ya tiene tu código)
flutter create --org io.pactstream --project-name pactstream .

# Instalar dependencias
flutter pub get
```

Si todo va bien, deberías poder ejecutar:

```powershell
flutter run -d chrome
```

…y ver la app en Chrome con la pantalla de splash de PactStream y luego de login.

## Parte 3 · Crear el proyecto Supabase

1. Ve a https://supabase.com/dashboard y haz **"New project"**.
2. Datos:
   - **Name**: `pactstream-dev`
   - **Database password**: genera una y guárdala segura (la necesitas para migrations)
   - **Region**: `eu-west-1` (Irlanda) — más cercana a España
   - **Pricing plan**: Free para empezar; Pro 25 €/mes cuando empiecen pruebas con usuarios reales.
3. Espera 2-3 minutos a que se cree el proyecto.

Cuando esté listo, ve a **Project Settings → API** y copia:
- **Project URL** → será tu `SUPABASE_URL`
- **anon / public key** → será tu `SUPABASE_ANON_KEY`

## Parte 4 · Aplicar el schema a Supabase

El schema completo está en `supabase/migrations/20260429000000_initial_schema.sql`.

### Opción A: Vía dashboard Supabase (más fácil)

1. En el dashboard del proyecto, ve a **SQL Editor** → **New query**.
2. Abre el archivo `supabase/migrations/20260429000000_initial_schema.sql` en VS Code, copia todo su contenido y pégalo en el SQL Editor.
3. Pulsa **Run**. Tarda ~5 segundos. Si hay errores, te avisará en rojo.
4. Verifica yendo a **Table Editor**: deberías ver las 27 tablas creadas (users, organizations, pacts, milestones, etc.).

### Opción B: Vía Supabase CLI (recomendado para producción)

```powershell
# Instalar la CLI (vía Scoop o npm)
npm install -g supabase

# Login
supabase login

# Linkar tu proyecto
supabase link --project-ref <tu-project-ref>

# Aplicar migrations
supabase db push
```

## Parte 5 · Configurar variables de entorno

```powershell
# Copia el ejemplo
copy .env.example .env

# Edita .env con tus datos
notepad .env
```

Rellena al menos:
- `SUPABASE_URL` y `SUPABASE_ANON_KEY` (de la Parte 3)
- `ENVIRONMENT=development`
- `LOG_LEVEL=debug`

Las demás variables (Mangopay, Onfido, Signaturit, FCM) se rellenan según vamos integrando los servicios — ver el roadmap en Design Handoff §8.

## Parte 6 · Configurar Supabase Auth

En el dashboard Supabase:

1. **Authentication → Settings → Email**:
   - Habilita "Confirm email"
   - Configura el SMTP custom (Resend) cuando lo tengas. De momento Supabase envía con su SMTP por defecto.
2. **Authentication → URL Configuration**:
   - Site URL: `http://localhost:3000` (dev)
   - Redirect URLs: añadir `pactstream://callback`, `http://localhost:3000/**`

## Parte 7 · Ejecutar la app

```powershell
# Web (más rápido para iterar)
flutter run -d chrome

# Android (con dispositivo conectado por USB con depuración USB activada)
flutter devices                # ver qué dispositivos detecta
flutter run                    # corre en el primero disponible

# iOS (solo desde Mac)
flutter run -d ios
```

Si todo está bien:
1. Verás el splash de PactStream con el logo.
2. Después de 800ms, redirige a la pantalla de Login.
3. Puedes pulsar "Crear cuenta nueva" — aún muestra placeholder porque la implementación está pendiente del Sprint 1.

## Parte 8 · Crear primer usuario de prueba

Mientras el flujo de registro no esté implementado, puedes crear un usuario manualmente:

```sql
-- En SQL Editor de Supabase
-- 1. Crear usuario en auth.users (vía Supabase auth-helpers o dashboard Authentication > Users > Add user)
-- 2. Insertar fila en tabla public.users:
INSERT INTO public.users (
  auth_provider_id,
  full_name,
  email,
  primary_role,
  country_iso
) VALUES (
  '<UUID del usuario que acabas de crear en auth.users>',
  'Andrés Segnini',
  'andres@pactstream.io',
  'tecnico',
  'ES'
);
```

Ahora con ese email + contraseña puedes hacer login en la app.

## Resolución de problemas frecuentes

### "flutter: command not found"
PATH no actualizado. Reinicia la terminal o el ordenador.

### "No connected devices"
Para Android: activar Modo Desarrollador en el móvil + USB Debugging + drivers OEM.
Para Web: `flutter run -d chrome` debería funcionar siempre.

### "Could not find package 'supabase_flutter'"
`flutter pub get` no se ejecutó. Correr en la raíz del proyecto.

### Error al ejecutar la migration
Lo más común: caracteres mal copiados al pegar en el SQL Editor. Mejor usar la opción B (CLI) o copiar el archivo entero seleccionando con Ctrl+A en VS Code.

### Login devuelve "Invalid login credentials"
- ¿Confirmaste el email del usuario? Mira en `auth.users` → `email_confirmed_at` debe estar relleno.
- ¿La password coincide? Crea un user nuevo desde dashboard Auth > Users.

## Próximos pasos tras el setup

Una vez tengas la app corriendo y conectada a Supabase, sigue el plan de sprints de Design Handoff §8:

- **Sprint 1**: Auth + onboarding + KYC con Onfido
- **Sprint 2**: Pacto + firma con Signaturit
- **Sprint 3**: Pagos + validación de hitos
- **Sprint 4**: Disputas + comunicación + reputación

Cada sprint tiene tareas concretas en `../PactStream_Design_Handoff.docx` y `../PactStream_Data_Model.docx`.

---

¿Algo no funciona? Lee `ARCHITECTURE.md` para entender por qué las cosas están donde están, o revisa los issues en el repo (cuando exista). Si todo lo demás falla, este código fue generado siguiendo convenciones estándar de Flutter — cualquier dev de Flutter puede ayudarte en 30 minutos.
