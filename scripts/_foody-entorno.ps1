# Carga config/foody-entorno.env → hashtable $FoodyEntorno + URLs derivadas.
# Dot-source:  . (Join-Path $PSScriptRoot '_foody-entorno.ps1')

$ErrorActionPreference = 'Stop'
$raizFoody = Split-Path -Parent $PSScriptRoot
$FoodyEntornoPath = Join-Path $raizFoody 'config\foody-entorno.env'
if (-not (Test-Path $FoodyEntornoPath)) {
  $ex = Join-Path $raizFoody 'config\foody-entorno.env.example'
  if (Test-Path $ex) {
    Copy-Item $ex $FoodyEntornoPath
    Write-Host "Creado config/foody-entorno.env desde example" -ForegroundColor Yellow
  } else {
    throw "Falta config/foody-entorno.env (y .example)"
  }
}

$FoodyEntorno = @{}
Get-Content $FoodyEntornoPath -Encoding UTF8 | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq '' -or $line.StartsWith('#')) { return }
  if ($line -notmatch '=') { return }
  $k, $v = $line -split '=', 2
  $FoodyEntorno[$k.Trim()] = $v.Trim()
}

function Get-FoodyEnv([string]$Key, [string]$Default = '') {
  if ($FoodyEntorno.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($FoodyEntorno[$Key])) {
    return $FoodyEntorno[$Key]
  }
  return $Default
}

function Build-FoodyPublicUrl([string]$HostPart, [string]$Dominio) {
  if ([string]::IsNullOrWhiteSpace($HostPart) -or $HostPart -eq '@') {
    return "https://$Dominio"
  }
  return "https://$HostPart.$Dominio"
}

$script:FoodyDominio = Get-FoodyEnv 'DOMINIO' 'foodyy.store'
$script:FoodyModo = (Get-FoodyEnv 'MODO' 'tunel').ToLowerInvariant()
$script:FoodyUrlApp = Build-FoodyPublicUrl (Get-FoodyEnv 'HOST_APP' '@') $FoodyDominio
$script:FoodyUrlEquipo = Build-FoodyPublicUrl (Get-FoodyEnv 'HOST_EQUIPO' 'equipo') $FoodyDominio
$script:FoodyUrlApi = Build-FoodyPublicUrl (Get-FoodyEnv 'HOST_API' 'api') $FoodyDominio
$script:FoodyUrlSb = Build-FoodyPublicUrl (Get-FoodyEnv 'HOST_SB' 'sb') $FoodyDominio
$script:FoodyPuertoApi = [int](Get-FoodyEnv 'PUERTO_API' '3000')
$script:FoodyPuertoSb = [int](Get-FoodyEnv 'PUERTO_SUPABASE' '8000')
$script:FoodyPuertoEquipo = [int](Get-FoodyEnv 'PUERTO_WEB_EQUIPO' '8080')
$script:FoodyPuertoCliente = [int](Get-FoodyEnv 'PUERTO_WEB_CLIENTE' '8081')
$script:FoodyTunnelNombre = Get-FoodyEnv 'TUNNEL_NOMBRE' 'foody'
$script:FoodyIpLan = Get-FoodyEnv 'IP_LAN' ''
