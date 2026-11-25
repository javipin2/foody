# Helpers compartidos para scripts QA Foody (ASCII-only para PowerShell Windows)
# QA vive separada del servicio usado por el Tunnel (:3000).
$script:FoodyQaBase = if ([string]::IsNullOrWhiteSpace($env:FOODY_QA_API_BASE)) {
    'http://127.0.0.1:3001/api/v1'
} else {
    $env:FOODY_QA_API_BASE.TrimEnd('/')
}
$script:FoodyQaDbContainer = if ([string]::IsNullOrWhiteSpace($env:FOODY_QA_DB_CONTAINER)) {
    'foody-diseno-qa-db'
} else {
    $env:FOODY_QA_DB_CONTAINER
}
$script:FoodyQaDatabase = if ([string]::IsNullOrWhiteSpace($env:FOODY_QA_DATABASE)) {
    'foody_diseno_qa'
} else {
    $env:FOODY_QA_DATABASE
}
$script:FoodyQaSucursal = 'c0000000-0000-4000-8000-000000000001'
$script:FoodyQaPass = '123456'

function Assert-FoodyQaDisposable {
    $qaUri = [Uri]$script:FoodyQaBase
    $esApiQa = @('127.0.0.1', 'localhost') -contains $qaUri.Host -and $qaUri.Port -eq 3001
    $esClon = $script:FoodyQaDatabase -match '^foody_diseno_qa_codex_[a-zA-Z0-9_]+$'
    if (-not $esApiQa -or $script:FoodyQaDbContainer -ne 'foody-diseno-qa-db' -or -not $esClon) {
        throw "Escritura QA bloqueada: requiere API localhost:3001, contenedor foody-diseno-qa-db y clon foody_diseno_qa_codex_* (actual: $($script:FoodyQaBase), $($script:FoodyQaDbContainer)/$($script:FoodyQaDatabase))."
    }
    $containerActivo = docker inspect --format '{{.State.Running}}' $script:FoodyQaDbContainer 2>$null
    if ($LASTEXITCODE -ne 0 -or $containerActivo.Trim() -ne 'true') {
        throw "Contenedor QA '$($script:FoodyQaDbContainer)' no está ejecutándose."
    }
    $dbExiste = docker exec $script:FoodyQaDbContainer psql -U postgres -d postgres -Atc `
        "SELECT 1 FROM pg_database WHERE datname='$($script:FoodyQaDatabase)';" 2>$null
    if ($LASTEXITCODE -ne 0 -or $dbExiste.Trim() -ne '1') {
        throw "El clon QA '$($script:FoodyQaDatabase)' no existe en '$($script:FoodyQaDbContainer)'."
    }
}

function Invoke-FoodyApi {
    param(
        [string]$Method = 'GET',
        [string]$Path,
        [hashtable]$Headers = @{},
        [object]$Body = $null
    )
    $metodoNormalizado = $Method.ToUpperInvariant()
    $esLogin = $Path -match '^/auth/login(?:-domiciliario)?(?:\?|$)'
    if ($metodoNormalizado -notin @('GET', 'HEAD', 'OPTIONS') -and -not $esLogin) {
        Assert-FoodyQaDisposable
    }
    $qaUri = [Uri]$script:FoodyQaBase
    $esQaLocal = @('127.0.0.1', 'localhost') -contains $qaUri.Host -and $qaUri.Port -eq 3001
    if (-not $esQaLocal -and $env:FOODY_E2E_ALLOW_NON_QA -ne '1') {
        throw "Destino QA bloqueado ($script:FoodyQaBase). Requiere API local :3001 o FOODY_E2E_ALLOW_NON_QA=1 explícito."
    }
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
                $reader.Close()
                if ($raw) { $body = $raw | ConvertFrom-Json }
            }
            catch {}
        }
        if ($null -eq $body -and $_.ErrorDetails.Message) {
            try { $body = $_.ErrorDetails.Message | ConvertFrom-Json } catch {}
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

function Get-FoodyTokenDomiciliarioIndep {
    param([string]$Email = 'repartidor@foody.demo')
    $login = Invoke-FoodyApi -Method POST -Path '/auth/login-domiciliario' -Body @{
        email      = $Email
        contrasena = $script:FoodyQaPass
    }
    if (-not ($login.ok -and $login.json.exito)) {
        throw "Login indep fallo ($Email): $($login.json.mensaje)"
    }
    return @{
        token   = $login.json.datos.token
        headers = @{ Authorization = "Bearer $($login.json.datos.token)" }
    }
}

function Limpiar-PedidosActivosDemo {
    param([hashtable]$Headers)
    $sid = $script:FoodyQaSucursal
    $lista = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$sid" -Headers $Headers
    if (-not ($lista.ok -and $lista.json.exito)) { return 0 }
    $pedidos = @($lista.json.datos | Where-Object {
            $_.estado -notin @('cancelado', 'rechazado', 'pagado')
        })
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

function Limpiar-AsignacionesDomicilioDemo {
    param([string]$DomiciliarioPlantaId = '92000000-0000-4000-8000-000000000001')
    Assert-FoodyQaDisposable
    $null = docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -c `
        "UPDATE asignaciones_domicilio SET estado = 'cancelado'
         WHERE domiciliario_planta_id = '$DomiciliarioPlantaId'
           AND estado IN ('asignado', 'en_camino');" 2>&1
}

function Ensure-HorariosDemoAbiertos {
  # ponytail: hora_cierre 23:59:00 excluye 23:59:30 — QA nocturno fallaba RESTAURANTE_CERRADO
    Assert-FoodyQaDisposable
    $sid = $script:FoodyQaSucursal
    $null = docker exec $script:FoodyQaDbContainer psql -U postgres -d $script:FoodyQaDatabase -c `
        "UPDATE horarios_sucursal SET hora_apertura='00:00', hora_cierre='23:59:59', activo=true WHERE sucursal_id='$sid';" 2>&1
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

# ponytail: auto-dispatch al listo deja pedido en asignado — no re-asignar manual
function Ensure-AsignacionDomiPlanta {
    param(
        [string]$PedidoId,
        [hashtable]$Headers,
        [string]$SucursalId = $script:FoodyQaSucursal,
        [string]$DomiPlantaId = '92000000-0000-4000-8000-000000000001'
    )
    $lista = Invoke-FoodyApi -Path "/pedidos?sucursal_id=$SucursalId" -Headers $Headers
    $est = ($lista.json.datos | Where-Object { $_.id -eq $PedidoId } | Select-Object -First 1).estado
    if ($est -in @('asignado', 'en_camino')) {
        return @{ ok = $true; auto = $true; estado = $est }
    }
    if ($est -ne 'listo') {
        return @{ ok = $false; mensaje = "estado=$est (esperaba listo o asignado)" }
    }
    $asig = Invoke-FoodyApi -Method POST -Path '/domiciliarios-planta/asignar' -Headers $Headers -Body @{
        pedido_id              = $PedidoId
        sucursal_id            = $SucursalId
        domiciliario_planta_id = $DomiPlantaId
    }
    if ($asig.ok -and $asig.json.exito) {
        return @{ ok = $true; auto = $false; estado = 'asignado' }
    }
    return @{ ok = $false; mensaje = $asig.json.mensaje }
}
