# Verifica columnas/tablas criticas de migraciones recientes (055, 064, 066, 067).
# Uso: .\scripts\verificar-migraciones-prod.ps1

$ErrorActionPreference = 'Stop'
$Contenedor = 'supabase-db'
$Db = 'postgres'
$Usuario = 'postgres'

function Invoke-PsqlScalar {
    param([string]$Sql)
    docker exec $Contenedor psql -U $Usuario -d $Db -tAc $Sql 2>$null
}

Write-Host '=== Verificar schema migraciones criticas ===' -ForegroundColor Cyan

$running = docker ps --filter "name=$Contenedor" --format '{{.Names}}' 2>$null
if ($running -ne $Contenedor) {
    throw "Contenedor $Contenedor no esta corriendo (docker compose -f docker-compose.dev.yml up -d)"
}

$checks = @(
    @{
        Nombre = '055 asignaciones_domicilio estado cancelado'
        Sql    = "SELECT COUNT(*) FROM pg_constraint WHERE conname = 'asignaciones_domicilio_estado_check'"
        Esperado = '1'
    }
    @{
        Nombre = '066 domicilio_fuera_caja en sucursales'
        Sql    = "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'sucursales' AND column_name = 'domicilio_ingresa_a_caja'"
        Esperado = '1'
    }
    @{
        Nombre = '067 pedidos.seguimiento_token'
        Sql    = "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'pedidos' AND column_name = 'seguimiento_token'"
        Esperado = '1'
    }
    @{
        Nombre = '065 fiado domiciliario config'
        Sql    = "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'sucursales' AND column_name = 'permite_fiado_domiciliario'"
        Esperado = '1'
    }
    @{
        Nombre = '062 segunda sede demo'
        Sql    = "SELECT COUNT(*) FROM sucursales WHERE id = 'c0000000-0000-4000-8000-000000000002'"
        Esperado = '1'
    }
)

$fallos = 0
foreach ($c in $checks) {
    $got = (Invoke-PsqlScalar $c.Sql).Trim()
    if ($got -eq $c.Esperado) {
        Write-Host "OK  $($c.Nombre)" -ForegroundColor Green
    }
    else {
        Write-Host "FAIL $($c.Nombre) (got=$got esperado=$($c.Esperado))" -ForegroundColor Red
        $fallos++
    }
}

# 064 RLS: tablas criticas con FORCE (deny-all sin politicas)
$rls = (Invoke-PsqlScalar "SELECT (relrowsecurity AND relforcerowsecurity)::int FROM pg_class WHERE relname = 'pagos_pedido'").Trim()
if ($rls -eq '1') {
    Write-Host 'OK  064 RLS FORCE en pagos_pedido' -ForegroundColor Green
}
else {
    Write-Host 'FAIL 064 RLS FORCE en pagos_pedido' -ForegroundColor Red
    $fallos++
}

if ($fallos -gt 0) {
    Write-Host "Schema: $fallos fallo(s)" -ForegroundColor Red
    exit 1
}
Write-Host 'Schema migraciones: OK' -ForegroundColor Green
