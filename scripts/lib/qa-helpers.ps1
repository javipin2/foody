# Helpers compartidos para scripts QA Foody (ASCII-only para PowerShell Windows)
$script:FoodyQaBase = 'http://localhost:3000/api/v1'
$script:FoodyQaSucursal = 'c0000000-0000-4000-8000-000000000001'
$script:FoodyQaPass = '123456'

function Invoke-FoodyApi {
    param(
        [string]$Method = 'GET',
        [string]$Path,
        [hashtable]$Headers = @{},
        [object]$Body = $null
    )
    $params = @{
        Uri             = "$script:FoodyQaBase$Path"
        Method          = $Method
        TimeoutSec      = 30
        UseBasicParsing = $true
    }
    if ($Headers.Count) { $params.Headers = $Headers }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json'
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }
    try {
        $r = Invoke-WebRequest @params
        return @{
            ok     = $true
            status = $r.StatusCode
            json   = ($r.Content | ConvertFrom-Json)
        }
    }
    catch {
        $status = 0
        $body = $null
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $raw = $reader.ReadToEnd()
                if ($raw) { $body = $raw | ConvertFrom-Json }
            }
            catch {}
        }
        return @{
            ok     = $false
            status = $status
            json   = $body
            error  = $_.Exception.Message
        }
    }
}

function Get-FoodyToken {
    param([string]$Email)
    $login = Invoke-FoodyApi -Method POST -Path '/auth/login' -Body @{
        email      = $Email
        contrasena = $script:FoodyQaPass
    }
    if (-not ($login.ok -and $login.json.exito)) {
        throw "Login fallo ($Email): $($login.json.mensaje)"
    }
    return @{
        token  = $login.json.datos.token
        headers = @{ Authorization = "Bearer $($login.json.datos.token)" }
    }
}

function Limpiar-PedidosActivosDemo {
    param([hashtable]$Headers)
    $sid = $script:FoodyQaSucursal
    $lista = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid&solo_activos=true" -Headers $Headers
    if (-not ($lista.ok -and $lista.json.exito)) { return 0 }
    $pedidos = @($lista.json.datos)
    $n = 0
    foreach ($p in $pedidos) {
        $id = $p.id
        if (-not $id) { continue }
        $r = Invoke-FoodyApi -Method PATCH -Path "/pedidos/$id/estado?sucursal_id=$sid" -Headers $Headers -Body @{
            estado = 'cancelado'
            motivo = 'QA cleanup demo'
        }
        if ($r.ok -and $r.json.exito) { $n++ }
    }
    if ($n -gt 0) { Start-Sleep -Seconds 1 }
    return $n
}

function Ensure-CajaAbierta {
    param([hashtable]$Headers)
    $sid = $script:FoodyQaSucursal
    $activa = Invoke-FoodyApi -Path "/caja/activa/$sid" -Headers $Headers
    if ($activa.ok -and $activa.json.exito -and $activa.json.datos) {
        return $true
    }
    $abrir = Invoke-FoodyApi -Method POST -Path "/caja/abrir?sucursal_id=$sid" -Headers $Headers -Body @{
        sucursal_id   = $sid
        monto_inicial = 50000
    }
    if ($abrir.ok -and $abrir.json.exito) { return $true }
    if ($abrir.json.error -eq 'CAJA_YA_ABIERTA') { return $true }
    return $false
}

function Get-ProductosMenuFlat {
    param($MenuResponseJson)
    $flat = @()
    foreach ($c in @($MenuResponseJson.datos.categorias)) {
        foreach ($p in @($c.productos)) { $flat += $p }
    }
    return $flat
}

function Restaurar-InventarioDemo {
    param([hashtable]$Headers)
    $stocks = @{
        '40000000-0000-4000-8000-000000000001' = 5000
        '40000000-0000-4000-8000-000000000002' = 200
        '40000000-0000-4000-8000-000000000003' = 10000
    }
    foreach ($ingId in $stocks.Keys) {
        $null = Invoke-FoodyApi -Method PATCH -Path "/inventario/$ingId" -Headers $Headers -Body @{
            stock_nuevo   = [double]$stocks[$ingId]
            motivo_ajuste = 'QA restaurar demo'
        }
    }
    Start-Sleep -Seconds 1
}

function Get-MesasLibres {
    param([hashtable]$Headers)
    $sid = $script:FoodyQaSucursal
    $mesas = Invoke-FoodyApi -Path "/mesas/$sid" -Headers $Headers
    if (-not ($mesas.ok -and $mesas.json.exito)) { return @() }
    return @($mesas.json.datos | Where-Object { -not $_.pedido_id })
}

function Get-ProductoCatalogo {
    param(
        [hashtable]$Headers,
        [string]$ProductoId
    )
    $sid = $script:FoodyQaSucursal
    $lista = Invoke-FoodyApi -Path "/productos/sucursal/$sid" -Headers $Headers
    if (-not ($lista.ok -and $lista.json.exito)) { return $null }
    return @($lista.json.datos | Where-Object { $_.id -eq $ProductoId })[0]
}

function Assert-Qa {
    param([bool]$Cond, [string]$Msg)
    if ($Cond) {
        Write-Host "  OK  $Msg" -ForegroundColor Green
        return $true
    }
    Write-Host "  FALLO  $Msg" -ForegroundColor Red
    return $false
}
