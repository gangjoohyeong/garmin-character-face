#!/usr/bin/env bash
# 개발자 서명 키 만들기 + GitHub Secret(DEVELOPER_KEY_B64)용 텍스트 출력 (macOS / Linux)
#   ./tools/make_key.sh
# 이미 keys/developer_key.der 가 있으면 그 키를 씁니다. 키는 꼭 백업하세요.
set -e
cd "$(dirname "$0")/.."
mkdir -p keys
KEY=keys/developer_key.der
if [ ! -f "$KEY" ]; then
  openssl genrsa -out keys/developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in keys/developer_key.pem -out "$KEY" -nocrypt
  rm keys/developer_key.pem
  echo "새 개발자 키를 만들었습니다: $KEY"
else
  echo "기존 개발자 키를 사용합니다: $KEY"
fi
B64=$(base64 < "$KEY" | tr -d '\n')
if command -v pbcopy >/dev/null; then printf %s "$B64" | pbcopy; echo "클립보드에 복사했습니다 (${#B64}자)."
else echo "아래 한 줄 전체를 복사하세요:"; echo "$B64"; fi
echo "GitHub 저장소 Settings → Secrets and variables → Actions → New repository secret"
echo "  Name: DEVELOPER_KEY_B64"
