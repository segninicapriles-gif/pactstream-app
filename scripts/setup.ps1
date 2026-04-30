# PactStream -- Script de setup automatico para Windows
# Uso: powershell -ExecutionPolicy Bypass -File scripts\setup.ps1

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "PactStream Setup" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar Flutter
Write-Host "1. Verificando Flutter..." -ForegroundColor Yellow
try {
    flutter --version | Out-Null
    Write-Host "   [OK] Flutter instalado" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Flutter no encontrado en el PATH." -ForegroundColor Red
    Write-Host "   Instala Flutter desde https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Red
    exit 1
}

# 2. Verificar git
Write-Host "2. Verificando Git..." -ForegroundColor Yellow
try {
    git --version | Out-Null
    Write-Host "   [OK] Git instalado" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] Git no encontrado. Instala desde https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

# 3. Inicializar proyecto Flutter (si no existe android/)
Write-Host "3. Inicializando proyecto Flutter..." -ForegroundColor Yellow
if (Test-Path "android") {
    Write-Host "   [OK] Proyecto ya inicializado (carpeta android existe)" -ForegroundColor Green
} else {
    Write-Host "   Creando carpetas de plataforma..." -ForegroundColor Yellow
    flutter create --org io.pactstream --project-name pactstream . | Out-Null
    Write-Host "   [OK] Proyecto Flutter inicializado" -ForegroundColor Green
}

# 4. Instalar dependencias
Write-Host "4. Instalando dependencias..." -ForegroundColor Yellow
flutter pub get
Write-Host "   [OK] Dependencias instaladas" -ForegroundColor Green

# 5. Crear .env si no existe
Write-Host "5. Configurando variables de entorno..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "   [OK] .env ya existe" -ForegroundColor Green
} else {
    Copy-Item ".env.example" ".env"
    Write-Host "   [OK] .env creado a partir de .env.example" -ForegroundColor Green
    Write-Host "   [WARN] Edita .env con tus credenciales de Supabase" -ForegroundColor Yellow
}

# 6. Verificar dispositivos disponibles
Write-Host "6. Dispositivos disponibles para desarrollo:" -ForegroundColor Yellow
flutter devices

# 7. Inicializar git si no existe
Write-Host "7. Verificando repositorio Git..." -ForegroundColor Yellow
if (Test-Path ".git") {
    Write-Host "   [OK] Repositorio Git ya inicializado" -ForegroundColor Green
} else {
    git init | Out-Null
    Write-Host "   [OK] Repositorio Git inicializado" -ForegroundColor Green
    Write-Host "   Recuerda: git add . y git commit -m \"Initial commit\" para tu primer commit" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[DONE] Setup completado" -ForegroundColor Green
Write-Host ""
Write-Host "Proximos pasos:" -ForegroundColor Cyan
Write-Host "  1. Edita .env con tus credenciales de Supabase"
Write-Host "  2. Ejecuta el schema en Supabase (ver docs/SETUP.md Parte 4)"
Write-Host "  3. flutter run -d chrome   (para web)"
Write-Host "  4. flutter run             (para movil con dispositivo conectado)"
Write-Host ""
