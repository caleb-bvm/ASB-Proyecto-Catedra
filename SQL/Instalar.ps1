param([string]$Servidor = '.\SQLEXPRESS')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  foreach ($archivo in @('01_base_y_tablas.sql','02_vistas_y_trigger.sql','03_datos.sql')) {
    & sqlcmd -S $Servidor -E -C -b -f 65001 -i $archivo
    if ($LASTEXITCODE -ne 0) { throw "Se detuvo la instalación en $archivo. Revise el mensaje anterior." }
  }
  Write-Host 'Instalación completada. Base: FonaVitSV_Fase2'
} finally { Pop-Location }
