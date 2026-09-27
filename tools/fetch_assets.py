#!/usr/bin/env python3
"""
외부 캐릭터 에셋 받기 / 가공.

디지털 캐릭터 스타일에서 쓰는 비트맵을 만든다. 에셋은 저작권이 있으므로 저장소에 커밋하지 않고
빌드할 때마다 이 스크립트로 받아서 만든다 (결과물은 .gitignore 대상).

  - 꼬부기 / 파이리 : PokeAPI 스프라이트 저장소의 공식 아트를 내려받음
  - 도롱이          : assets/dorongi.png (직접 넣어 둔 파일, 흰 배경이면 자동으로 지움)
  - 모찌            : 오리지널 캐릭터라 벡터 그림을 그대로 씀

만드는 파일:
  resources/drawables/assets.xml      비트맵 리소스 목록
  resources/drawables/assets/*.png    크기별 비트맵 (66/88/110/132px) + AOD 외곽선
  source/Assets.mc                    (캐릭터, 크기) -> 리소스 ID
  preview/assets.js                   미리보기용 같은 이미지 (data URI)

에셋을 못 구하면(오프라인, Pillow 없음, 파일 없음) 해당 캐릭터는 비워 두고,
워치는 벡터 그림으로 대신 그린다. 그래서 이 스크립트가 실패해도 빌드는 된다.

사용법:  python tools/fetch_assets.py
"""
import base64
import io
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "assets", "cache")
OUT_DIR = os.path.join(ROOT, "resources", "drawables", "assets")

# 캐릭터 인덱스 -> 에셋 정보 (0 모찌는 없음)
SOURCES = {
    1: {"name": "squirtle", "url": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/7.png"},
    2: {"name": "charmander", "url": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/4.png"},
    3: {"name": "dorongi", "file": os.path.join(ROOT, "assets", "dorongi.png")},
}
SCALES = [3, 4, 5, 6]          # 워치 코드의 캐릭터 배율 (상자 한 변 = 배율 * 22px)
AOD_SCALE = 3
AOD_COLOR = (0x5A, 0x5A, 0x5A, 255)


def log(msg):
    print("[assets] " + msg)


def load_source(src):
    """원본 이미지 bytes (캐시 사용)."""
    if "file" in src:
        if os.path.exists(src["file"]):
            with open(src["file"], "rb") as f:
                return f.read()
        return None
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, src["name"] + ".png")
    if not os.path.exists(path):
        try:
            with urllib.request.urlopen(src["url"], timeout=30) as r:
                data = r.read()
            with open(path, "wb") as f:
                f.write(data)
        except Exception as e:  # noqa: BLE001
            log("%s 다운로드 실패: %s" % (src["name"], e))
            return None
    with open(path, "rb") as f:
        return f.read()


def remove_white_background(img):
    """테두리와 이어진 흰색(에 가까운) 영역을 투명하게 (flood fill)."""
    from PIL import Image
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    def whitish(p):
        return p[3] > 0 and p[0] > 235 and p[1] > 235 and p[2] > 235

    seen = bytearray(w * h)
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + \
            [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if not whitish(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        if x > 0: stack.append((x - 1, y))
        if x < w - 1: stack.append((x + 1, y))
        if y > 0: stack.append((x, y - 1))
        if y < h - 1: stack.append((x, y + 1))
    return img


def fit(img, box):
    """투명 여백을 자르고 box x box 안에 비율 유지로 맞춤 (아래 가운데 정렬)."""
    from PIL import Image
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w, h = img.size
    k = min(box / w, box / h)
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    img = img.resize((nw, nh), Image.LANCZOS)
    # 워치에서 반투명 가장자리가 번지지 않게 알파를 0/255 로
    r, g, b, a = img.split()
    a = a.point(lambda v: 255 if v >= 128 else 0)
    img = Image.merge("RGBA", (r, g, b, a))
    out = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    out.paste(img, ((box - nw) // 2, box - nh), img)
    return out


def outline(img):
    """알파 마스크의 가장자리만 회색으로 (AOD용)."""
    from PIL import Image
    w, h = img.size
    a = img.split()[3].load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            if a[x, y] == 0:
                continue
            edge = x == 0 or y == 0 or x == w - 1 or y == h - 1 or \
                a[x - 1, y] == 0 or a[x + 1, y] == 0 or a[x, y - 1] == 0 or a[x, y + 1] == 0
            if edge:
                o[x, y] = AOD_COLOR
    return out


def to_data_uri(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def main():
    try:
        from PIL import Image
    except ImportError:
        Image = None
        log("Pillow 가 없어 에셋을 만들지 않습니다 (pip install pillow). 벡터 그림으로 대신 그립니다.")

    made = {}      # ci -> {"sizes": {scale: rid}, "aod": rid}
    preview = {}   # ci -> {"sizes": {scale: uri}, "aod": uri}
    os.makedirs(OUT_DIR, exist_ok=True)
    for f in os.listdir(OUT_DIR):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT_DIR, f))

    if Image is not None:
        for ci, src in SOURCES.items():
            data = load_source(src)
            if data is None:
                if "file" in src:
                    log("%s: %s 파일이 없어 벡터 그림을 씁니다." % (src["name"], os.path.relpath(src["file"], ROOT)))
                continue
            img = Image.open(io.BytesIO(data)).convert("RGBA")
            if img.getextrema()[3][0] == 255:     # 알파가 전부 불투명 = 배경 있음
                img = remove_white_background(img)
            made[ci] = {"sizes": {}}
            preview[ci] = {"sizes": {}}
            for s in SCALES:
                box = s * 22
                im = fit(img, box)
                rid = "Asset%s%d" % (src["name"].capitalize(), box)
                im.save(os.path.join(OUT_DIR, rid + ".png"))
                made[ci]["sizes"][s] = rid
                preview[ci]["sizes"][s] = to_data_uri(im)
                if s == AOD_SCALE:
                    ol = outline(im)
                    aid = "Asset%sAod" % src["name"].capitalize()
                    ol.save(os.path.join(OUT_DIR, aid + ".png"))
                    made[ci]["aod"] = aid
                    preview[ci]["aod"] = to_data_uri(ol)
            log("%s: 비트맵 %d개" % (src["name"], len(SCALES) + 1))

    # ---- resources/drawables/assets.xml ----
    lines = ["<drawables>"]
    for ci in sorted(made):
        for rid in list(made[ci]["sizes"].values()) + [made[ci]["aod"]]:
            lines.append('    <bitmap id="%s" filename="assets/%s.png" />' % (rid, rid))
    lines.append("</drawables>")
    with open(os.path.join(ROOT, "resources", "drawables", "assets.xml"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    # ---- source/Assets.mc ----
    L = ["// 자동 생성 파일 - tools/fetch_assets.py (커밋하지 않음)",
         "import Toybox.Lang;", "", "module Assets {",
         "    // 캐릭터 ci, 배율 s 의 비트맵 리소스 (없으면 null → 벡터 그림 사용)",
         "    function get(ci as Number, s as Number) as ResourceId or Null {"]
    for ci in sorted(made):
        L.append("        if (ci == %d) {" % ci)
        for s, rid in sorted(made[ci]["sizes"].items()):
            L.append("            if (s == %d) { return Rez.Drawables.%s; }" % (s, rid))
        L.append("        }")
    L += ["        return null;", "    }", "",
          "    // AOD 외곽선 비트맵 (배율 %d)" % AOD_SCALE,
          "    function aod(ci as Number) as ResourceId or Null {"]
    for ci in sorted(made):
        L.append("        if (ci == %d) { return Rez.Drawables.%s; }" % (ci, made[ci]["aod"]))
    L += ["        return null;", "    }", "}", ""]
    with open(os.path.join(ROOT, "source", "Assets.mc"), "w", encoding="utf-8") as f:
        f.write("\n".join(L))

    # ---- preview/assets.js ----
    with open(os.path.join(ROOT, "preview", "assets.js"), "w", encoding="utf-8") as f:
        f.write("// 자동 생성 파일 - tools/fetch_assets.py (커밋하지 않음)\n")
        f.write("window.ASSET_DATA = {\n")
        for ci in sorted(preview):
            sizes = ", ".join('"%d": "%s"' % (s, u) for s, u in sorted(preview[ci]["sizes"].items()))
            f.write('  "%d": { "sizes": { %s }, "aod": "%s" },\n' % (ci, sizes, preview[ci]["aod"]))
        f.write("};\n")

    log("완료: 에셋 캐릭터 %s" % (", ".join(SOURCES[c]["name"] for c in sorted(made)) or "없음"))


if __name__ == "__main__":
    sys.exit(main())
