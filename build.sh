#!/usr/bin/env bash
# macOS / Linux 빌드:  ./build.sh [device] [--run]
set -e
cd "$(dirname "$0")"
DEVICE="${1:-fr265s}"
if [ -z "$CIQ_SDK" ]; then
  for d in "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks" "$HOME/.Garmin/ConnectIQ/Sdks"; do
    [ -d "$d" ] && CIQ_SDK="$(ls -dt "$d"/*/ | head -1)"
  done
fi
[ -z "$CIQ_SDK" ] && { echo "Connect IQ SDK를 찾을 수 없습니다 (CIQ_SDK 환경변수로 지정 가능)"; exit 1; }
KEY=keys/developer_key.der
if [ ! -f "$KEY" ]; then
  mkdir -p keys
  openssl genrsa -out keys/developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in keys/developer_key.pem -out "$KEY" -nocrypt
  rm keys/developer_key.pem
fi
command -v python3 >/dev/null && python3 tools/gen_sprites.py
mkdir -p bin
"$CIQ_SDK/bin/monkeyc" -f monkey.jungle -d "$DEVICE" -o bin/PixelPals.prg -y "$KEY" -l 0 -w
echo "완료: bin/PixelPals.prg"
if [ "$2" = "--run" ]; then
  "$CIQ_SDK/bin/connectiq" & sleep 4
  "$CIQ_SDK/bin/monkeydo" bin/PixelPals.prg "$DEVICE"
fi
