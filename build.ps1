# Pixel Pals 워치페이스 빌드 스크립트 (Windows PowerShell)
#
#   .\build.ps1              # FR265S용 빌드 → bin\PixelPals.prg
#   .\build.ps1 -Run         # 빌드 후 시뮬레이터 실행
#   .\build.ps1 -Device fr265
#   .\build.ps1 -Store       # 스토어판(Mochi Pixel) 빌드 → bin\MochiPixel.prg
#   .\build.ps1 -Store -Release   # 스토어 업로드용 .iq 패키지 → bin\MochiPixel.iq
#
# 실행 정책 오류가 나면: powershell -ExecutionPolicy Bypass -File .\build.ps1
param(
    [string]$Device = "fr265s",
    [switch]$Run,
    [switch]$Store,
    [switch]$Release
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
Set-Location $root

# 1) SDK 찾기 (SDK Manager 기본 설치 위치)
$sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
if (-not (Test-Path $sdkRoot)) {
    Write-Error "Connect IQ SDK가 없습니다. README.md의 '1. SDK 설치'를 먼저 진행하세요."
}
$sdk = Get-ChildItem $sdkRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$bin = Join-Path $sdk.FullName "bin"
Write-Host "SDK: $($sdk.Name)" -ForegroundColor Cyan

# 2) 개발자 키 (없으면 생성)
$key = Join-Path $root "keys\developer_key.der"
if (-not (Test-Path $key)) {
    New-Item -ItemType Directory -Force (Join-Path $root "keys") | Out-Null
    if (Get-Command openssl -ErrorAction SilentlyContinue) {
        $pem = Join-Path $root "keys\developer_key.pem"
        openssl genrsa -out $pem 4096
        openssl pkcs8 -topk8 -inform PEM -outform DER -in $pem -out $key -nocrypt
        Remove-Item $pem
    } else {
        try {
            $rsa = [System.Security.Cryptography.RSA]::Create(4096)
            [IO.File]::WriteAllBytes($key, $rsa.ExportPkcs8PrivateKey())
        } catch {
            Write-Error "키를 만들 수 없습니다. VS Code에서 'Monkey C: Generate a Developer Key'로 keys\developer_key.der 를 만드세요."
        }
    }
    Write-Host "개발자 키 생성: $key  (잃어버리지 않게 백업하세요)" -ForegroundColor Yellow
}

# 3) 스프라이트 재생성 + 도롱이 이미지(assets\dorongi.png) 가공
if (Get-Command python -ErrorAction SilentlyContinue) {
    python tools\gen_sprites.py
    python -c "import PIL" 2>$null
    if ($LASTEXITCODE -ne 0) { python -m pip install --user pillow }
    python tools\fetch_assets.py
    python tools\check_resources.py
    if ($LASTEXITCODE -ne 0) { Write-Error "리소스 검사 실패 (위 목록 참고)" }
} elseif (-not (Test-Path (Join-Path $root "source\Assets.mc"))) {
    Write-Error "Python 이 필요합니다 (source\Assets.mc 생성용). https://www.python.org 에서 설치하세요."
}

New-Item -ItemType Directory -Force (Join-Path $root "bin") | Out-Null

# 전체판(Pixel Pals, 사이드로드용) / 스토어판(Mochi Pixel, 스토어 업로드용)
if ($Store) { $jungle = "store.jungle"; $name = "MochiPixel" } else { $jungle = "monkey.jungle"; $name = "PixelPals" }
if ($Release -and -not $Store) {
    Write-Warning "스토어에는 스토어판(-Store -Release)을 올리세요. 전체판은 앱 ID가 달라 사이드로드용입니다."
}

if ($Release) {
    & "$bin\monkeyc.bat" -e -r -f $jungle -o "bin\$name.iq" -y $key -l 0 -w
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "완료: bin\$name.iq" -ForegroundColor Green
    exit 0
}

& "$bin\monkeyc.bat" -f $jungle -d $Device -o "bin\$name.prg" -y $key -l 0 -w
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "완료: bin\$name.prg" -ForegroundColor Green

if ($Run) {
    Start-Process "$bin\connectiq.bat"
    Start-Sleep -Seconds 4
    & "$bin\monkeydo.bat" "bin\$name.prg" $Device
}
