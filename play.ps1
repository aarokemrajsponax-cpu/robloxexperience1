# Keeps this folder in sync with GitHub and serves it to Roblox Studio.
#
# Run it from the project folder (the one with rojo.exe in it):
#   irm https://raw.githubusercontent.com/aarokemrajsponax-cpu/robloxexperience1/claude/nice-brown-a88p9r/play.ps1 | iex
#
# Then click Rojo -> Connect in Studio. Any change pushed to the branch
# shows up in Studio within a few seconds.

$Repo = "aarokemrajsponax-cpu/robloxexperience1"
$Branch = "claude/nice-brown-a88p9r"
$CheckEverySeconds = 5

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Folder = (Get-Location).Path
$Web = New-Object Net.WebClient

if (-not (Test-Path (Join-Path $Folder "rojo.exe"))) {
    Write-Host "Can't find rojo.exe in this folder." -ForegroundColor Red
    Write-Host "Open PowerShell in the folder that has rojo.exe and src in it, then try again." -ForegroundColor Red
    return
}

function Get-LatestCommit {
    $refs = $Web.DownloadString("https://github.com/$Repo.git/info/refs?service=git-upload-pack")
    if ($refs -match "([0-9a-f]{40}) refs/heads/$([regex]::Escape($Branch))") { return $Matches[1] }
    return $null
}

function Update-Files($Commit) {
    $temp = Join-Path $env:TEMP "robloxexperience1-sync"
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $temp -ItemType Directory | Out-Null
    $zip = Join-Path $temp "latest.zip"
    $Web.DownloadFile("https://github.com/$Repo/archive/$Commit.zip", $zip)
    Expand-Archive $zip -DestinationPath $temp -Force
    $source = Get-ChildItem $temp -Directory | Select-Object -First 1

    robocopy (Join-Path $source.FullName "src") (Join-Path $Folder "src") /MIR /NJH /NJS /NFL /NDL /NP | Out-Null
    Copy-Item (Join-Path $source.FullName "default.project.json") $Folder -Force
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}

$last = $null
$rojo = $null
try {
    $last = Get-LatestCommit
    Update-Files $last
    Write-Host "Files are up to date." -ForegroundColor Green

    $rojo = Start-Process -FilePath (Join-Path $Folder "rojo.exe") -ArgumentList "serve" -WorkingDirectory $Folder -NoNewWindow -PassThru
    Start-Sleep -Seconds 2
    Write-Host ""
    Write-Host "Ready! In Roblox Studio click Rojo -> Connect." -ForegroundColor Green
    Write-Host "Keep this window open. Updates will appear here automatically." -ForegroundColor Green

    while ($true) {
        Start-Sleep -Seconds $CheckEverySeconds
        try {
            $latest = Get-LatestCommit
            if ($latest -and $latest -ne $last) {
                Update-Files $latest
                $last = $latest
                Write-Host "$(Get-Date -Format t)  New update synced to Studio!" -ForegroundColor Cyan
            }
        } catch {
            # Internet hiccup; try again next time around.
        }
    }
} finally {
    if ($rojo -and -not $rojo.HasExited) { Stop-Process -Id $rojo.Id -Force }
}
