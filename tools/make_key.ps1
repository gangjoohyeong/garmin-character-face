# 개발자 서명 키 만들기 + GitHub Secret(DEVELOPER_KEY_B64)용 텍스트를 클립보드에 복사 (Windows)
#
#   powershell -ExecutionPolicy Bypass -File tools\make_key.ps1
#
# 이미 keys\developer_key.der 가 있으면 새로 만들지 않고 그 키를 씁니다.
# 이 키는 스토어 앱 업데이트에 계속 필요하니 반드시 백업해 두세요. (저장소에는 올라가지 않음)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$key = Join-Path $root "keys\developer_key.der"
New-Item -ItemType Directory -Force (Join-Path $root "keys") | Out-Null

if (-not (Test-Path $key)) {
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
            Write-Error "키를 만들 수 없습니다. Git for Windows(openssl 포함)를 설치하거나 PowerShell 7 에서 다시 실행하세요."
        }
    }
    Write-Host "새 개발자 키를 만들었습니다: $key" -ForegroundColor Yellow
} else {
    Write-Host "기존 개발자 키를 사용합니다: $key" -ForegroundColor Cyan
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($key))
Set-Clipboard -Value $b64
Write-Host ""
Write-Host "GitHub Secret 용 텍스트를 클립보드에 복사했습니다 ($($b64.Length)자)." -ForegroundColor Green
Write-Host "저장소 Settings → Secrets and variables → Actions → New repository secret"
Write-Host "  Name:   DEVELOPER_KEY_B64"
Write-Host "  Secret: (Ctrl+V 로 붙여넣기)"
Write-Host ""
Write-Host "keys\developer_key.der 파일은 꼭 백업하세요. 잃어버리면 같은 앱으로 업데이트를 올릴 수 없습니다." -ForegroundColor Yellow
