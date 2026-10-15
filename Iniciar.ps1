param([int]$Puerto = 8765, [switch]$SinAbrir)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
  throw 'Se necesita .NET SDK 10 para iniciar el prototipo.'
}
if ($Puerto -lt 1024 -or $Puerto -gt 65535) { throw 'El puerto debe estar entre 1024 y 65535.' }
$env:FONAVIT_PORT = [string]$Puerto
$proyecto = Join-Path $PSScriptRoot 'Servidor/FonaVitSV.csproj'
$url = "http://127.0.0.1:$Puerto/"
try {
  $salud = Invoke-RestMethod ($url + 'api/health') -TimeoutSec 2
  if (-not $env:FONAVIT_CONNECTION_STRING -and $salud.connected -and $salud.database -eq 'FonaVitSV_Fase2') {
    Write-Host "El prototipo ya esta disponible en $url"
    if (-not $SinAbrir) { Start-Process $url }
    exit 0
  }
} catch { }
& dotnet build $proyecto --nologo
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el servidor. Revisa los mensajes anteriores.' }
# Abre el navegador cuando el servidor ya responde, sin mostrar ventanas auxiliares.
if (-not $SinAbrir) {
  $abrir = Start-Job -ArgumentList $url -ScriptBlock {
    param($direccion)
    for ($intento = 0; $intento -lt 60; $intento++) {
      try {
        $estado = Invoke-RestMethod ($direccion + 'api/health') -TimeoutSec 1
        if ($estado.connected) { Start-Process $direccion; return }
      } catch { }
      Start-Sleep -Milliseconds 250
    }
  }
}
Write-Host "FonaVitSV: $url"
Write-Host 'Deja esta ventana abierta. Usa Ctrl+C para detener el servidor.'
try { & dotnet run --project $proyecto --no-build --no-launch-profile }
finally { if ($abrir) { Stop-Job $abrir; Remove-Job $abrir } }
