#!/usr/bin/env python3
"""
리소스 교차 검사 (SDK 없이). 컴파일 전에 흔한 실수를 잡는다.
전체판(monkey.jungle)과 스토어판(store.jungle)을 각각 검사한다.

  1. 코드의 Rez.Strings.* / Rez.Drawables.* 가 리소스 XML 에 있는지
  2. 영어 / 한국어 문자열 키가 같은지
  3. settings.xml 의 @Strings / @Properties 참조가 있는지
  4. Settings.mc 의 KEYS / COUNTS / DEFAULTS 가 properties.xml, settings.xml 과 맞는지
  5. 미리보기(preview/index.html) 의 선택지 수가 COUNTS 와 맞는지 (전체판)
  6. 매니페스트 / jungle 경로, 스프라이트 런 인코딩 범위
  7. 스토어판에 오리지널이 아닌 캐릭터가 섞이지 않았는지

사용법:  python tools/check_resources.py      (문제가 있으면 exit 1)
"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors = []

VARIANTS = [
    {"name": "전체판", "jungle": "monkey.jungle", "manifest": "manifest.xml", "src": "source-full", "res": "resources-full"},
    {"name": "스토어판", "jungle": "store.jungle", "manifest": "manifest-store.xml", "src": "source-store", "res": "resources-store"},
]
# 스토어판에 들어가면 안 되는 이름 (원작자 권리 확인 필요)
NOT_FOR_STORE = ["Dorongi", "dorongi"]
# 저장소 어디에도 들어가면 안 되는 말 (저작권 문제로 제거한 캐릭터·에셋 출처).
# 대소문자 무시. 이 파일 자체와 git 기록은 검사하지 않는다.
BANNED = [b"pok\xc3\xa9mon", b"pokemon", b"pokeapi", b"squirtle", b"charmander", b"nintendo",
          "포켓몬".encode(), "꼬부기".encode(), "파이리".encode(), "닌텐도".encode()]
SKIP_DIRS = {".git", "node_modules", "__pycache__", "cache", "out"}


def err(msg):
    errors.append(msg)


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def string_ids(path):
    return {e.get("id"): (e.text or "") for e in ET.parse(os.path.join(ROOT, path)).getroot().iter("string")}


def check_strings(v):
    eng = string_ids("resources/strings/strings.xml")
    kor = string_ids("resources-kor/strings/strings.xml")
    for p in glob.glob(os.path.join(ROOT, v["res"], "strings", "*.xml")):
        eng.update(string_ids(os.path.relpath(p, ROOT)))
    for p in glob.glob(os.path.join(ROOT, v["res"] + "-kor", "strings", "*.xml")):
        kor.update(string_ids(os.path.relpath(p, ROOT)))
    tag = "[%s] " % v["name"]
    for k in sorted(set(eng) - set(kor)):
        err(tag + "한국어 문자열에 없음: %s" % k)
    for k in sorted(set(kor) - set(eng)):
        err(tag + "영어(기본) 문자열에 없음: %s" % k)
    for k, val in kor.items():
        if not val.strip():
            err(tag + "빈 한국어 문자열: %s" % k)
    return eng


def settings_arrays(sm):
    def arr(name, kind):
        mm = re.search(r"var %s as Array<%s> = \[(.*?)\]" % (name, kind), sm, re.S)
        if not mm:
            err("Settings.mc 에서 %s 를 못 찾음" % name)
            return []
        body = mm.group(1)
        return re.findall(r'"(\w+)"', body) if kind == "String" else [int(x) for x in re.findall(r"-?\d+", body)]
    return arr("KEYS", "String"), arr("COUNTS", "Number"), arr("DEFAULTS", "Number"), arr("vals", "Number")


def check_variant(v, eng):
    tag = "[%s] " % v["name"]
    files = glob.glob(os.path.join(ROOT, "source", "*.mc")) + glob.glob(os.path.join(ROOT, v["src"], "*.mc"))
    src = {os.path.relpath(x, ROOT): read(os.path.relpath(x, ROOT)) for x in files}
    code = "\n".join(src.values())

    # jungle
    jungle = read(v["jungle"])
    for d in (v["src"], v["res"]):
        if d not in jungle:
            err(tag + "%s 에 %s 경로가 없음" % (v["jungle"], d))
    if not os.path.exists(os.path.join(ROOT, v["src"], "Assets.mc")):
        err(tag + "%s/Assets.mc 가 없음 (python tools/fetch_assets.py 를 실행하세요)" % v["src"])

    # 문자열 참조
    for name in sorted(set(re.findall(r"Rez\.Strings\.(\w+)", code))):
        if name not in eng:
            err(tag + "코드에서 쓰는 Rez.Strings.%s 가 strings.xml 에 없음" % name)

    # 드로어블
    drawables = set()
    for p in glob.glob(os.path.join(ROOT, "resources", "drawables", "*.xml")) + \
            glob.glob(os.path.join(ROOT, v["res"], "drawables", "*.xml")):
        for e in ET.parse(p).getroot():
            drawables.add(e.get("id"))
            fn = e.get("filename")
            if fn and not os.path.exists(os.path.join(os.path.dirname(p), fn)):
                err(tag + "드로어블 파일 없음: %s (%s)" % (fn, os.path.relpath(p, ROOT)))
    for name in sorted(set(re.findall(r"Rez\.Drawables\.(\w+)", code))):
        if name not in drawables:
            err(tag + "코드에서 쓰는 Rez.Drawables.%s 가 drawables XML 에 없음" % name)
    manifest = read(v["manifest"])
    m = re.search(r'launcherIcon="@Drawables\.(\w+)"', manifest)
    if m and m.group(1) not in drawables:
        err(tag + "manifest 런처 아이콘 %s 가 없음" % m.group(1))
    m = re.search(r'name="@Strings\.(\w+)"', manifest)
    if m and m.group(1) not in eng:
        err(tag + "manifest 앱 이름 문자열 %s 가 없음" % m.group(1))

    # 설정 XML
    props = {}
    for e in ET.parse(os.path.join(ROOT, v["res"], "settings", "properties.xml")).getroot().iter("property"):
        props[e.get("id")] = (e.get("type"), (e.text or "").strip())
    settings = {}
    for s in ET.parse(os.path.join(ROOT, v["res"], "settings", "settings.xml")).getroot().iter("setting"):
        key = s.get("propertyKey", "").replace("@Properties.", "")
        if key not in props:
            err(tag + "settings.xml 이 없는 속성을 참조: %s" % key)
        title = s.get("title", "").replace("@Strings.", "")
        if title not in eng:
            err(tag + "settings.xml 제목 문자열 없음: %s" % title)
        entries = []
        for le in s.iter("listEntry"):
            sid = (le.text or "").strip().replace("@Strings.", "")
            if sid not in eng:
                err(tag + "settings.xml 선택지 문자열 없음: %s (%s)" % (sid, key))
            entries.append(int(le.get("value")))
        if entries and entries != list(range(len(entries))):
            err(tag + "%s 선택지 값이 0부터 연속이 아님: %s" % (key, entries))
        settings[key] = len(entries)
    for k in props:
        if k not in settings:
            err(tag + "속성 %s 에 대한 설정 화면 항목이 없음" % k)

    # Settings.mc 와 비교
    sm = read("source/Settings.mc")
    keys, counts, defaults, vals = settings_arrays(sm)
    if not (len(keys) == len(counts) == len(defaults) == len(vals)):
        err("Settings.mc KEYS/COUNTS/DEFAULTS/vals 길이가 다름: %d/%d/%d/%d" % (len(keys), len(counts), len(defaults), len(vals)))
    lc = re.search(r"const LIST_COUNT = (\d+);", sm)
    if lc and int(lc.group(1)) != len(keys):
        err("LIST_COUNT(%s) != KEYS 개수(%d)" % (lc.group(1), len(keys)))
    sp = read(os.path.join(v["src"], "Sprites.mc"))
    cc = int(re.search(r"const CHARACTER_COUNT = (\d+);", sp).group(1))
    names = re.findall(r"Rez\.Strings\.(\w+)", re.search(r"function characterNames\(\).*?\}", sp, re.S).group(0))
    if len(names) != cc:
        err(tag + "characterNames() 개수(%d) != CHARACTER_COUNT(%d)" % (len(names), cc))
    counts = list(counts)
    if "Character" in keys:
        counts[keys.index("Character")] = cc + 1 if cc > 1 else 1
    for i, k in enumerate(keys):
        if k not in props:
            if k == "Character" and cc == 1:
                continue   # 스토어판: 캐릭터 설정 없음
            err(tag + "Settings.mc 키 %s 가 properties.xml 에 없음" % k)
            continue
        t, val = props[k]
        if t != "number":
            err(tag + "속성 %s 는 number 여야 함 (%s)" % (k, t))
        if i < len(defaults) and val != str(defaults[i]):
            err(tag + "속성 %s 기본값 불일치: properties.xml=%s, Settings.mc=%d" % (k, val, defaults[i]))
        if i < len(counts) and settings.get(k) != counts[i]:
            err(tag + "속성 %s 선택지 수 불일치: settings.xml=%s, 코드=%d" % (k, settings.get(k), counts[i]))
        if i < len(vals) and i < len(defaults) and vals[i] != defaults[i]:
            err("Settings.mc vals[%d] 초기값이 DEFAULTS 와 다름 (%s)" % (i, k))
    for i, k in enumerate(keys):
        const = None
        for name, idx in re.findall(r"const (\w+) = (\d+);", sm):
            if int(idx) == i and name != "LIST_COUNT" and not name.startswith("DATA_"):
                const = name
                break
        mm = re.search(r"i == %s\) \{\s*return \[(.*?)\]" % const, sm, re.S) if const else None
        if mm and i < len(counts):
            n = len(re.findall(r"Rez\.Strings\.\w+", mm.group(1)))
            if n != counts[i]:
                err("labels(%s) 선택지 %d개 != COUNTS %d" % (const, n, counts[i]))
    for k, (t, _) in props.items():
        if t == "boolean" and ('getBool("%s"' % k) not in sm:
            err(tag + "boolean 속성 %s 를 Settings.mc 에서 읽지 않음" % k)

    # 스프라이트 런 인코딩
    for w in re.findall(r"var W as Array<Number> = \[(.*?)\]", sp):
        for x in w.split(","):
            if int(x) > 63:
                err(tag + "스프라이트 폭 %s 가 런 인코딩 한계(63)를 넘음" % x)

    # 스토어판 저작권 점검
    if v["src"] == "source-store":
        store_text = "\n".join(src.values()) + read("resources/strings/strings.xml") + \
            read("resources-kor/strings/strings.xml") + \
            read(os.path.join(v["res"], "settings", "settings.xml")) + \
            "\n".join(read(os.path.relpath(p, ROOT)) for p in glob.glob(os.path.join(ROOT, v["res"], "**", "*.xml"), recursive=True))
        for bad in NOT_FOR_STORE:
            if bad in store_text:
                err(tag + "스토어판에 '%s' 가 들어 있음" % bad)
        if glob.glob(os.path.join(ROOT, v["res"], "drawables", "assets", "*")):
            err(tag + "스토어판 리소스에 외부 에셋이 있음")

    return keys, counts


def check_preview(keys, counts):
    html = read("preview/index.html")
    key_map = {"Style": "style", "Character": "character", "CharStyle": "charStyle", "CharSize": "charSize",
               "Background": "background", "Accent": "accent", "TimeColor": "timeColor", "Ring": "ring",
               "DateLang": "dateLang", "SleepAt": "sleepAt", "WakeAt": "wakeAt", "Scenery": "scenery"}
    names = re.findall(r"'[^']*'", re.search(r"const NAMES = \[(.*?)\]", html).group(1))
    for i, k in enumerate(keys):
        jk = key_map.get(k)
        if not jk:
            continue
        mm = re.search(r"key: '%s', label: '[^']*', items: (\[[^\]]*\]|\w+)" % jk, html)
        if not mm:
            err("미리보기 OPTIONS 에 %s 가 없음" % jk)
            continue
        items = mm.group(1)
        if not items.startswith("["):   # 변수 이름이면 그 정의를 읽음
            dm = re.search(r"const %s = (\[[^\]]*\])" % items, html)
            items = dm.group(1) if dm else "[]"
        n = len(re.findall(r"'[^']*'", items)) + (len(names) if "...NAMES" in items else 0)
        if n != counts[i]:
            err("미리보기 %s 선택지 %d개 != 전체판 %d" % (jk, n, counts[i]))
    dm = re.search(r"const DATA = \[(.*?)\];", html)
    if dm and "Slot1" in keys:
        n = len(re.findall(r"'[^']*'", dm.group(1)))
        if n != counts[keys.index("Slot1")]:
            err("미리보기 정보 칸 선택지 %d개 != COUNTS %d" % (n, counts[keys.index("Slot1")]))


def check_banned():
    me = os.path.abspath(__file__)
    for dirpath, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            path = os.path.join(dirpath, f)
            if os.path.abspath(path) == me or f.endswith((".png", ".prg", ".iq", ".der")):
                continue
            try:
                data = open(path, "rb").read().lower()
            except OSError:
                continue
            for b in BANNED:
                if b in data:
                    err("저작권 문제로 제거한 내용이 남아 있음: '%s' (%s)" % (b.decode(), os.path.relpath(path, ROOT)))


def main():
    check_banned()
    full = None
    for v in VARIANTS:
        eng = check_strings(v)
        r = check_variant(v, eng)
        if full is None:
            full = r
    check_preview(*full)

    if errors:
        print("리소스 검사: %d개 문제" % len(errors))
        for e in errors:
            print("  - " + e)
        return 1
    print("리소스 검사: 문제 없음 (전체판 + 스토어판, 문자열 %d개)" % len(eng))
    return 0


if __name__ == "__main__":
    sys.exit(main())
