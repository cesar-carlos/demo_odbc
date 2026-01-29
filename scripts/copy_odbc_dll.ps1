# Copia odbc_engine.dll do cache do pub para as pastas do runner (Windows)
# e para a raiz do projeto (para dart test).
# Execute antes de "flutter run" ou "dart test" se a DLL não for encontrada.
#
# Uso: .\scripts\copy_odbc_dll.ps1
# Ou:  pwsh -File scripts\copy_odbc_dll.ps1

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot | Split-Path -Parent
$cacheRoot = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"

# Encontrar pasta do odbc_fast (qualquer versão)
$odbcFastDirs = Get-ChildItem -Path $cacheRoot -Directory -Filter "odbc_fast-*" -ErrorAction SilentlyContinue
if (-not $odbcFastDirs -or $odbcFastDirs.Count -eq 0) {
    Write-Host "ERRO: Pacote odbc_fast nao encontrado em $cacheRoot" -ForegroundColor Red
    Write-Host "Execute: dart pub get" -ForegroundColor Yellow
    exit 1
}

$dllSource = Join-Path $odbcFastDirs[0].FullName "artifacts\windows-x64\odbc_engine.dll"
if (-not (Test-Path $dllSource)) {
    Write-Host "ERRO: DLL nao encontrada em: $dllSource" -ForegroundColor Red
    exit 1
}

$copied = 0

# 1. Runner Debug e Release (Flutter run/build)
$runnerDebug = Join-Path $projectRoot "build\windows\x64\runner\Debug"
$runnerRelease = Join-Path $projectRoot "build\windows\x64\runner\Release"
foreach ($dest in @($runnerDebug, $runnerRelease)) {
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    Copy-Item -Path $dllSource -Destination $dest -Force
    Write-Host "Copiado para: $dest" -ForegroundColor Green
    $copied++
}

# 2. Raiz do projeto (dart test procura no diretório atual)
$destRoot = Join-Path $projectRoot "odbc_engine.dll"
Copy-Item -Path $dllSource -Destination $destRoot -Force
Write-Host "Copiado para: $destRoot" -ForegroundColor Green
$copied++

Write-Host ""
Write-Host "Concluido. odbc_engine.dll copiada em $copied local(is)." -ForegroundColor Cyan
Write-Host "Execute: flutter run -d windows  ou  dart test" -ForegroundColor Gray
