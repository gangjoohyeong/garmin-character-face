#!/usr/bin/env bash
# macOS / Linux 빌드:  ./build.sh [device] [--run] [--store]
set -e
cd "$(dirname "$0")"
DEVICE="${1:-fr265s}"
JUNGLE=monkey.jungle; NAME=PixelPals
for a in "$@"; do [ "$a" = "--store" ] && { JUNGLE=store.jungle; NAME=MochiPixel; }; done
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
python3 tools/gen_sprites.py
python3 -c "import PIL" 2>/dev/null || python3 -m pip install --user pillow
python3 tools/fetch_assets.py
python3 tools/check_resources.py
mkdir -p bin
"$CIQ_SDK/bin/monkeyc" -f "$JUNGLE" -d "$DEVICE" -o "bin/$NAME.prg" -y "$KEY" -l 0 -w
echo "완료: bin/$NAME.prg"
if [[ " $* " == *" --run "* ]]; then
  "$CIQ_SDK/bin/connectiq" & sleep 4
  "$CIQ_SDK/bin/monkeydo" "bin/$NAME.prg" "$DEVICE"
fi
