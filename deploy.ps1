param(
    [string]$Remote = "",
    [string]$Branch = "gh-pages",
    [string]$BaseHref = "/t_co_service/",
    [switch]$UseCanvasKit
)

function Ensure-GitRepo {
    if (-not (Test-Path .git)) {
        git init | Out-Null
        git add . | Out-Null
        git commit -m "chore: initial commit" | Out-Null
    }
}

function Ensure-Remote($remote) {
    if ([string]::IsNullOrWhiteSpace($remote)) { return }
    $existing = git remote | Out-String
    if (-not ($existing -match "origin")) {
        git remote add origin $remote | Out-Null
    }
}

function Build-Web($baseHref, $useCanvasKit) {
    flutter clean | Out-Null
    flutter pub get | Out-Null
    $renderer = $useCanvasKit.IsPresent ? "canvaskit" : "html"
    flutter build web --release --web-renderer=$renderer --base-href=$baseHref | Out-Null
}

function Deploy-GHPages($branch) {
    $worktreeDir = ".gh-pages"
    if (Test-Path $worktreeDir) { Remove-Item -Recurse -Force $worktreeDir }

    $remoteBranchExists = $false
    try {
        git ls-remote --exit-code --heads origin $branch | Out-Null
        if ($LASTEXITCODE -eq 0) { $remoteBranchExists = $true }
    } catch {}

    if ($remoteBranchExists) {
        git worktree add $worktreeDir origin/$branch | Out-Null
    } else {
        git worktree add -B $branch $worktreeDir | Out-Null
    }

    Push-Location $worktreeDir
    Get-ChildItem -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Force -Recurse
    Copy-Item ..\build\web\* . -Recurse
    git add -A | Out-Null
    git commit -m ("deploy: $(Get-Date -Format s)") | Out-Null
    git push -u origin $branch
    Pop-Location

    git worktree prune | Out-Null
}

Write-Host "Ensuring git repository..."
Ensure-GitRepo
Ensure-Remote $Remote

Write-Host "Building Flutter Web..."
Build-Web $BaseHref $UseCanvasKit

Write-Host "Deploying to gh-pages..."
Deploy-GHPages $Branch

Write-Host "Done."
