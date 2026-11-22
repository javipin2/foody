# Foody — QA produccion en lote (P2-12)
# Uso: powershell -File scripts/verificar-produccion-lote.ps1
$ErrorActionPreference = "Continue"
$Base = "http://localhost:3000/api/v1"
$Sucursal = "c0000000-0000-4000-8000-000000000001"
$Pass = "123456"

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
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $body = $reader.ReadToEnd()
            } catch {}
        }
        return @{ ok = $false; status = $status; error = $_.Exception.Message; body = $body }
    }
}

Write-Host ""
Write-Host "=== QA Produccion en lote (P2-12) ==="
Write-Host ""

$login = Invoke-Api -Method POST -Path "/auth/login" -Body @{
    email = "admin@foody.demo"; contrasena = $Pass
}
if (-not ($login.ok -and $login.json.exito)) {
    Write-Host "FALLO: login ($($login.status))"
    exit 1
}
$token = $login.json.datos.token
$h = @{ Authorization = "Bearer $token" }

$ings = Invoke-Api -Path "/inventario/${Sucursal}" -Headers $h
if (-not ($ings.ok -and $ings.json.exito)) {
    Write-Host "FALLO: listar inventario"
    exit 1
}
$listaIng = @($ings.json.datos)
if ($listaIng.Count -lt 1) {
    Write-Host "FALLO: sin ingredientes demo"
    exit 1
}
$ingOk = $listaIng | Where-Object { $_.unidad_base -in @('g','kg','ml','l','und') } | Select-Object -First 1
if (-not $ingOk) { $ingOk = $listaIng[0] }
$ingId = $ingOk.id
$unidadIng = $ingOk.unidad_base
if ($unidadIng -eq 'kg') { $unidadIng = 'g' }
if ($unidadIng -eq 'l') { $unidadIng = 'ml' }

$ts = Get-Date -Format "HHmmss"
$crear = Invoke-Api -Method POST -Path "/costeo/subrecetas" -Headers $h -Body @{
    sucursal_id        = $Sucursal
    nombre             = "QA Lote $ts"
    cantidad_resultado = 1000
    unidad_resultado   = "g"
    margen_error       = 0.05
    usa_produccion_lote = $true
    items              = @(
        @{
            tipo_item      = "ingrediente"
            ingrediente_id = $ingId
            cantidad       = 500
            unidad         = $unidadIng
        }
    )
}
if (-not ($crear.ok -and $crear.json.exito)) {
    Write-Host "FALLO: crear subreceta lote ($($crear.status)) $($crear.body)"
    exit 1
}
$recetaId = $crear.json.datos.receta_id
Write-Host "Subreceta lote: $recetaId"

$prod = Invoke-Api -Method POST -Path "/costeo/producciones" -Headers $h -Body @{
    sucursal_id        = $Sucursal
    receta_id          = $recetaId
    cantidad_producida = 1000
    observaciones      = "QA script"
}
if (-not ($prod.ok -and $prod.json.exito)) {
    Write-Host "FALLO: registrar produccion ($($prod.status)) $($prod.body)"
    exit 1
}
Write-Host "Produccion OK costo_unitario=$($prod.json.datos.costo_unitario) stock_lote=$($prod.json.datos.stock_lote)"

$hist = Invoke-Api -Path "/costeo/producciones/${Sucursal}?receta_id=$recetaId" -Headers $h
if (-not ($hist.ok -and $hist.json.exito -and @($hist.json.datos).Count -ge 1)) {
    Write-Host "FALLO: historial producciones"
    exit 1
}
Write-Host "Historial: $(@($hist.json.datos).Count) registro(s)"

Write-Host ""
Write-Host "OK - produccion en lote verificada"
exit 0
