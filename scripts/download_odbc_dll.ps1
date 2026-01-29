# Baixa odbc_engine.dll diretamente do GitHub Releases (dart_odbc_fast)
# e copia para as pastas do runner e para a raiz do projeto.
# Use quando nao quiser depender do pub cache (ex.: CI, maquina limpa).
#
# Uso: .\scripts\download_odbc_dll.ps1
#       .\scripts\download_odbc_dll.ps1 -Version 0.2.8
# Ou:  pwsh -File scripts\download_odbc_dll.ps1

param(
    [string]$Version = "0.2.8"
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot | Split-Path -Parent
$repo = "cesar-carlos/dart_odbc_fast"
$tag = "v$Version"

Write-Host "Buscando release $tag em https://github.com/$repo ..." -ForegroundColor Cyan

try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$tag" -Method Get
}
catch {
    Write-Host "ERRO: Release $tag nao encontrada ou GitHub inacessivel." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Procurar asset Windows (dll ou zip com a dll)
$dllAsset = $release.assets | Where-Object { $_.name -match 'windows' -and $_.name -match '\.(dll|zip)$' } | Select-Object -First 1
if (-not $dllAsset) {
    $dllAsset = $release.assets | Where-Object { $_.name -match 'odbc_engine.*\.dll$' } | Select-Object -First 1
}
if (-not $dllAsset) {
    Write-Host "ERRO: Nenhum asset Windows (dll/zip) encontrado na release $tag." -ForegroundColor Red
    Write-Host "Assets disponiveis: $($release.assets.name -join ', ')" -ForegroundColor Gray
    exit 1
}

$tempDir = Join-Path $env:TEMP "odbc_fast_dll_$Version"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$downloaded = Join-Path $tempDir $dllAsset.name
Write-Host "Baixando: $($dllAsset.browser_download_url)" -ForegroundColor Gray
Invoke-WebRequest -Uri $dllAsset.browser_download_url -OutFile $downloaded -UseBasicParsing

$dllSource = $null
if ($dllAsset.name -match '\.zip$') {
    $extractDir = Join-Path $tempDir "extract"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    Expand-Archive -Path $downloaded -DestinationPath $extractDir -Force
    $dllSource = Get-ChildItem -Path $extractDir -Recurse -Filter "odbc_engine.dll" | Select-Object -First 1 -ExpandProperty FullName
    if (-not $dllSource) {
        Write-Host "ERRO: odbc_engine.dll nao encontrada dentro do zip." -ForegroundColor Red
        exit 1
    }
}
else {
    $dllSource = $downloaded
    if (-not (Test-Path $dllSource)) {
        Write-Host "ERRO: Download falhou." -ForegroundColor Red
        exit 1
    }
    # Se o asset tiver outro nome (ex: odbc_engine-windows-x64.dll), copiar como odbc_engine.dll
    $renamed = Join-Path $tempDir "odbc_engine.dll"
    if ((Split-Path -Leaf $dllSource) -ne "odbc_engine.dll") {
        Copy-Item -Path $dllSource -Destination $renamed -Force
        $dllSource = $renamed
    }
}

Write-Host "DLL obtida: $dllSource" -ForegroundColor Green
$copied = 0

# 1. Runner Debug e Release
$runnerDebug = Join-Path $projectRoot "build\windows\x64\runner\Debug"
$runnerRelease = Join-Path $projectRoot "build\windows\x64\runner\Release"
foreach ($dest in @($runnerDebug, $runnerRelease)) {
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    Copy-Item -Path $dllSource -Destination (Join-Path $dest "odbc_engine.dll") -Force
    Write-Host "Copiado para: $dest" -ForegroundColor Green
    $copied++
}

# 2. Raiz do projeto (dart test)
$destRoot = Join-Path $projectRoot "odbc_engine.dll"
Copy-Item -Path $dllSource -Destination $destRoot -Force
Write-Host "Copiado para: $destRoot" -ForegroundColor Green
$copied++

Write-Host ""
Write-Host "Concluido. odbc_engine.dll (versao $Version) baixada e copiada em $copied local(is)." -ForegroundColor Cyan
Write-Host "Execute: flutter run -d windows  ou  dart test" -ForegroundColor Gray
