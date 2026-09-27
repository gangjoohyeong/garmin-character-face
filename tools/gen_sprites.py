#!/usr/bin/env python3
"""
스프라이트 / 픽셀폰트 생성기.

여기서 정의한 픽셀 그림을 두 곳으로 내보낸다.
  - source/Sprites.mc   (워치 코드)
  - preview/sprites.js  (브라우저 미리보기)
두 결과물이 같은 데이터를 쓰므로 워치와 미리보기의 그림이 항상 일치한다.

사용법:  python tools/gen_sprites.py

런(run) 인코딩: 한 가로줄의 같은 색 연속 픽셀을 하나의 Number로 묶는다.
  value = x | (y << 6) | (w << 12) | (colorIndex << 18)
팔레트 인덱스 0 = 투명, 1 = 외곽선(K) 으로 고정 (AOD에서 외곽선만 그릴 때 사용).
"""
import json
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# 캐릭터 정의
#   grid   : 얼굴(눈/입)이 없는 기본 몸체
#   eyes / mouths : 패치 목록 (row, col, 문자열)  '_' = 기존 픽셀 유지
#   frames : 프레임 이름 -> 적용할 패치 목록
# ---------------------------------------------------------------------------

MOCHI = {
    "name": "mochi",
    "palette": {
        "K": 0x2B2B3A, "W": 0xFFF8EE, "S": 0xE6D5C3, "P": 0xFF9BB3,
        "G": 0x6CC56C, "R": 0xE0506A,
    },
    "grid": [
        "..........KK..........",
        ".........KGGK.........",
        "........KGGK..........",
        ".......KKKKKKKK.......",
        ".....KKWWWWWWWWKK.....",
        "....KWWWWWWWWWWWWK....",
        "...KWWWWWWWWWWWWWWK...",
        "..KWWWWWWWWWWWWWWWWK..",
        "..KWWWWWWWWWWWWWWWWK..",
        ".KWWWWWWWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWWWWWWWK.",
        "KWWWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWWWK",
        "KWWWWWWWWWWWWWWWWWWWWK",
        "KSWWWWWWWWWWWWWWWWWWSK",
        ".KSSWWWWWWWWWWWWWWSSK.",
        "..KKSSSSSSSSSSSSSSKK..",
        "....KKKKKKKKKKKKKK....",
    ],
    "common": [(12, 3, "PPP"), (12, 16, "PPP")],
    "eyes": {
        "open":  [(9, 6, "KK"), (10, 6, "KK"), (11, 6, "KK"),
                  (9, 14, "KK"), (10, 14, "KK"), (11, 14, "KK")],
        "blink": [(10, 6, "KK"), (10, 14, "KK")],
        "sleep": [(10, 5, "K__K"), (11, 6, "KK"), (10, 13, "K__K"), (11, 14, "KK")],
    },
    "mouths": {
        "smile": [(12, 9, "K__K"), (13, 10, "KK")],
        "yawn":  [(12, 10, "KK"), (13, 9, "KRRK"), (14, 10, "KK")],
        "small": [(13, 10, "KK")],
    },
    "head": (4, 16),          # 머리 위 기준점 (row, col) - Zzz 위치용
}

SQUIRTLE = {
    "name": "squirtle",
    "palette": {
        "K": 0x23303D, "B": 0x7FCBEA, "b": 0x4E9FC6, "S": 0xB8733A,
        "Y": 0xF5E3A3, "y": 0xDCC47E, "E": 0x4A1C1C, "W": 0xFFFFFF,
        "R": 0xE0506A,
    },
    "grid": [
        "......KKKKKKKKKK......",
        "....KKBBBBBBBBBBKK....",
        "...KBBBBBBBBBBBBBBK...",
        "..KBBBBBBBBBBBBBBBBK..",
        "..KBBBBBBBBBBBBBBBBK..",
        ".KBBBBBBBBBBBBBBBBBBK.",
        ".KBBBBBBBBBBBBBBBBBBK.",
        ".KBBBBBBBBBBBBBBBBBBK.",
        ".KBBBBBBBBBBBBBBBBBBK.",
        "..KBBBBBBBBBBBBBBBBK..",
        "..KbBBBBBBBBBBBBBBbK..",
        "...KKbbBBBBBBBBbbKK...",
        "..KSSKKKKKKKKKKKKSSK..",
        ".KBKSSYYYYYYYYYYSSKBK.",
        "KBBKSYYYYYYYYYYYYSKBBK",
        "KBBKSyyyyyyyyyyyySKBBK",
        ".KKKSYYYYYYYYYYYYSKKK.",
        "...KSSYYYYYYYYYYSSK...",
        "...KBBSSSSSSSSSSBBK...",
        "..KBBBBK......KBBBBK..",
        "..KKKKKK......KKKKKK..",
    ],
    "common": [],
    "eyes": {
        "open":  [(5, 5, "EEE"), (6, 5, "EWE"), (7, 5, "EEE"), (8, 5, "EEE"),
                  (5, 14, "EEE"), (6, 14, "EWE"), (7, 14, "EEE"), (8, 14, "EEE")],
        "blink": [(7, 5, "KKK"), (7, 14, "KKK")],
        "sleep": [(7, 5, "K_K"), (8, 6, "K"), (7, 14, "K_K"), (8, 15, "K")],
    },
    "mouths": {
        "smile": [(9, 9, "K__K"), (10, 10, "KK")],
        "yawn":  [(9, 10, "KK"), (10, 9, "KRRK"), (11, 10, "KK")],
        "small": [(10, 10, "KK")],
    },
    "head": (1, 17),
}

CHARMANDER = {
    "name": "charmander",
    "palette": {
        "K": 0x3A2320, "O": 0xF4893A, "o": 0xCF6420, "Y": 0xF7E08A,
        "R": 0xE8402A, "F": 0xFFD23F, "W": 0xFFFFFF, "M": 0xC8324A,
    },
    "grid": [
        ".......KKKKKKK........",
        ".....KKOOOOOOOKK......",
        "....KOOOOOOOOOOOK.....",
        "...KOOOOOOOOOOOOOK....",
        "...KOOOOOOOOOOOOOK....",
        "..KOOOOOOOOOOOOOOOK...",
        "..KOOOOOOOOOOOOOOOK...",
        "..KOOOOOOOOOOOOOOOK...",
        "..KOOOOOOOOOOOOOOOK...",
        "...KOOOOOOOOOOOOOK....",
        "...KoOOOOOOOOOOOoK....",
        "....KKooOOOOOooKK.....",
        "...KOOKKKKKKKKKOOK....",
        "..KOKOYYYYYYYYOKOKKOK.",
        ".KOOKOYYYYYYYYYOKOOOK.",
        ".KOOKOYYYYYYYYYOKOOK..",
        "..KKKOYYYYYYYYYOKKK...",
        "....KOOYYYYYYYOOKK....",
        "....KOOOOOOOOOOOK.....",
        "...KOOOOK...KOOOOK....",
        "...KKKKKK...KKKKKK....",
    ],
    # 꼬리 불꽃 (A = 기본, B = 깜빡임 - 모양은 같고 색만 다름)
    "common": [(7, 20, "R"), (8, 19, "RR"), (9, 19, "RFR"), (10, 19, "RFR"),
               (11, 19, "RFR"), (12, 19, "RR")],
    "extra": [(7, 20, "F"), (8, 19, "RF"), (9, 19, "FFR"), (10, 19, "RFF"),
              (11, 19, "FFR"), (12, 19, "FR")],
    "eyes": {
        "open":  [(5, 6, "KW"), (6, 6, "KK"), (7, 6, "KK"),
                  (5, 13, "KW"), (6, 13, "KK"), (7, 13, "KK")],
        "blink": [(7, 6, "KK"), (7, 13, "KK")],
        "sleep": [(6, 5, "K__K"), (7, 6, "KK"), (6, 12, "K__K"), (7, 13, "KK")],
    },
    "mouths": {
        "smile": [(9, 8, "K___K"), (10, 9, "KKK")],
        "yawn":  [(9, 9, "KKK"), (10, 8, "KMMMK"), (11, 9, "KKK")],
        "small": [(10, 9, "KKK")],
    },
    "head": (0, 15),
}

CHARACTERS = [MOCHI, SQUIRTLE, CHARMANDER]

# 프레임 순서 (워치 코드의 FRAME_* 상수와 일치해야 함)
FRAMES = [
    ("open", "smile"),   # 0 기본
    ("blink", "smile"),  # 1 깜빡
    ("sleep", "yawn"),   # 2 하품
    ("sleep", "small"),  # 3 수면
]


def apply(grid, patches):
    g = [list(r) for r in grid]
    for (r, c, s) in patches:
        for i, ch in enumerate(s):
            if ch != "_":
                g[r][c + i] = ch
    return ["".join(r) for r in g]


def palette_order(ch):
    keys = ["K"] + [k for k in ch["palette"] if k != "K"]
    return keys


def runs_of(grid, keys, only_diff_from=None):
    """grid -> 런 리스트 (색 인덱스 순 정렬 → setColor 호출 최소화)."""
    out = []
    for y, row in enumerate(grid):
        x = 0
        while x < len(row):
            ch = row[x]
            differs = only_diff_from is None or only_diff_from[y][x] != ch
            if ch == "." or not differs:
                x += 1
                continue
            st = x
            while x < len(row) and row[x] == ch and (
                    only_diff_from is None or only_diff_from[y][x] != ch):
                x += 1
            ci = keys.index(ch) + 1
            out.append((ci, st, y, x - st))
    out.sort(key=lambda t: (t[0], t[2], t[1]))
    return [x | (y << 6) | (w << 12) | (c << 18) for (c, x, y, w) in out]


def build_character(ch):
    grid = ch["grid"]
    w = len(grid[0])
    for i, r in enumerate(grid):
        assert len(r) == w, f"{ch['name']} row {i} width {len(r)} != {w}"
    keys = palette_order(ch)
    body = apply(grid, ch["common"])
    frames = [apply(body, ch["eyes"][e] + ch["mouths"][m]) for (e, m) in FRAMES]
    base = frames[0]
    data = {
        "w": w,
        "h": len(grid),
        "pal": [0] + [ch["palette"][k] for k in keys],
        "base": runs_of(base, keys),
        # 프레임 1..3 은 기본 프레임 위에 덧그리는 차이분만 저장
        "face": [runs_of(f, keys, base) for f in frames[1:]],
        "extra": [],
        "head": list(ch["head"]),
    }
    if "extra" in ch:
        ex = apply(base, ch["extra"])
        data["extra"] = runs_of(ex, keys, base)
    return data


# ---------------------------------------------------------------------------
# 픽셀 폰트
# ---------------------------------------------------------------------------
BIG = {  # 5x7 숫자
    "0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
}

SMALL = {  # 3x5
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", "..#", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    "%": ["#.#", "..#", ".#.", "#..", "#.#"],
    "/": ["..#", "..#", ".#.", "#..", "#.."],
    "-": ["...", "...", "###", "...", "..."],
    ".": ["...", "...", "...", "...", ".#."],
    ":": ["...", ".#.", "...", ".#.", "..."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    " ": ["...", "...", "...", "...", "..."],
}

ICONS = {  # 5x5 (순서: 워치 코드의 ICON_* 상수)
    "heart": [".#.#.", "#####", "#####", ".###.", "..#.."],
    "bolt":  ["...#.", "..##.", ".###.", ".##..", ".#..."],
    "steps": [".##..", ".##..", "...##", "##.##", "##..."],
    "batt":  ["####.", "#..##", "#..##", "#..##", "####."],
}
ICON_ORDER = ["heart", "bolt", "steps", "batt"]


def bits(rows):
    v = 0
    wdt = len(rows[0])
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == "#":
                v |= 1 << (r * wdt + c)
    return v


def row_masks(rows):
    return [sum(1 << c for c, ch in enumerate(row) if ch == "#") for row in rows]


def write_png(path, pix):
    h = len(pix)
    w = len(pix[0])
    raw = b"".join(b"\0" + bytes(v for p in row for v in p) for row in pix)

    def chunk(t, b):
        return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def write_icon(c, path, size=70, s=3):
    """앱 아이콘: 하늘색 원 위에 캐릭터."""
    pix = [[(0, 0, 0, 0)] * size for _ in range(size)]
    r = size / 2
    for y in range(size):
        for x in range(size):
            if (x + 0.5 - r) ** 2 + (y + 0.5 - r) ** 2 <= r * r:
                pix[y][x] = (0x75, 0xC6, 0xF9, 255) if y < size * 0.68 else (0x6C, 0xCB, 0x4E, 255)
    ox = (size - c["w"] * s) // 2
    oy = int(size * 0.72) - c["h"] * s
    for v in c["base"]:
        x, y, w, ci = v & 63, (v >> 6) & 63, (v >> 12) & 63, (v >> 18) & 15
        col = c["pal"][ci]
        rgba = ((col >> 16) & 255, (col >> 8) & 255, col & 255, 255)
        for yy in range(y * s, (y + 1) * s):
            for xx in range(x * s, (x + w) * s):
                if 0 <= oy + yy < size and 0 <= ox + xx < size:
                    pix[oy + yy][ox + xx] = rgba
    write_png(path, pix)


def main():
    chars = [build_character(c) for c in CHARACTERS]
    small_chars = "".join(SMALL.keys())
    font = {
        "big": [row_masks(BIG[str(d)]) for d in range(10)],
        "chars": small_chars,
        "small": [bits(SMALL[c]) for c in small_chars],
        "icons": [bits(ICONS[k]) for k in ICON_ORDER],
    }

    # ---- Monkey C ----
    def arr(a):
        return "[" + ", ".join(str(x) for x in a) + "]"

    def hexarr(a):
        return "[" + ", ".join("0x%06X" % x for x in a) + "]"

    L = []
    L.append("// 자동 생성 파일 - 직접 수정하지 말 것 (tools/gen_sprites.py)")
    L.append("import Toybox.Lang;")
    L.append("")
    L.append("module Sprites {")
    L.append("    // 캐릭터: 0 모찌, 1 꼬부기, 2 파이리")
    L.append("    var W as Array<Number> = %s;" % arr([c["w"] for c in chars]))
    L.append("    var H as Array<Number> = %s;" % arr([c["h"] for c in chars]))
    L.append("    var HEAD as Array = [%s];" % ", ".join(arr(c["head"]) for c in chars))
    L.append("    var PAL as Array = [")
    for c in chars:
        L.append("        %s," % hexarr(c["pal"]))
    L.append("    ];")
    L.append("    var BASE as Array = [")
    for c in chars:
        L.append("        %s," % arr(c["base"]))
    L.append("    ];")
    L.append("    // 프레임 1(깜빡) 2(하품) 3(수면) 차이분")
    L.append("    var FACE as Array = [")
    for c in chars:
        L.append("        [%s]," % ", ".join(arr(f) for f in c["face"]))
    L.append("    ];")
    L.append("    var EXTRA as Array = [%s];" % ", ".join(arr(c["extra"]) for c in chars))
    L.append("")
    L.append("    // 픽셀 폰트")
    L.append("    var BIG as Array = [%s];" % ", ".join(arr(d) for d in font["big"]))
    L.append('    var CHARS as String = "%s";' % font["chars"])
    L.append("    var SMALL as Array<Number> = %s;" % arr(font["small"]))
    L.append("    var ICONS as Array<Number> = %s;" % arr(font["icons"]))
    L.append("}")
    L.append("")
    with open(os.path.join(ROOT, "source", "Sprites.mc"), "w", encoding="utf-8") as f:
        f.write("\n".join(L))

    # ---- JS ----
    js = {"chars": chars, "font": font}
    os.makedirs(os.path.join(ROOT, "preview"), exist_ok=True)
    with open(os.path.join(ROOT, "preview", "sprites.js"), "w", encoding="utf-8") as f:
        f.write("// 자동 생성 파일 - tools/gen_sprites.py\n")
        f.write("window.SPRITES = " + json.dumps(js) + ";\n")

    write_icon(chars[0], os.path.join(ROOT, "resources", "drawables", "launcher_icon.png"))

    total = sum(len(c["base"]) + sum(len(x) for x in c["face"]) + len(c["extra"]) for c in chars)
    print("OK: %d characters, %d runs total" % (len(chars), total))


if __name__ == "__main__":
    main()
