# Prompt 34 — Casos extremos de infraestructura (timeout, doble submit, API caida).
# Uso: .\scripts\verificar-infra-extremos.ps1
# Requiere: API viva + seed demo

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\qa-helpers.ps1"

Write-Host '=== Verificar infra extremos (Prompt 34) ===' -ForegroundColor Cyan

$salud = Invoke-RestMethod -Uri "$script:FoodyQaBase/salud" -TimeoutSec 8
if (-not $salud.exito) { throw 'API salud fallo' }
Write-Host 'OK salud' -ForegroundColor Green

$admin = Get-FoodyToken 'admin@foody.demo'
$cajero = Get-FoodyToken 'cajero.test@foody.demo'
$h = $admin.headers
$hc = $cajero.headers
$sid = $script:FoodyQaSucursal
$Producto = 'f0000000-0000-4000-8000-000000000002'
$Precio = 8000
$script:fallos = 0

function Assert-Ok {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) { Write-Host "  OK  $Msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $Msg" -ForegroundColor Red; $script:fallos++ }
}

$null = Limpiar-PedidosActivosDemo -Headers $h
$null = Ensure-CajaAbierta -Headers $hc
$null = Ensure-HorariosDemoAbiertos

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- A) API caida / host muerto (cliente debe fallar rapido) ---' -ForegroundColor Yellow
$sw = [Diagnostics.Stopwatch]::StartNew()
try {
    Invoke-WebRequest -Uri 'http://127.0.0.1:3999/api/v1/salud' -TimeoutSec 3 -UseBasicParsing | Out-Null
    Assert-Ok -Cond $false -Msg 'Host muerto no debio responder'
} catch {
    $sw.Stop()
    Assert-Ok -Cond ($sw.ElapsedMilliseconds -lt 5000) -Msg "Host muerto falla en <5s (got $($sw.ElapsedMilliseconds)ms)"
}

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- B) Doble cobro concurrente (API-IDEM-02 / INFRA-EXT-DBL) ---' -ForegroundColor Yellow
$libres = Get-MesasLibres -Headers $hc
if ($libres.Count -eq 0) {
    $null = Limpiar-PedidosActivosDemo -Headers $h
    $libres = Get-MesasLibres -Headers $hc
}
$Mesa = $libres[0].id
$crear = Invoke-FoodyApi -Method POST -Path '/pedidos/staff' -Headers $hc -Body @{
    sucursal_id = $sid
    mesa_id     = $Mesa
    tipo        = 'mesa'
    device_id   = 'qa-infra-dbl'
    metodo_pago = 'efectivo'
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert-Ok -Cond ($crear.ok -and $crear.json.exito) -Msg 'Crear pedido mesa'
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'listo' }
$null = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$pedidoId/estado?sucursal_id=$sid" -Headers $hc -Body @{ estado = 'pagando' }

# Dos POSTs en paralelo reales (Runspace)
$session = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [RunspaceFactory]::CreateRunspacePool(1, 2, $session, $Host)
$pool.Open()
$uri = "$script:FoodyQaBase/pedidos/$pedidoId/cobrar?sucursal_id=$sid"
$token = ($hc['Authorization'] -replace '^Bearer ', '')
$pipes = @()
for ($i = 0; $i -lt 2; $i++) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript({
        param($U, $Tok)
        try {
            $r = Invoke-WebRequest -Uri $U -Method POST -Headers @{ Authorization = "Bearer $Tok" } `
                -ContentType 'application/json' -Body '{"metodo_pago":"efectivo"}' `
                -TimeoutSec 30 -UseBasicParsing
            return @{ ok = $true; status = [int]$r.StatusCode; body = ($r.Content | ConvertFrom-Json) }
        } catch {
            $st = 0
            $body = $null
            if ($_.Exception.Response) {
                $st = [int]$_.Exception.Response.StatusCode
                try {
                    $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $raw = $reader.ReadToEnd(); $reader.Close()
                    if ($raw) { $body = $raw | ConvertFrom-Json }
                } catch {}
            }
            return @{ ok = $false; status = $st; body = $body; err = $_.Exception.Message }
        }
    }).AddArgument($uri).AddArgument($token)
    $pipes += [pscustomobject]@{ ps = $ps; handle = $ps.BeginInvoke() }
}
$results = foreach ($p in $pipes) {
    $out = $p.ps.EndInvoke($p.handle)
    $p.ps.Dispose()
    $out
}
$pool.Close(); $pool.Dispose()

$okCount = @($results | Where-Object { $_.ok -and $_.body.exito }).Count
$failCount = 2 - $okCount
Assert-Ok -Cond ($okCount -eq 1) -Msg "Exactamente 1 cobro exitoso (got ok=$okCount)"
Assert-Ok -Cond ($failCount -eq 1) -Msg "Segundo cobro rechazado (got fail=$failCount)"
$errCodes = @($results | Where-Object { -not ($_.ok -and $_.body.exito) } | ForEach-Object { $_.body.error })
Write-Host "  NOTE segundo error=$($errCodes -join ',')" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- C) Timeout de lectura: cliente Dio receive=45s (documentado) ---' -ForegroundColor Yellow
# No forzamos hang de Nest; afirmamos constantes en codigo via grep liviano
$cfg = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\core\constantes\configuracion.dart') -Raw
Assert-Ok -Cond ($cfg -match 'timeoutConexion = Duration\(seconds: 15\)') -Msg 'connectTimeout 15s en Configuracion'
Assert-Ok -Cond ($cfg -match 'timeoutRespuesta = Duration\(seconds: 45\)') -Msg 'receiveTimeout 45s en Configuracion'
$msg = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\core\red\mensaje_error_http.dart') -Raw
Assert-Ok -Cond ($msg -match 'connectionTimeout|receiveTimeout|connectionError') -Msg 'mensajeErrorHttp cubre timeouts/conexion'
Assert-Ok -Cond ($msg -match 'Sin conexion con el servidor|No pudimos conectar') -Msg 'Mensaje UX claro offline'

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- D) UI guards (codigo) ---' -ForegroundColor Yellow
$checkout = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\features\pedidos\presentation\checkout_screen.dart') -Raw
Assert-Ok -Cond ($checkout -match '_enviando') -Msg 'Checkout tiene _enviando'
Assert-Ok -Cond ($checkout -match 'idempotencyKey|_idempotencyKey') -Msg 'Checkout envia idempotency_key'
$pos = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\features\pedidos\presentation\pedido_cajero_screen.dart') -Raw
Assert-Ok -Cond ($pos -match '_enviando') -Msg 'POS cajero tiene _enviando'
$mesa = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\features\mesa\presentation\mesa_pedidos_sheet.dart') -Raw
$kanban = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\features\admin\presentation\widgets\pedidos_kanban_widget.dart') -Raw
$kds = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\features\cocinas\presentation\kds_screen.dart') -Raw
if ($mesa -notmatch '_cobrando\s*=') {
    Write-Host '  NOTE INFRA-EXT-UI-01 mesa cobro sin flag _cobrando (solo dialogo)' -ForegroundColor DarkYellow
} else {
    Write-Host '  OK  mesa tiene _cobrando' -ForegroundColor Green
}
if ($kanban -notmatch '_cobrandoPedido|_cobroEnCurso') {
    Write-Host '  NOTE INFRA-EXT-UI-02 kanban _cobrarParaLlevar sin busy flag' -ForegroundColor DarkYellow
} else {
    Write-Host '  OK  kanban cobro con busy' -ForegroundColor Green
}
if ($kds -match '_marcandoTodo' -and $kds -notmatch '_cambiandoItem') {
    Write-Host '  NOTE INFRA-EXT-UI-03 KDS: guard en marcar-todo; item individual sin lock UI' -ForegroundColor DarkYellow
}

Write-Host ''
if ($script:fallos -eq 0) {
    Write-Host 'Infra extremos OK (asserts de hallazgo UI intencionales)' -ForegroundColor Green
    exit 0
}
Write-Host "$script:fallos fallos" -ForegroundColor Red
exit 1
