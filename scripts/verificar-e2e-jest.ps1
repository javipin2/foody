# Prompt 33 — Suite E2E Jest/Supertest (5 flujos + casos limite 28-30)
# Uso: .\scripts\verificar-e2e-jest.ps1
# Requiere: API QA viva en :3001 + clon `foody_diseno_qa_codex_*` en `foody-diseno-qa-db`.
# Seleccionar el clon con FOODY_QA_DATABASE; el script reconstruye grants y prepara
# `cajero.sololectura.test@foody.demo` solo dentro de esa base antes de ejecutar Jest.

param(
    [string]$ApiHost
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$backend = Join-Path $raiz 'foody_backend'

if ([string]::IsNullOrWhiteSpace($ApiHost)) {
    $ApiHost = if ([string]::IsNullOrWhiteSpace($env:E2E_HOST)) {
        'http://127.0.0.1:3001'
    } else {
        $env:E2E_HOST.TrimEnd('/')
    }
}
$ApiHost = $ApiHost.TrimEnd('/')
$uriHost = [Uri]$ApiHost
$esQaLocal = @('127.0.0.1', 'localhost') -contains $uriHost.Host -and $uriHost.Port -eq 3001
if (-not $esQaLocal -and $env:FOODY_E2E_ALLOW_NON_QA -ne '1') {
    Write-Host "BLOQUEADO: E2E apunta a $ApiHost. Usa API QA local :3001; override requiere FOODY_E2E_ALLOW_NON_QA=1." -ForegroundColor Yellow
    exit 2
}
$base = "$ApiHost/api/v1"

function Initialize-FoodyE2eRoleFixtures {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [string]$Container = 'foody-diseno-qa-db'
    )

    if ($Database -notmatch '^foody_diseno_qa_codex_[a-zA-Z0-9_]+$' -or $Container -ne 'foody-diseno-qa-db') {
        throw 'Fixture RBAC solo se prepara en foody_diseno_qa_codex_* dentro de foody-diseno-qa-db.'
    }
    $exists = docker exec $Container psql -U postgres -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='$Database'" 2>$null
    if ($LASTEXITCODE -ne 0 -or $exists.Trim() -ne '1') {
        throw "Clon QA '$Database' no existe; no se prepara fixture."
    }

    # Recompone, de forma idempotente, los grants fuente de todas las migraciones.
    # Así la suite no depende de que el snapshot de demo tenga aplicada la matriz más reciente.
    $roles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $migrations = Join-Path $raiz 'foody_supabase\migrations'
    foreach ($file in Get-ChildItem -LiteralPath $migrations -Filter '*.sql' | Sort-Object Name) {
        $contents = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($insert in [regex]::Matches($contents, '(?is)INSERT\s+INTO\s+roles_permisos\b.*?;')) {
            foreach ($tuple in [regex]::Matches($insert.Value, "\('([a-z_]+)'\s*,\s*'([a-z_]+)'\)")) {
                $roles.Add("$($tuple.Groups[1].Value):$($tuple.Groups[2].Value)") | Out-Null
            }
        }
    }
    if ($roles.Count -lt 40) { throw "Matriz de roles incompleta al leer migraciones ($($roles.Count) grants)." }
    $values = ($roles | Sort-Object | ForEach-Object {
        $parts = $_.Split(':', 2)
        "('$($parts[0])','$($parts[1])')"
    }) -join ",`n"

    $sql = @"
INSERT INTO roles_permisos (rol, permiso) VALUES
$values
ON CONFLICT (rol, permiso) DO NOTHING;

-- Cajero operacional usa la plantilla de rol. La cuenta de solo lectura es distinta.
DELETE FROM usuario_permisos
WHERE usuario_id IN (
  SELECT id FROM usuarios WHERE email IN ('admin@foody.demo', 'cajero.test@foody.demo')
);

INSERT INTO usuarios (
  id, sucursal_id, restaurante_id, nombre, email, rol, activo,
  hash_contrasena, proveedor_auth, email_verificado, token_version
)
SELECT gen_random_uuid(), sucursal_id, restaurante_id, 'QA Caja solo lectura',
       'cajero.sololectura.test@foody.demo', 'cajero', true,
       hash_contrasena, proveedor_auth, email_verificado, token_version
FROM usuarios
WHERE email = 'cajero.test@foody.demo'
ON CONFLICT (email) DO UPDATE SET
  sucursal_id = EXCLUDED.sucursal_id,
  restaurante_id = EXCLUDED.restaurante_id,
  nombre = EXCLUDED.nombre,
  rol = EXCLUDED.rol,
  activo = true,
  hash_contrasena = EXCLUDED.hash_contrasena,
  proveedor_auth = EXCLUDED.proveedor_auth,
  email_verificado = EXCLUDED.email_verificado,
  token_version = EXCLUDED.token_version;

DELETE FROM usuario_permisos
WHERE usuario_id = (SELECT id FROM usuarios WHERE email = 'cajero.sololectura.test@foody.demo');
INSERT INTO usuario_permisos (usuario_id, permiso)
SELECT id, 'ver_caja' FROM usuarios WHERE email = 'cajero.sololectura.test@foody.demo'
ON CONFLICT (usuario_id, permiso) DO NOTHING;
"@
    $sql | docker exec -i $Container psql -U postgres -d $Database -v ON_ERROR_STOP=1 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Falló la preparación de grants y cuenta RBAC del clon QA.' }
    $readonly = docker exec $Container psql -U postgres -d $Database -Atc @"
SELECT count(*) FROM usuario_permisos up
JOIN usuarios u ON u.id = up.usuario_id
WHERE u.email = 'cajero.sololectura.test@foody.demo' AND up.permiso = 'ver_caja';
"@
    if ($LASTEXITCODE -ne 0 -or $readonly.Trim() -ne '1') {
        throw 'La cuenta RBAC read-only no quedó preparada exactamente.'
    }
    Write-Host "OK fixture QA: $($roles.Count) grants migrados + cajero de solo lectura aislado." -ForegroundColor Green
}

Write-Host '=== Foody E2E Jest (flujos criticos) ===' -ForegroundColor Cyan
Write-Host "Destino verificado: $ApiHost" -ForegroundColor DarkGray

try {
    $salud = Invoke-RestMethod -Uri "$base/salud" -TimeoutSec 8
    if (-not $salud.exito) { throw 'salud exito=false' }
    Write-Host 'OK API viva' -ForegroundColor Green
} catch {
    Write-Host "FALLO: API no disponible en $base" -ForegroundColor Red
    exit 1
}

# La suite anterior puede consumir stock demo además de crear pedidos. Para que
# sea repetible, restablecer solo la BD QA aislada antes de ejecutar Jest.
if ($esQaLocal) {
    if ($env:FOODY_QA_DATABASE -notmatch '^foody_diseno_qa_codex_[a-zA-Z0-9_]+$') {
        Write-Host 'BLOQUEADO: el E2E integrado requiere FOODY_QA_DATABASE=foody_diseno_qa_codex_*.' -ForegroundColor Yellow
        exit 2
    }
    $qaBaseAnterior = $env:FOODY_QA_API_BASE
    try {
        $env:FOODY_QA_API_BASE = "$ApiHost/api/v1"
        & "$PSScriptRoot\limpiar-demo-qa.ps1"
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'FALLO: no se pudo preparar la BD QA' -ForegroundColor Red
            exit 1
        }
        $qaContainer = if ([string]::IsNullOrWhiteSpace($env:FOODY_QA_DB_CONTAINER)) {
            'foody-diseno-qa-db'
        } else {
            $env:FOODY_QA_DB_CONTAINER
        }
        Initialize-FoodyE2eRoleFixtures -Database $env:FOODY_QA_DATABASE -Container $qaContainer
    } finally {
        $env:FOODY_QA_API_BASE = $qaBaseAnterior
    }
}

Push-Location $backend
$e2eHostAnterior = $env:E2E_HOST
try {
    $env:E2E_HOST = $ApiHost
    npm run test:e2e -- --runInBand
    $code = $LASTEXITCODE
} finally {
    $env:E2E_HOST = $e2eHostAnterior
    Pop-Location
}

if ($code -eq 0) {
    Write-Host 'E2E Jest OK' -ForegroundColor Green
    exit 0
}
Write-Host "E2E Jest FALLO exit=$code" -ForegroundColor Red
exit $code
