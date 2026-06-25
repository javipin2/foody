# Foody - QA cajero sin asignacion de mesas (post migracion 049)
# Uso: powershell -File scripts/verificar-cajero-mesas.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$MesaLibre = "7170df60-ca76-4049-9248-8c6f1f799a42"
$Producto = "f0000000-0000-4000-8000-000000000002"
$Precio = 8000
$Pass = "123456"
$CajeroEmail = "cajero.test@foody.demo"
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

Write-Host ""
Write-Host "=== QA Cajero sin turno de mesas ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = $CajeroEmail; contrasena = $Pass
}
Assert ($login.ok -and $login.json.exito) "Login $CajeroEmail"
if (-not ($login.ok -and $login.json.exito)) { exit 1 }
$token = $login.json.datos.token
$h = @{ Authorization = "Bearer $token" }

$mesas = Invoke-Api -Path "/mesas/$Sucursal" -Headers $h
$mesasOk = $mesas.ok -and $mesas.json.exito
if (-not $mesasOk) {
    $det = "status=$($mesas.status) exito=$($mesas.json.exito) msg=$($mesas.json.mensaje)"
    Assert $false "GET /mesas como cajero - $det"
} else {
    Assert $true "GET /mesas como cajero (no 403)"
}
$lista = @($mesas.json.datos)
Assert ($lista.Count -gt 0) "Hay mesas en sucursal demo"

$malAsignadas = @($lista | Where-Object { $_.mesera_asignada_id -eq $CajeroId })
Assert ($malAsignadas.Count -eq 0) "Ninguna mesa con mesera_asignada_id = cajero"

$crear = Invoke-Api -Method POST -Path "/pedidos/staff" -Headers $h -Body @{
    sucursal_id = $Sucursal
    mesa_id     = $MesaLibre
    tipo        = "mesa"
    device_id   = "qa-cajero-mesas"
    metodo_pago = "efectivo"
    items       = @(
        @{
            producto_id = $Producto
            cantidad    = 1
            precio      = $Precio
        }
    )
}
Assert ($crear.ok -and $crear.json.exito) "POST /pedidos/staff mesa (status=$($crear.status) err=$($crear.json.error) msg=$($crear.json.message) raw=$($crear.error))"
$pedidoId = $crear.json.datos.id
if (-not $pedidoId) { $pedidoId = $crear.json.datos.pedido_id }

Start-Sleep -Seconds 1
$mesas2 = Invoke-Api -Path "/mesas/$Sucursal" -Headers $h
$mesa = @($mesas2.json.datos | Where-Object { $_.id -eq $MesaLibre })[0]
Assert ($mesa.mesera_asignada_id -ne $CajeroId) "Mesa sin mesera_asignada_id = cajero tras pedido"
Assert ($null -eq $mesa.mesera_asignada_id -or $mesa.mesera_asignada_id -eq "") "Mesa mesera_asignada_id vacia (cajero no toma turno)"

if ($pedidoId) {
    $sql = "SELECT mesera_id FROM pedidos WHERE id = '$pedidoId'"
    $meseraPedido = (docker exec supabase-db psql -U postgres -d postgres -tAc $sql 2>&1).ToString().Trim()
    Assert ([string]::IsNullOrWhiteSpace($meseraPedido)) "pedidos.mesera_id vacio para pedido del cajero"
} else {
    Assert $false "No se pudo verificar mesera_id (pedido no creado)"
}

Write-Host ""
if ($fallos -eq 0) {
    Write-Host "RESULTADO: 0 fallos - QA cajero/mesas OK" -ForegroundColor Green
    exit 0
}
Write-Host "RESULTADO: $fallos fallos" -ForegroundColor Red
exit 1
