# Foody - QA operacion mesas: cajero (sin turno) + mesero (con turno)
# Uso: powershell -File scripts/verificar-operacion-mesas.ps1
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\lib\qa-helpers.ps1"
Assert-FoodyQaDisposable

& "$PSScriptRoot\verificar-cajero-mesas.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== QA Mesero con turno de mesas ==="
Write-Host ""

$Base = $script:FoodyQaBase
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$MesaMesero = $null
$Producto = "f0000000-0000-4000-8000-000000000002"
$Precio = 8000
$Pass = "123456"
$MeseroEmail = "mesero@foody.com"
$MeseroId = "90000000-0000-4000-8000-000000000003"
$CajeroId = "c622aeff-518d-4453-bfa5-930f70aec41d"

function Invoke-Api {
    param([string]$Method = "GET", [string]$Path, [hashtable]$Headers = @{}, [object]$Body = $null)
    $params = @{
        Uri             = "$Base$Path"
        Method          = $Method
        TimeoutSec      = 25
        UseBasicParsing = $true
    }
    if ($Headers.Count) { $params.Headers = $Headers }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 8 -Compress)
    }
    try {
        $r = Invoke-WebRequest @params
        $json = $r.Content | ConvertFrom-Json
        return @{ ok = $true; status = $r.StatusCode; json = $json }
    }
    catch {
        $status = 0
        $body = $null
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $body = $reader.ReadToEnd() | ConvertFrom-Json
            } catch {}
        }
        return @{ ok = $false; status = $status; json = $body; error = $_.Exception.Message }
    }
}

$fallos = 0
function Assert($cond, $msg) {
    if ($cond) { Write-Host "  OK  $msg" -ForegroundColor Green }
    else { Write-Host "  FALLO  $msg" -ForegroundColor Red; $script:fallos++ }
}

$adminLogin = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
Assert ($adminLogin.ok -and $adminLogin.json.exito) "Login admin para asignar turno"
if (-not ($adminLogin.ok -and $adminLogin.json.exito)) { exit 1 }
$hAdmin = @{ Authorization = "Bearer $($adminLogin.json.datos.token)" }
$mesasAdmin = Invoke-Api -Path "/mesas/$Sucursal" -Headers $hAdmin
$MesaMesero = @($mesasAdmin.json.datos | Where-Object { $_.activa -ne $false -and $_.estado_operativo -eq 'libre' } | Select-Object -First 1).id
Assert ([bool]$MesaMesero) "Hay mesa libre para probar turno de mesero"
if (-not $MesaMesero) { exit 1 }

$turno = Invoke-Api -Method POST -Path "/mesas/asignar-turno" -Headers $hAdmin -Body @{
    sucursal_id = $Sucursal
    asignaciones = @(
        @{ mesa_id = $MesaMesero; mesera_asignada_id = $MeseroId }
    )
}
Assert ($turno.ok -and $turno.json.exito) "POST asignar-turno mesa a mesero"

$meseroLogin = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = $MeseroEmail; contrasena = $Pass
}
Assert ($meseroLogin.ok -and $meseroLogin.json.exito) "Login $MeseroEmail"
if (-not ($meseroLogin.ok -and $meseroLogin.json.exito)) { exit 1 }
$hMesero = @{ Authorization = "Bearer $($meseroLogin.json.datos.token)" }

$mesas = Invoke-Api -Path "/mesas/$Sucursal" -Headers $hMesero
$mesa = @($mesas.json.datos | Where-Object { $_.id -eq $MesaMesero })[0]
Assert ($mesa.mesera_asignada_id -eq $MeseroId) "Mesa asignada al mesero en turno"

$crear = Invoke-Api -Method POST -Path "/pedidos/staff" -Headers $hMesero -Body @{
    sucursal_id = $Sucursal
    mesa_id     = $MesaMesero
    tipo        = "mesa"
    device_id   = "qa-mesero-mesas"
    metodo_pago = "efectivo"
    items       = @(@{ producto_id = $Producto; cantidad = 1; precio = $Precio })
}
Assert ($crear.ok -and $crear.json.exito) "POST pedido staff como mesero (status=$($crear.status) err=$($crear.json.error) msg=$($crear.json.mensaje))"
$pedidoId = $crear.json.datos.pedido_id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.id }

Start-Sleep -Seconds 1
$mesas2 = Invoke-Api -Path "/mesas/$Sucursal" -Headers $hMesero
$mesa2 = @($mesas2.json.datos | Where-Object { $_.id -eq $MesaMesero })[0]
Assert ($mesa2.mesera_asignada_id -eq $MeseroId) "Tras pedido mesero, mesa sigue asignada a el"

if ($pedidoId) {
    $sql = "SELECT mesera_id FROM pedidos WHERE id = '$pedidoId'"
    $meseraPedido = (docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -tAc $sql 2>&1).ToString().Trim()
    Assert ($meseraPedido -eq $MeseroId) "pedidos.mesera_id = mesero tras crear pedido"
}

# Limpiar turno para no bloquear QA siguiente
$null = Invoke-Api -Method POST -Path "/mesas/asignar-turno" -Headers $hAdmin -Body @{
    sucursal_id = $Sucursal
    asignaciones = @(
        @{ mesa_id = $MesaMesero; mesera_asignada_id = $null }
    )
}

Write-Host ""
if ($fallos -eq 0) {
    Write-Host "RESULTADO MESERO: 0 fallos - QA operacion mesas OK" -ForegroundColor Green
    exit 0
}
Write-Host "RESULTADO MESERO: $fallos fallos" -ForegroundColor Red
exit 1
