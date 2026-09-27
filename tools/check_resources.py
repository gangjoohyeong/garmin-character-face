#!/usr/bin/env python3
"""
리소스 교차 검사 (SDK 없이). 컴파일 전에 흔한 실수를 잡는다.

  1. 코드의 Rez.Strings.* / Rez.Drawables.* 가 리소스 XML 에 있는지
  2. 영어 / 한국어 문자열 키가 같은지
  3. settings.xml 의 @Strings / @Properties 참조가 있는지
  4. Settings.mc 의 KEYS / COUNTS / DEFAULTS 가 properties.xml, settings.xml 과 맞는지
  5. 미리보기(preview/index.html) 의 선택지 수가 COUNTS 와 맞는지
  6. manifest 의 런처 아이콘 / 스프라이트 런 인코딩 범위

사용법:  python tools/check_resources.py      (문제가 있으면 exit 1)
"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors = []


def err(msg):
    errors.append(msg)


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def string_ids(path):
    return {e.get("id"): (e.text or "") for e in ET.parse(os.path.join(ROOT, path)).getroot().iter("string")}


def main():
    src = {p: read(p) for p in (os.path.relpath(x, ROOT) for x in glob.glob(os.path.join(ROOT, "source", "*.mc")))}
    code = "\n".join(src.values())

    # ---- 1/2. 문자열 ----
    eng = string_ids("resources/strings/strings.xml")
    kor = string_ids("resources-kor/strings/strings.xml")
    for k in sorted(set(eng) - set(kor)):
        err("한국어 문자열에 없음: %s" % k)
    for k in sorted(set(kor) - set(eng)):
        err("영어(기본) 문자열에 없음: %s" % k)
    for k, v in kor.items():
        if not v.strip():
            err("빈 한국어 문자열: %s" % k)
    for name in sorted(set(re.findall(r"Rez\.Strings\.(\w+)", code))):
        if name not in eng:
            err("코드에서 쓰는 Rez.Strings.%s 가 strings.xml 에 없음" % name)

    # ---- 드로어블 ----
    drawables = set()
    for p in glob.glob(os.path.join(ROOT, "resources", "drawables", "*.xml")):
        for e in ET.parse(p).getroot():
            drawables.add(e.get("id"))
            fn = e.get("filename")
            if fn and not os.path.exists(os.path.join(os.path.dirname(p), fn)):
                err("드로어블 파일 없음: %s (%s)" % (fn, os.path.relpath(p, ROOT)))
    for name in sorted(set(re.findall(r"Rez\.Drawables\.(\w+)", code))):
        if name not in drawables:
            err("코드에서 쓰는 Rez.Drawables.%s 가 drawables XML 에 없음 (fetch_assets.py 를 실행했나요?)" % name)
    manifest = read("manifest.xml")
    m = re.search(r'launcherIcon="@Drawables\.(\w+)"', manifest)
    if m and m.group(1) not in drawables:
        err("manifest 런처 아이콘 %s 가 없음" % m.group(1))

    # ---- 3. 설정 XML ----
    props = {}
    for e in ET.parse(os.path.join(ROOT, "resources/settings/properties.xml")).getroot().iter("property"):
        props[e.get("id")] = (e.get("type"), (e.text or "").strip())
    settings = {}
    for s in ET.parse(os.path.join(ROOT, "resources/settings/settings.xml")).getroot().iter("setting"):
        key = s.get("propertyKey", "").replace("@Properties.", "")
        if key not in props:
            err("settings.xml 이 없는 속성을 참조: %s" % key)
        title = s.get("title", "").replace("@Strings.", "")
        if title not in eng:
            err("settings.xml 제목 문자열 없음: %s" % title)
        entries = []
        for le in s.iter("listEntry"):
            sid = (le.text or "").strip().replace("@Strings.", "")
            if sid not in eng:
                err("settings.xml 선택지 문자열 없음: %s (%s)" % (sid, key))
            entries.append(int(le.get("value")))
        if entries and entries != list(range(len(entries))):
            err("%s 선택지 값이 0부터 연속이 아님: %s" % (key, entries))
        settings[key] = len(entries)
    for k in props:
        if k not in settings:
            err("속성 %s 에 대한 설정 화면 항목이 없음" % k)

    # ---- 4. Settings.mc 와 비교 ----
    sm = src.get(os.path.join("source", "Settings.mc"), "")

    def arr(name, kind):
        mm = re.search(r"var %s as Array<%s> = \[(.*?)\]" % (name, kind), sm, re.S)
        if not mm:
            err("Settings.mc 에서 %s 를 못 찾음" % name)
            return []
        body = mm.group(1)
        return re.findall(r'"(\w+)"', body) if kind == "String" else [int(x) for x in re.findall(r"-?\d+", body)]

    keys, counts, defaults = arr("KEYS", "String"), arr("COUNTS", "Number"), arr("DEFAULTS", "Number")
    vals = arr("vals", "Number")
    if not (len(keys) == len(counts) == len(defaults) == len(vals)):
        err("Settings.mc KEYS/COUNTS/DEFAULTS/vals 길이가 다름: %d/%d/%d/%d" % (len(keys), len(counts), len(defaults), len(vals)))
    lc = re.search(r"const LIST_COUNT = (\d+);", sm)
    if lc and int(lc.group(1)) != len(keys):
        err("LIST_COUNT(%s) != KEYS 개수(%d)" % (lc.group(1), len(keys)))
    for i, k in enumerate(keys):
        if k not in props:
            err("Settings.mc 키 %s 가 properties.xml 에 없음" % k)
            continue
        t, v = props[k]
        if t != "number":
            err("속성 %s 는 number 여야 함 (%s)" % (k, t))
        if i < len(defaults) and v != str(defaults[i]):
            err("속성 %s 기본값 불일치: properties.xml=%s, Settings.mc=%d" % (k, v, defaults[i]))
        if i < len(counts) and settings.get(k) != counts[i]:
            err("속성 %s 선택지 수 불일치: settings.xml=%s, Settings.mc=%d" % (k, settings.get(k), counts[i]))
        if i < len(vals) and i < len(defaults) and vals[i] != defaults[i]:
            err("Settings.mc vals[%d] 초기값이 DEFAULTS 와 다름 (%s)" % (i, k))
    # labels() 선택지 수
    for i, k in enumerate(keys):
        const = None
        for name, idx in re.findall(r"const (\w+) = (\d+);", sm):
            if int(idx) == i and name not in ("LIST_COUNT", "CHARACTER_COUNT") and not name.startswith("DATA_"):
                const = name
                break
        mm = re.search(r"i == %s\) \{\s*return \[(.*?)\]" % const, sm, re.S) if const else None
        if mm and i < len(counts):
            n = len(re.findall(r"Rez\.Strings\.\w+", mm.group(1)))
            if n != counts[i]:
                err("labels(%s) 선택지 %d개 != COUNTS %d" % (const, n, counts[i]))
    for k, (t, v) in props.items():
        if t == "boolean" and ('getBool("%s"' % k) not in sm:
            err("boolean 속성 %s 를 Settings.mc 에서 읽지 않음" % k)

    # ---- 5. 미리보기 ----
    html = read("preview/index.html")
    key_map = {"Style": "style", "Character": "character", "CharStyle": "charStyle", "CharSize": "charSize",
               "Background": "background", "Accent": "accent", "TimeColor": "timeColor", "Ring": "ring",
               "DateLang": "dateLang", "SleepAt": "sleepAt", "WakeAt": "wakeAt"}
    for i, k in enumerate(keys):
        jk = key_map.get(k)
        if not jk:
            continue
        mm = re.search(r"key: '%s', label: '[^']*', items: (\[[^\]]*\]|\w+)" % jk, html)
        if not mm:
            err("미리보기 OPTIONS 에 %s 가 없음" % jk)
            continue
        items = mm.group(1)
        if items.startswith("["):
            n = len(re.findall(r"'[^']*'", items)) + items.count("...NAMES")  * 0
            if "...NAMES" in items:
                n += len(re.findall(r"'[^']*'", re.search(r"const NAMES = \[(.*?)\]", html).group(1)))
            if n != counts[i]:
                err("미리보기 %s 선택지 %d개 != COUNTS %d" % (jk, n, counts[i]))

    dm = re.search(r"const DATA = \[(.*?)\];", html)
    if dm and "Slot1" in keys:
        n = len(re.findall(r"'[^']*'", dm.group(1)))
        if n != counts[keys.index("Slot1")]:
            err("미리보기 정보 칸 선택지 %d개 != COUNTS %d" % (n, counts[keys.index("Slot1")]))

    # ---- 6. 스프라이트 ----
    sp = read("source/Sprites.mc")
    for w in re.findall(r"var W as Array<Number> = \[(.*?)\]", sp):
        for v in w.split(","):
            if int(v) > 63:
                err("스프라이트 폭 %s 가 런 인코딩 한계(63)를 넘음" % v)

    if errors:
        print("리소스 검사: %d개 문제" % len(errors))
        for e in errors:
            print("  - " + e)
        return 1
    print("리소스 검사: 문제 없음 (문자열 %d, 속성 %d, 드로어블 %d)" % (len(eng), len(props), len(drawables)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
