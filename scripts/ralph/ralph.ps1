# Ralph - Autonomous AI Agent Loop for Windows PowerShell
param (
    [string]$Tool = "claude",
    [int]$MaxIterations = 10
)

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PrdFile = Join-Path $ScriptDir "prd.json"
$ProgressFile = Join-Path $ScriptDir "progress.txt"
$ArchiveDir = Join-Path $ScriptDir "archive"
$LastBranchFile = Join-Path $ScriptDir ".last-branch"

# Archive previous run if branch changed
if ((Test-Path $PrdFile) -and (Test-Path $LastBranchFile)) {
    try {
        $prdContent = Get-Content $PrdFile -Raw | ConvertFrom-Json
        $currentBranch = $prdContent.branchName
        $lastBranch = (Get-Content $LastBranchFile -Raw).Trim()

        if ($currentBranch -and $lastBranch -and ($currentBranch -ne $lastBranch)) {
            $date = Get-Date -Format "yyyy-MM-dd"
            $folderName = $lastBranch -replace '^ralph/', ''
            $archiveFolder = Join-Path $ArchiveDir "$date-$folderName"

            Write-Host "Archiving previous run: $lastBranch"
            New-Item -ItemType Directory -Path $archiveFolder -Force | Out-Null
            if (Test-Path $PrdFile) { Copy-Item $PrdFile (Join-Path $archiveFolder "prd.json") }
            if (Test-Path $ProgressFile) { Copy-Item $ProgressFile (Join-Path $archiveFolder "progress.txt") }
            Write-Host "   Archived to: $archiveFolder"

            Set-Content -Path $ProgressFile -Value "# Ralph Progress Log`nStarted: $(Get-Date)`n---"
        }
    } catch {}
}

if (Test-Path $PrdFile) {
    try {
        $prdContent = Get-Content $PrdFile -Raw | ConvertFrom-Json
        if ($prdContent.branchName) {
            Set-Content -Path $LastBranchFile -Value $prdContent.branchName
        }
    } catch {}
}

if (-not (Test-Path $ProgressFile)) {
    Set-Content -Path $ProgressFile -Value "# Ralph Progress Log`nStarted: $(Get-Date)`n---"
}

Write-Host "Starting Ralph - Tool: $Tool - Max iterations: $MaxIterations" -ForegroundColor Cyan

for ($i = 1; $i -le $MaxIterations; $i++) {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Yellow
    Write-Host "  Ralph Iteration $i of $MaxIterations ($Tool)" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Yellow

    $output = ""
    if ($Tool -eq "amp") {
        $promptPath = Join-Path $ScriptDir "prompt.md"
        $output = Get-Content $promptPath -Raw | & amp --dangerously-allow-all 2>&1 | Tee-Object -Variable cmdOut
    } else {
        $claudePromptPath = Join-Path $ScriptDir "CLAUDE.md"
        $promptContent = Get-Content $claudePromptPath -Raw
        $output = $promptContent | & claude --dangerously-skip-permissions --print 2>&1 | Tee-Object -Variable cmdOut
    }

    if ($output -match "<promise>COMPLETE</promise>") {
        Write-Host ""
        Write-Host "Ralph completed all tasks!" -ForegroundColor Green
        Write-Host "Completed at iteration $i of $MaxIterations"
        exit 0
    }

    Write-Host "Iteration $i complete. Continuing..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Ralph reached max iterations ($MaxIterations) without completing all tasks." -ForegroundColor Red
Write-Host "Check $ProgressFile for status."
exit 1
