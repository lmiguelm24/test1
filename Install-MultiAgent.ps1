
param(
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$GitArgs)

    $result = & git -C $ProjectPath @GitArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Git fallo: $($result -join "`n")"
    }

    return $result
}

function Write-ProjectFile {
    param(
        [string]$RelativePath,
        [string]$Content
    )

    $path = Join-Path $ProjectPath $RelativePath
    $directory = Split-Path $path -Parent

    New-Item -ItemType Directory -Path $directory -Force |
        Out-Null

    if (Test-Path $path) {
        $existing = Get-Content -LiteralPath $path -Raw

        if ($existing.Trim() -eq $Content.Trim()) {
            Write-Host "[OK] Sin cambios: $RelativePath" -ForegroundColor DarkGray
            return
        }

        $backup = "$path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $path $backup
        Write-Host "[BACKUP] $RelativePath" -ForegroundColor Yellow
    }

    Set-Content -LiteralPath $path -Value $Content -Encoding UTF8
    Write-Host "[CREADO] $RelativePath" -ForegroundColor Green
}

# --------------------------------------------------
# 1. VALIDAR PROYECTO
# --------------------------------------------------

if (-not (Test-Path $ProjectPath)) {
    throw "No existe el directorio indicado."
}

$ProjectPath = (Resolve-Path $ProjectPath).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git no esta instalado o no esta en PATH."
}

Write-Host "`nMULTIAGENT INSTALLER" -ForegroundColor Cyan
Write-Host "Proyecto: $ProjectPath"

# --------------------------------------------------
# 2. GIT
# --------------------------------------------------

$GitRoot = & git -C $ProjectPath rev-parse --show-toplevel 2>$null

if ($LASTEXITCODE -ne 0) {

    Write-Host "[AVISO] Proyecto sin Git. Inicializando main..." -ForegroundColor Yellow

    & git -C $ProjectPath init -b main

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo inicializar Git."
    }

    $NewRepository = $true

} else {

    $NewRepository = $false

    $GitRoot = (Resolve-Path $GitRoot).Path

    if ($GitRoot -ne $ProjectPath) {
        throw "Ejecuta el instalador desde la raiz real del repositorio."
    }

    $status = Invoke-Git @("status", "--porcelain")

    if ($status.Count -gt 0) {
        throw "Hay cambios sin guardar en Git. Guarda o revisa tus cambios antes de instalar."
    }
}

# --------------------------------------------------
# 3. INSTRUCCIONES GENERALES
# --------------------------------------------------

$Instructions = @'
# MULTIAGENT PROJECT RULES

## Architecture

The project uses four independent agent sessions.

1. Junie: project coordinator and main branch owner.
2. GitHub Copilot Frontend: frontend implementation.
3. OpenCode Backend: backend implementation.
4. GitHub Copilot QA: independent quality review.

## Ownership

Junie:
- Project architecture.
- Task planning.
- Shared API contracts.
- Integration.
- Main branch.
- Final validation.

Copilot Frontend:
- React.
- Vite.
- TypeScript.
- UI components.
- Forms.
- Frontend integration.

OpenCode Backend:
- Node.js.
- TypeScript.
- API.
- Database.
- Services.
- Backend validation.

Copilot QA:
- Testing.
- Regression analysis.
- Code review.
- API contract verification.
- Quality reports.

## Git rules

- main is owned by Junie.
- Frontend works on agent/frontend.
- Backend works on agent/backend.
- QA works on agent/qa.
- No secondary agent may merge into main.
- No force push.
- No destructive Git commands.
- No production database changes.
- Junie reviews every integration.

## Coordination

- Every task must have a written objective.
- Every task must list permitted files.
- Avoid simultaneous changes to shared files.
- Define API contracts before dependent implementation.
- QA reviews the resulting changes.
- Junie integrates only reviewed work.

## Completion requirements

Report:
- Files changed.
- Implementation details.
- Tests executed.
- Test results.
- Outstanding issues.
- Dependencies affected.

Never claim tests passed without executing them.
'@

Write-ProjectFile "AGENTS.md" $Instructions

# --------------------------------------------------
# 4. COORDINATION DIRECTORY
# --------------------------------------------------

$Coordination = @'
# Agent Coordination

Junie is the central coordinator.

## Workflow

1. Junie creates a task in tasks/.
2. Junie assigns a task to each specialist.
3. Frontend and backend work independently.
4. QA reviews the implementation.
5. Junie checks the results.
6. Junie integrates approved branches into main.

## Task status

Use:
- pending
- assigned
- in_progress
- review
- approved
- integrated
- blocked

## Safety

No agent can approve its own changes for integration.
QA reports findings independently.
Junie is responsible for final integration.
'@

Write-ProjectFile ".coordination/README.md" $Coordination

# --------------------------------------------------
# 5. JUNIE COORDINATOR PROMPT
# --------------------------------------------------

$Junie = @'
# JUNIE - MAIN COORDINATOR

You are the principal software architect and integration manager.

You own main.

Your team:
- GitHub Copilot Frontend.
- OpenCode Backend.
- GitHub Copilot QA.

Responsibilities:

1. Inspect the complete architecture.
2. Understand existing functionality.
3. Divide requests into independent tasks.
4. Define API contracts.
5. Write task assignments under .coordination/tasks/.
6. Assign frontend and backend work.
7. Request QA review.
8. Inspect every change.
9. Resolve integration issues.
10. Merge approved changes into main.
11. Execute final validation.

IMPORTANT:

Air ACP sessions are independent.
Do not claim to have launched or controlled another ACP session unless you actually have an integration that supports it.

Use task files as the shared coordination protocol.

Never merge unreviewed work.
Never force push.
Never overwrite existing user changes.
Ask before destructive operations.

You are the only agent authorized to integrate into main.
'@

Write-ProjectFile ".coordination/JUNIE.md" $Junie

# --------------------------------------------------
# 6. COPILOT FRONTEND PROMPT
# --------------------------------------------------

$Frontend = @'
# COPILOT FRONTEND

Role: Frontend developer.

Branch: agent/frontend.

Read AGENTS.md and your task assignment before working.

Responsibilities:
- React.
- Vite.
- TypeScript.
- shadcn/ui.
- Tailwind.
- Forms.
- Components.
- Frontend API integration.

Rules:
- Work only on frontend-owned files.
- Respect existing UI architecture.
- Do not modify backend implementation.
- Follow API contracts defined by Junie.
- Do not merge into main.
- Report files and tests.
- Commit only to your own branch when authorized.

When complete, report your result to Junie.
'@

Write-ProjectFile ".coordination/COPILOT-FRONTEND.md" $Frontend

# --------------------------------------------------
# 7. OPENCODE BACKEND PROMPT
# --------------------------------------------------

$Backend = @'
# OPENCODE BACKEND

Role: Backend developer.

Branch: agent/backend.

Read AGENTS.md and your task assignment before working.

Responsibilities:
- Node.js.
- TypeScript.
- REST API.
- Database.
- Services.
- Validation.
- Authentication.
- Backend tests.

Rules:
- Work only on backend-owned files.
- Respect existing API contracts.
- Do not modify frontend implementation.
- Do not perform destructive migrations.
- Do not modify production data.
- Do not merge into main.
- Report changed files and test results.
- Commit only to your own branch when authorized.

When complete, report your result to Junie.
'@

Write-ProjectFile ".coordination/OPENCODE-BACKEND.md" $Backend

# --------------------------------------------------
# 8. COPILOT QA PROMPT
# --------------------------------------------------

$QA = @'
# COPILOT QA

Role: Independent quality auditor.

Branch: agent/qa.

Read AGENTS.md and your task assignment before working.

Responsibilities:
- Test frontend.
- Test backend.
- Check API contracts.
- Detect regressions.
- Review TypeScript.
- Check security-sensitive changes.
- Report integration problems.

Rules:
- Do not modify production source files.
- Do not commit.
- Do not merge.
- Do not approve your own changes.
- Request permission before commands with side effects.
- Never claim tests passed without execution.

Report findings with:
- Severity.
- File.
- Line.
- Reproduction.
- Recommended correction.

Return your report to Junie.
'@

Write-ProjectFile ".coordination/COPILOT-QA.md" $QA

# --------------------------------------------------
# 9. TEMPLATES
# --------------------------------------------------

$TaskTemplate = @'
# TASK ID:

## Objective

## Assigned agent

## Branch

## Allowed files

## Files to avoid

## Dependencies

## API contract

## Acceptance criteria

## Tests required

## Status: pending
'@

Write-ProjectFile ".coordination/TASK-TEMPLATE.md" $TaskTemplate

# --------------------------------------------------
# 10. INITIAL SETUP COMMIT
# --------------------------------------------------

$Changes = Invoke-Git @("status", "--porcelain")

if ($Changes.Count -gt 0) {

    Write-Host "`n[FASE 1 COMPLETADA]" -ForegroundColor Green
    Write-Host "Se han creado las instrucciones y los perfiles."
    Write-Host ""
    Write-Host "Revisa los archivos nuevos y guarda la configuracion:"
    Write-Host ""
    Write-Host "git add AGENTS.md .coordination"
    Write-Host 'git commit -m "chore: configure multi-agent workflow"'
    Write-Host ""
    Write-Host "Despues vuelve a ejecutar este instalador."
    return
}

# --------------------------------------------------
# 11. VALIDAR MAIN
# --------------------------------------------------

$CurrentBranch = (Invoke-Git @("branch", "--show-current")) -join ""

if ($CurrentBranch -ne "main") {
    throw "Cambia primero a main. Rama actual: $CurrentBranch"
}

# --------------------------------------------------
# 12. CREAR WORKTREES
# --------------------------------------------------

$WorktreeRoot = "$ProjectPath-agents"

New-Item -ItemType Directory -Path $WorktreeRoot -Force |
    Out-Null

function Add-AgentWorktree {
    param(
        [string]$Branch,
        [string]$Folder
    )

    $Destination = Join-Path $WorktreeRoot $Folder

    if (Test-Path $Destination) {

        $Existing = & git -C $Destination rev-parse --show-toplevel 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[EXISTE] $Destination" -ForegroundColor Yellow
            return
        }

        throw "La ruta existe pero no es un worktree: $Destination"
    }

    $Branches = Invoke-Git @("branch", "--list", $Branch)

    if ($Branches.Count -gt 0) {

        Invoke-Git @("worktree", "add", $Destination, $Branch) |
            Out-Null

    } else {

        Invoke-Git @("worktree", "add", "-b", $Branch, $Destination, "main") |
            Out-Null

    }

    Write-Host "[WORKTREE] $Branch -> $Destination" -ForegroundColor Green
}

Add-AgentWorktree "agent/frontend" "frontend"
Add-AgentWorktree "agent/backend" "backend"
Add-AgentWorktree "agent/qa" "qa"

# --------------------------------------------------
# 13. RESULTADO
# --------------------------------------------------

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " MULTIAGENT CONFIGURATION READY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "MAIN: $ProjectPath"
Write-Host "FRONTEND: $WorktreeRoot\frontend"
Write-Host "BACKEND: $WorktreeRoot\backend"
Write-Host "QA: $WorktreeRoot\qa"

Write-Host "`nAbre cada carpeta como proyecto o sesion independiente en Air."
Write-Host "Junie debe trabajar en la carpeta principal."
Write-Host "`nNo se han realizado merges ni push."
