# ==============================================================
# VAULT-TEC ARCHIVE TERMINAL — AUTO INSTALLER + MAIN TERMINAL
# ==============================================================

$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Vault-Header {
    Clear-Host
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "   VAULT-TEC ARCHIVE SYSTEM v2.0" -ForegroundColor Green
    Write-Host "   AUTHORIZED USER: MARIK" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
}

Vault-Header
Write-Host "[BOOT] Initializing Vault-Tec environment..." -ForegroundColor Green
Start-Sleep -Milliseconds 300

# --------------------------------------------------
# PYTHON CHECK + AUTO INSTALL (CURRENT USER)
# --------------------------------------------------

Write-Host "[CHECK] Searching for Python runtime..." -ForegroundColor Green

$PythonDir  = Join-Path $env:LOCALAPPDATA "Programs\Python\Python312"
$PythonPath = Join-Path $PythonDir "python.exe"

if (-not (Test-Path $PythonPath)) {

    Write-Host "[WARN] Python not found. Installing Python 3.12..." -ForegroundColor Yellow

    $tempDir = Join-Path $env:TEMP "VaultTecPython"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }

    $pythonInstaller = Join-Path $tempDir "python-3.12.0-amd64.exe"
    $pythonUrl       = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"

    Write-Host "[DOWNLOAD] Fetching Python installer..." -ForegroundColor Green
    Invoke-WebRequest $pythonUrl -OutFile $pythonInstaller -Headers @{ "User-Agent" = "VaultTecTerminal" }

    Write-Host "[INSTALL] Running silent Python installer..." -ForegroundColor Green

    $proc = Start-Process -FilePath $pythonInstaller `
        -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_pip=1" `
        -Wait -PassThru

    if ($proc.ExitCode -ne 0) {
        Write-Host "[FAIL] Python installation failed. Exit code: $($proc.ExitCode)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    if (-not (Test-Path $PythonPath)) {
        Write-Host "[FAIL] Python installation completed but python.exe not found." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    Write-Host "[OK] Python installed successfully." -ForegroundColor Green
} else {
    Write-Host "[OK] Python already installed." -ForegroundColor Green
}

Write-Host "[OK] Using Python at: $PythonPath" -ForegroundColor Green

# --------------------------------------------------
# PYTHON DEPENDENCIES (HYBRID OFFLINE-FIRST)
# --------------------------------------------------

Write-Host ""
Write-Host "[SYNC] Installing Python dependencies (offline-first hybrid)..." -ForegroundColor Green

$PipCache = Join-Path $env:LOCALAPPDATA "pip\Cache"
if (-not (Test-Path $PipCache)) {
    New-Item -ItemType Directory -Path $PipCache | Out-Null
}

$packages = @(
    "yt-dlp[default]",
    "certifi",
    "websockets",
    "pycryptodome",
    "mutagen",
    "PySocks"
)

foreach ($pkg in $packages) {

    Write-Host ""
    Write-Host "→ Processing: $pkg" -ForegroundColor Cyan

    # 1) Try offline install from cache
    $offline = & $PythonPath -m pip install --no-index --find-links "$PipCache" $pkg 2>&1

    if ($offline -match "Successfully installed") {
        Write-Host "   Status: Installed from cache" -ForegroundColor Green
        continue
    }

    if ($offline -match "Requirement already satisfied") {
        Write-Host "   Status: Already installed" -ForegroundColor Green
        continue
    }

    Write-Host "   Cache miss → downloading..." -ForegroundColor Yellow

    # 2) Download package into cache
    $download = & $PythonPath -m pip download -d "$PipCache" $pkg 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "   Status: Failed (no internet + no cache)" -ForegroundColor Red
        continue
    }

    # 3) Install from cache after download
    $install = & $PythonPath -m pip install --no-index --find-links "$PipCache" $pkg 2>&1

    if ($install -match "Successfully installed") {
        Write-Host "   Status: Downloaded + installed" -ForegroundColor Green
    } else {
        Write-Host "   Status: Failed to install" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[OK] All Python dependencies processed." -ForegroundColor Green

# --------------------------------------------------
# DIRECTORIES
# --------------------------------------------------

$RootDir   = Join-Path $env:LOCALAPPDATA "VaultTecArchive"
$ToolsDir  = Join-Path $RootDir "tools"
$FFmpegDir = Join-Path $ToolsDir "ffmpeg"

$Aria2Exe  = Join-Path $ToolsDir  "aria2c.exe"
$FFmpegExe = Join-Path $FFmpegDir "ffmpeg.exe"

foreach ($d in @($RootDir, $ToolsDir, $FFmpegDir)) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d | Out-Null
    }
}

# --------------------------------------------------
# aria2 INSTALL
# --------------------------------------------------

if (-not (Test-Path $Aria2Exe)) {

    Write-Host ""
    Write-Host "[SYNC] Downloading aria2 module..." -ForegroundColor Green

    $apiUrl = "https://api.github.com/repos/aria2/aria2/releases/latest"
    $json   = Invoke-RestMethod $apiUrl -Headers @{ "User-Agent" = "VaultTecTerminal" }

    $asset = $json.assets |
        Where-Object { $_.name -match "win-64bit.*\.zip$" } |
        Select-Object -First 1

    if ($asset) {
        $ariaZip = Join-Path $ToolsDir $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $ariaZip -Headers @{ "User-Agent" = "VaultTecTerminal" }

        Expand-Archive $ariaZip -DestinationPath $ToolsDir -Force

        $found = Get-ChildItem $ToolsDir -Recurse -Filter aria2c.exe | Select-Object -First 1
        if ($found) {
            Copy-Item $found.FullName $Aria2Exe -Force
        }

        Remove-Item $ariaZip -Force
        Write-Host "[OK] aria2 installed." -ForegroundColor Green
    } else {
        Write-Host "[WARN] aria2 win-64bit archive not found." -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] aria2 already installed." -ForegroundColor Green
}

# --------------------------------------------------
# FFmpeg INSTALL
# --------------------------------------------------

if (-not (Test-Path $FFmpegExe)) {

    Write-Host ""
    Write-Host "[SYNC] Downloading FFmpeg module..." -ForegroundColor Green

    $ffZip = Join-Path $ToolsDir "ffmpeg.zip"
    $ffUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

    Invoke-WebRequest $ffUrl -OutFile $ffZip -Headers @{ "User-Agent" = "VaultTecTerminal" }

    Expand-Archive $ffZip -DestinationPath $ToolsDir -Force

    $found = Get-ChildItem $ToolsDir -Recurse -Filter ffmpeg.exe | Select-Object -First 1
    if ($found) {
        Copy-Item $found.FullName $FFmpegExe -Force
    }

    Remove-Item $ffZip -Force
    Write-Host "[OK] FFmpeg installed." -ForegroundColor Green
} else {
    Write-Host "[OK] FFmpeg already installed." -ForegroundColor Green
}

# --------------------------------------------------
# ALL DEPENDENCIES READY → START TERMINAL
# --------------------------------------------------

Vault-Header
Write-Host "[READY] All dependencies installed successfully." -ForegroundColor Green
Write-Host "[SYSTEM] Launching Vault-Tec Archive Terminal..." -ForegroundColor Green
Start-Sleep -Milliseconds 600

# --------------------------------------------------
# FALLOUT-STYLE PROGRESS BAR
# --------------------------------------------------

function Show-ProgressBar {
    param([double]$Percent)

    $width  = 40
    $filled = [math]::Round($Percent / 100 * $width)
    $empty  = $width - $filled

    $bar = ("█" * $filled) + ("-" * $empty)

    Write-Host -NoNewline "`r[$bar] $([math]::Round($Percent))%"
}

# --------------------------------------------------
# MAIN TERMINAL
# --------------------------------------------------

Vault-Header
Write-Host "[READY] Archive synchronization mode active." -ForegroundColor Green
Write-Host "[MODE] HIGH BITRATE PRIORITY ENABLED" -ForegroundColor Green
Write-Host ""

$url = Read-Host "ENTER VIDEO URL"
if (-not $url) { exit }

$SAVE_DIR = Join-Path $env:USERPROFILE "Downloads"

Write-Host ""
Write-Host "[SYNC] Downloading 1080p HIGH-BITRATE archive..." -ForegroundColor Green
Write-Host ""

$ytArgs = @(
    "--ffmpeg-location", "$FFmpegExe",
    "--merge-output-format", "mp4",
    "--concurrent-fragments", "8",
    "-f", "bv*[height=1080][vcodec^=avc1]+ba/best",
    "-o", "$SAVE_DIR/%(title)s.%(ext)s",
    "$url"
)

$process = New-Object System.Diagnostics.Process
$process.StartInfo.FileName               = $PythonPath
$process.StartInfo.Arguments              = "-m yt_dlp " + ($ytArgs -join " ")
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.RedirectStandardError  = $true
$process.StartInfo.UseShellExecute        = $false
$process.StartInfo.CreateNoWindow         = $true

$process.Start() | Out-Null

while (-not $process.HasExited) {
    $line = $process.StandardOutput.ReadLine()
    if ($line -match "(\d+\.\d+)%") {
        $percent = [double]$matches[1]
        Show-ProgressBar -Percent $percent
    }
}

Write-Host "`r[████████████████████████████████████████] 100%" -ForegroundColor Green
Write-Host ""
Write-Host "[COMPLETE] Archive saved to $SAVE_DIR" -ForegroundColor Green
Write-Host "[VAULT-TEC] Thank you for using the Vault-Tec terminal." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
