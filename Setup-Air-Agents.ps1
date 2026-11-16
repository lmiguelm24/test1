
param(
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "  AIR + OPENCODE MULTI-AGENT SETUP" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

# --------------------------------------------------
# 1. VALIDAR ENTORNO
# --------------------------------------------------

if (-not (Test-Path $ProjectPath)) {
    throw "No existe el proyecto: $ProjectPath"
}

$ProjectPath = (Resolve-Path $ProjectPath).Path

$GitRoot = git -C $ProjectPath rev-parse --show-toplevel 2>$null

if ($LASTEXITCODE -ne 0) {
    throw "La carpeta indicada no pertenece a un repositorio Git."
}

$ProjectPath = (Resolve-Path $GitRoot).Path

Write-Host "[OK] Proyecto: $ProjectPath" -ForegroundColor Green

$OpenCodeCommand = Get-Command opencode -ErrorAction SilentlyContinue

if (-not $OpenCodeCommand) {
    throw "OpenCode no está disponible en el PATH."
}

$OpenCodePath = $OpenCodeCommand.Source

Write-Host "[OK] OpenCode: $OpenCodePath" -ForegroundColor Green

opencode --version

# --------------------------------------------------
# 2. FUNCION PARA GUARDAR ARCHIVOS CON BACKUP
# --------------------------------------------------

function Write-ManagedFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $Directory = Split-Path $Path -Parent

    if (-not (Test-Path $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force |
            Out-Null
    }

    if (Test-Path $Path) {
        $Backup = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        Copy-Item $Path $Backup -Force

        Write-Host "[BACKUP] $Backup" -ForegroundColor Yellow
    }

    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8

    Write-Host "[CREADO] $Path" -ForegroundColor Green
}

# --------------------------------------------------
# 3. CREAR DIRECTORIOS
# --------------------------------------------------

$AgentDirectory = Join-Path $ProjectPath ".opencode\agents"

New-Item -ItemType Directory -Path $AgentDirectory -Force |
    Out-Null

# --------------------------------------------------
# 4. AGENTE COORDINADOR
# --------------------------------------------------

$Coordinator = @'
---
description: Coordinador principal de los tres agentes especializados.
mode: primary
permissions:
  - action: subagent
    resource: "*"
    effect: deny
  - action: subagent
    resource: frontend
    effect: allow
  - action: subagent
    resource: backend
    effect: allow
  - action: subagent
    resource: qa
    effect: allow
---

Eres el coordinador principal del proyecto.

Tu equipo tiene tres subagentes:

1. frontend
2. backend
3. qa

OBJETIVO:

Coordinar el desarrollo completo de las funcionalidades solicitadas.

PROCESO OBLIGATORIO:

1. Analiza la solicitud.
2. Inspecciona la arquitectura existente.
3. Identifica dependencias.
4. Divide el trabajo en tareas independientes.
5. Define los archivos que puede modificar cada agente.
6. Delega frontend y backend en paralelo cuando sea posible.
7. Espera los resultados.
8. Solicita a QA revisar los cambios.
9. Corrige incompatibilidades.
10. Ejecuta validaciones generales.
11. Entrega un informe final.

REGLAS:

- Utiliza la herramienta subagent para delegar.
- Lanza tareas independientes en paralelo.
- Nunca asignes el mismo archivo a dos agentes.
- Define contratos API antes de delegar tareas dependientes.
- Conserva las funcionalidades existentes.
- No inventes requisitos.
- No ejecutes migraciones destructivas.
- No modifiques archivos .env.
- No realices commits ni push sin autorización.
- No integres cambios que no hayan sido revisados.

INFORME FINAL:

- Trabajo de frontend.
- Trabajo de backend.
- Resultado de QA.
- Archivos modificados.
- Pruebas ejecutadas.
- Errores pendientes.
- Estado de integración.
'@

Write-ManagedFile `
    (Join-Path $AgentDirectory "coordinator.md") `
    $Coordinator

# --------------------------------------------------
# 5. AGENTE FRONTEND
# --------------------------------------------------

$Frontend = @'
---
description: Desarrollador especializado en React, Vite, TypeScript y UI.
mode: subagent
---

Eres el especialista frontend.

RESPONSABILIDADES:

- React.
- Vite.
- TypeScript.
- shadcn/ui.
- Tailwind CSS.
- Componentes reutilizables.
- Formularios.
- Validaciones.
- Integración con API.
- Diseño responsive.

REGLAS:

- Respeta la arquitectura existente.
- No modifiques archivos del backend.
- No cambies contratos API sin autorización.
- No elimines funcionalidades.
- No dupliques componentes.
- Conserva los patrones visuales existentes.
- Ejecuta las pruebas frontend disponibles.

Al finalizar informa:

1. Archivos modificados.
2. Componentes creados.
3. Componentes modificados.
4. Dependencias afectadas.
5. Pruebas ejecutadas.
6. Problemas pendientes.
'@

Write-ManagedFile `
    (Join-Path $AgentDirectory "frontend.md") `
    $Frontend

# --------------------------------------------------
# 6. AGENTE BACKEND
# --------------------------------------------------

$Backend = @'
---
description: Desarrollador especializado en Node.js, API y bases de datos.
mode: subagent
---

Eres el especialista backend.

RESPONSABILIDADES:

- Node.js.
- TypeScript.
- API REST.
- Servicios.
- Controladores.
- Base de datos.
- Validaciones.
- Autenticación.
- Autorización.
- Pruebas de integración.

REGLAS:

- Respeta la arquitectura existente.
- No modifiques componentes frontend.
- Conserva la compatibilidad de las API.
- No elimines endpoints existentes sin autorización.
- No ejecutes migraciones destructivas.
- No modifiques datos de producción.
- Documenta cambios en los contratos API.

Al finalizar informa:

1. Archivos modificados.
2. Endpoints afectados.
3. Cambios en base de datos.
4. Dependencias afectadas.
5. Pruebas ejecutadas.
6. Problemas pendientes.
'@

Write-ManagedFile `
    (Join-Path $AgentDirectory "backend.md") `
    $Backend

# --------------------------------------------------
# 7. AGENTE QA
# --------------------------------------------------

$QA = @'
---
description: Auditor de calidad, pruebas y regresiones. No modifica código.
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: ask
---

Eres el auditor de calidad del proyecto.

Tu función es revisar el trabajo de frontend y backend.

RESPONSABILIDADES:

- Revisar cambios.
- Detectar errores.
- Revisar TypeScript.
- Comprobar contratos API.
- Detectar regresiones.
- Revisar validaciones.
- Ejecutar pruebas autorizadas.
- Revisar problemas de seguridad.
- Evaluar consistencia de la arquitectura.

REGLAS:

- No modifiques archivos de producción.
- No realices commits.
- No cambies configuraciones.
- No ejecutes operaciones destructivas.
- Solicita autorización para ejecutar comandos.
- No declares una prueba exitosa sin haberla ejecutado.

INFORME:

Clasifica los hallazgos:

CRÍTICO
ALTO
MEDIO
BAJO

Para cada hallazgo informa:

- Archivo.
- Línea.
- Descripción.
- Cómo reproducirlo.
- Solución recomendada.

Entrega el informe al coordinador.
'@

Write-ManagedFile `
    (Join-Path $AgentDirectory "qa.md") `
    $QA

# --------------------------------------------------
# 8. CONFIGURAR OPENCODE
# --------------------------------------------------

$OpenCodeConfig = Join-Path $ProjectPath "opencode.json"

if (Test-Path $OpenCodeConfig) {

    try {
        $Config = Get-Content $OpenCodeConfig -Raw |
            ConvertFrom-Json
    }
    catch {
        throw "opencode.json no es JSON válido. No se modificó."
    }

}
else {

    $Config = [PSCustomObject]@{
        '$schema' = "https://opencode.ai/config.json"
    }

}

if ($Config.PSObject.Properties["default_agent"]) {
    $Config.default_agent = "coordinator"
}
else {
    $Config | Add-Member `
        -MemberType NoteProperty `
        -Name default_agent `
        -Value "coordinator"
}

$Config |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $OpenCodeConfig -Encoding UTF8

Write-Host "[OK] Coordinador configurado como predeterminado" -ForegroundColor Green

# --------------------------------------------------
# 9. CONFIGURAR AIR ACP
# --------------------------------------------------

$JetBrainsDirectory = Join-Path $env:USERPROFILE ".jetbrains"

New-Item -ItemType Directory `
    -Path $JetBrainsDirectory `
    -Force | Out-Null

$ACPPath = Join-Path $JetBrainsDirectory "acp.json"

if (Test-Path $ACPPath) {

    try {
        $ACP = Get-Content $ACPPath -Raw |
            ConvertFrom-Json
    }
    catch {
        throw "acp.json existente no es válido. No se modificó."
    }

}
else {

    $ACP = [PSCustomObject]@{}

}

if (-not $ACP.PSObject.Properties["agent_servers"]) {

    $ACP | Add-Member `
        -MemberType NoteProperty `
        -Name agent_servers `
        -Value ([PSCustomObject]@{})

}

# OpenCode instalado mediante npm suele usar .cmd.
# Windows ejecuta el lanzador mediante cmd.exe.

if ($OpenCodePath -match '\.(cmd|bat)$') {

    $ACPCommand = "cmd.exe"

    $ACPArguments = @(
        "/d",
        "/c",
        "`"$OpenCodePath`" acp"
    )

}
else {

    $ACPCommand = $OpenCodePath

    $ACPArguments = @("acp")

}

$OpenCodeACP = [PSCustomObject]@{
    command = $ACPCommand
    args = $ACPArguments
    use_idea_mcp = $true
    use_custom_mcp = $true
}

if ($ACP.agent_servers.PSObject.Properties["OpenCode (Copilot)"]) {

    $ACP.agent_servers."OpenCode (Copilot)" = $OpenCodeACP

}
else {

    $ACP.agent_servers |
        Add-Member `
            -MemberType NoteProperty `
            -Name "OpenCode (Copilot)" `
            -Value $OpenCodeACP

}

$ACP |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $ACPPath -Encoding UTF8

Write-Host "[OK] OpenCode registrado en Air" -ForegroundColor Green

# --------------------------------------------------
# 10. CREAR AGENTS.MD SI NO EXISTE
# --------------------------------------------------

$AgentsMD = Join-Path $ProjectPath "AGENTS.md"

if (-not (Test-Path $AgentsMD)) {

    $Instructions = @'
# Project Agent Instructions

## General Rules

- Read the existing architecture before making changes.
- Respect established coding conventions.
- Preserve existing functionality.
- Avoid duplicate implementations.
- Use strict TypeScript where applicable.
- Never modify environment secrets.
- Never execute destructive database operations.
- Never commit or push without authorization.

## Multi-Agent Protocol

- Coordinator owns task distribution and integration.
- Frontend owns frontend implementation.
- Backend owns backend implementation.
- QA owns testing and review.
- Avoid simultaneous edits to the same files.
- Coordinate API contracts before dependent changes.
- Report modified files and test results.
- Review all changes before integration.

## Completion

A task is complete only after:

- Implementation is reviewed.
- Relevant tests are executed.
- Type checks pass where available.
- Outstanding issues are documented.
'@

    Set-Content -LiteralPath $AgentsMD `
        -Value $Instructions -Encoding UTF8

    Write-Host "[CREADO] AGENTS.md" -ForegroundColor Green

}
else {

    Write-Host "[OMITIDO] AGENTS.md ya existe. Se conserva." -ForegroundColor Yellow

}

# --------------------------------------------------
# 11. VALIDAR RESULTADO
# --------------------------------------------------

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host " INSTALACION FINALIZADA" -ForegroundColor Green
Write-Host "======================================`n" -ForegroundColor Cyan

Write-Host "Proyecto: $ProjectPath"
Write-Host "Motor: OpenCode"
Write-Host "Proveedor: GitHub Copilot"
Write-Host "Agente principal: coordinator"
Write-Host "Subagentes: frontend, backend, qa"
Write-Host "Air ACP: $ACPPath"

Write-Host "`nArchivos creados:" -ForegroundColor Cyan

Get-ChildItem $AgentDirectory -File |
    Select-Object -ExpandProperty Name

Write-Host "`nSIGUIENTE PASO:" -ForegroundColor Yellow
Write-Host "1. Ejecutar opencode en la carpeta del proyecto."
Write-Host "2. Escribir /connect."
Write-Host "3. Seleccionar GitHub Copilot."
Write-Host "4. Completar la autenticacion de GitHub."
Write-Host "5. Ejecutar /models y seleccionar un modelo."
Write-Host "6. Reiniciar WebStorm para cargar ACP."

Write-Host "`nNo se han realizado commits ni cambios en el codigo de la aplicacion." -ForegroundColor Green
