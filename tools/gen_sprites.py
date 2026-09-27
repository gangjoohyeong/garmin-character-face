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
    "label": "CharMochi",
    "store": True,        # 오리지널 캐릭터 → 스토어판에 포함
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
        "happy": [(9, 6, "KK"), (10, 5, "K__K"), (9, 14, "KK"), (10, 13, "K__K")],
    },
    "mouths": {
        "smile": [(12, 9, "K__K"), (13, 10, "KK")],
        "yawn":  [(12, 10, "KK"), (13, 9, "KRRK"), (14, 10, "KK")],
        "small": [(13, 10, "KK")],
    },
    "head": (4, 16),          # 머리 위 기준점 (row, col) - Zzz 위치용
}

def build_dorongi_grid():
    """도롱이: 도형을 채운 뒤 빈 칸 중 4방향 이웃이 채워진 칸에 외곽선(K)을 두른다."""
    W, H = 26, 25
    g = [["."] * W for _ in range(H)]

    def put(r, c, ch):
        if 0 <= r < H and 0 <= c < W:
            g[r][c] = ch
    # 머리 (둥근 사각형)
    for y in range(H):
        for x in range(W):
            if (abs(x - 11.5) / 9.6) ** 2 + (abs(y - 5.3) / 5.2) ** 2 <= 1:
                put(y, x, "H")
    for y in range(9, 20):          # 몸
        for x in range(7, 17):
            put(y, x, "B")
    for y in range(11, 17):         # 팔
        for x in (4, 5, 18, 19):
            put(y, x, "B")
    for x in (3, 4, 5, 18, 19, 20):  # 손
        put(16, x, "B")
    for x in (3, 5, 18, 20):        # 손가락
        put(17, x, "B")
    for y in range(20, 23):         # 다리
        for x in (8, 9, 10, 14, 15, 16):
            put(y, x, "B")
    for x in (6, 7, 17, 18):        # 발
        put(22, x, "B")
    for x in (6, 8, 10, 14, 16, 18):  # 발가락
        put(23, x, "B")
    tail = {15: (24, 24), 16: (23, 24), 17: (22, 24), 18: (21, 24), 19: (17, 23), 20: (17, 22), 21: (18, 21)}
    for y, (a, b) in tail.items():
        for x in range(a, b + 1):
            put(y, x, "T")
    for (y, x) in [(17, 23), (19, 20), (20, 18), (18, 22), (16, 24)]:
        put(y, x, "S")
    for (y, x) in [(9, 8), (10, 9), (9, 15), (10, 14), (8, 6), (8, 17)]:
        put(y, x, "S")
    # 외곽선
    out = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if g[y][x] != ".":
                continue
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < H and 0 <= xx < W and g[yy][xx] != ".":
                    out[y][x] = "K"
                    break
    return ["".join(r) for r in out]


DORONGI = {
    "name": "dorongi",
    "label": "CharDorongi",
    "palette": {
        "K": 0x2B2A22, "H": 0xD8D49B, "B": 0xF4EFD3, "T": 0xE3E0A6,
        "S": 0xB5BF74, "W": 0xFFFFFF, "R": 0xE0506A,
    },
    "grid": build_dorongi_grid(),
    "common": [(5, 10, "K"), (5, 13, "K")],
    "eyes": {
        "open":  [(3, 5, "_WW_"), (4, 5, "WKKW"), (5, 5, "WKKW"), (6, 5, "_WW_"),
                  (3, 15, "_WW_"), (4, 15, "WKKW"), (5, 15, "WKKW"), (6, 15, "_WW_")],
        "blink": [(5, 5, "KKKK"), (5, 15, "KKKK")],
        "sleep": [(4, 5, "K__K"), (5, 6, "KK"), (4, 15, "K__K"), (5, 16, "KK")],
        "happy": [(4, 6, "KK"), (5, 5, "K__K"), (4, 16, "KK"), (5, 15, "K__K")],
    },
    "mouths": {
        "smile": [(7, 10, "KKKK")],
        "yawn":  [(7, 11, "KK"), (8, 10, "KRRK")],
        "small": [(7, 11, "KK")],
    },
    "head": (1, 20),
    "anchor": 11.5,       # 몸 중심 열 (꼬리 제외)
}

CHARACTERS = [MOCHI, DORONGI]


# ---------------------------------------------------------------------------
# 디지털(벡터) 캐릭터
#   100x100 상자 기준 좌표 (발바닥 y=100). 값은 0.1 단위 정수로 저장.
#   도형: [0 원, 색, x, y, r] / [1 타원, 색, x, y, rx, ry]
#         [4 호(선), 색, x, y, r, 굵기, 시작각, 끝각] (Garmin 기준: 0=3시, 반시계 +)
#         [5 선, 색, x1, y1, x2, y2, 굵기]
#   body   : 외곽선을 두르는 몸체 도형 (그리는 순서대로)
#   detail : 외곽선 없는 무늬 (배, 볼 등)
#   face   : 프레임별 얼굴 (0 기본, 1 깜빡, 2 하품, 3 수면)
#   extra  : 깜빡이는 부분 (외곽선 포함, 없으면 빈 목록)
# ---------------------------------------------------------------------------
def C(x, y, r, col): return [0, col, x, y, r]
def E(x, y, rx, ry, col): return [1, col, x, y, rx, ry]
def A(x, y, r, w, a0, a1, col): return [4, col, x, y, r, w, a0, a1]
def Ln(x1, y1, x2, y2, w, col): return [5, col, x1, y1, x2, y2, w]


def eyes_open(xs, y, rx, ry, col, hl=0xFFFFFF):
    out = []
    for x in xs:
        out += [E(x, y, rx, ry, col), C(x + rx * 0.35, y - ry * 0.45, max(1.2, rx * 0.4), hl)]
    return out


def eyes_blink(xs, y, half, w, col):
    return [Ln(x - half, y, x + half, y, w, col) for x in xs]


def eyes_sleep(xs, y, r, w, col):
    return [A(x, y - r * 0.4, r, w, 200, 340, col) for x in xs]


def eyes_happy(xs, y, r, w, col):
    return [A(x, y + r * 0.6, r, w, 20, 160, col) for x in xs]


def faces(eye_x, eye_y, erx, ery, ecol, mouth_y, smile_r, k, red, hl=0xFFFFFF):
    smile = [A(50, mouth_y - smile_r, smile_r, 2.6, 200, 340, k)]
    yawn = [E(50, mouth_y + 3, 4.5, 5.5, k), E(50, mouth_y + 3.8, 3, 3.6, red)]
    small = [Ln(46, mouth_y + 1, 54, mouth_y + 1, 2.4, k)]
    return [
        eyes_open(eye_x, eye_y, erx, ery, ecol, hl) + smile,
        eyes_blink(eye_x, eye_y + 1, erx + 2, 2.8, k) + smile,
        eyes_sleep(eye_x, eye_y + 1, erx + 1.5, 2.6, k) + yawn,
        eyes_sleep(eye_x, eye_y + 1, erx + 1.5, 2.6, k) + small,
        eyes_happy(eye_x, eye_y + 1, erx + 1.5, 2.6, k) + smile,
    ]


SMOOTH = [
    {   # 모찌
        "outline": 0x2B2B3A,
        "body": [E(58, 21, 10, 5, 0x6CC56C), E(50, 62, 45, 36, 0xFFF8EE)],
        "detail": [E(50, 88, 30, 7, 0xEFE3D4), E(23, 69, 6.5, 3.8, 0xFF9BB3), E(77, 69, 6.5, 3.8, 0xFF9BB3),
                   Ln(50, 27, 54, 21, 2, 0x3E8E4A)],
        "face": faces([35, 65], 57, 3.6, 5.2, 0x2B2B3A, 68, 5, 0x2B2B3A, 0xE0506A),
        "extra": [],
        "head": [18, 82],
    },
    {   # 도롱이
        "outline": 0x2B2A22,
        "body": [C(70, 88, 7, 0xE3E0A6), C(74, 87, 6.9, 0xE3E0A6), C(78, 85.5, 6.7, 0xE3E0A6), C(82, 83.5, 6.4, 0xE3E0A6), C(85, 81, 6.2, 0xE3E0A6), C(88, 78, 5.9, 0xE3E0A6), C(90, 75, 5.5, 0xE3E0A6), C(92, 71.5, 5, 0xE3E0A6), C(94, 68, 4.6, 0xE3E0A6), C(95, 64.5, 4.2, 0xE3E0A6),
                 E(38, 97, 9, 4, 0xF4EFD3), E(62, 97, 9, 4, 0xF4EFD3),
                 E(40, 88, 6, 9, 0xF4EFD3), E(60, 88, 6, 9, 0xF4EFD3),
                 C(24, 80, 5, 0xF4EFD3), C(76, 80, 5, 0xF4EFD3),
                 E(24, 66, 5, 13, 0xF4EFD3), E(76, 66, 5, 13, 0xF4EFD3),
                 E(50, 65, 23, 26, 0xF4EFD3), E(50, 30, 31, 27, 0xD8D49B)],
        "detail": [C(80, 84, 2.2, 0xB5BF74), C(89, 77, 1.8, 0xB5BF74), C(93, 68, 1.5, 0xB5BF74),
                   C(73, 89, 1.6, 0xB5BF74), C(36, 55, 2.4, 0xB5BF74), C(64, 55, 2.4, 0xB5BF74),
                   C(41, 59, 1.7, 0xB5BF74), C(59, 59, 1.7, 0xB5BF74),
                   C(47, 36, 0.9, 0x2B2A22), C(53, 36, 0.9, 0x2B2A22)],
        "face": [
            [C(34, 28, 8.5, 0x2B2A22), C(34, 28, 7, 0xFFFFFF), C(34, 28, 5, 0x1E1D18),
             C(66, 28, 8.5, 0x2B2A22), C(66, 28, 7, 0xFFFFFF), C(66, 28, 5, 0x1E1D18),
             Ln(45, 42, 55, 42, 2.2, 0x2B2A22)],
            [Ln(28, 29, 40, 29, 3, 0x2B2A22), Ln(60, 29, 72, 29, 3, 0x2B2A22), Ln(45, 42, 55, 42, 2.2, 0x2B2A22)],
            [A(34, 26, 5.5, 2.8, 200, 340, 0x2B2A22), A(66, 26, 5.5, 2.8, 200, 340, 0x2B2A22),
             E(50, 44, 4, 5, 0x2B2A22), E(50, 44.8, 2.7, 3.3, 0xE0506A)],
            [A(34, 26, 5.5, 2.8, 200, 340, 0x2B2A22), A(66, 26, 5.5, 2.8, 200, 340, 0x2B2A22),
             Ln(47, 43, 53, 43, 2.2, 0x2B2A22)],
            [A(34, 31, 6, 3, 20, 160, 0x2B2A22), A(66, 31, 6, 3, 20, 160, 0x2B2A22),
             A(50, 38, 5, 2.4, 200, 340, 0x2B2A22)],
        ],
        "extra": [],
        "head": [6, 80],
    },
]


def enc_shapes(lst):
    out = []
    for sh in lst:
        t, col = sh[0], sh[1]
        nums = [int(round(v * 10)) for v in sh[2:]]
        if t == 4:   # 각도는 그대로
            nums = [int(round(v * 10)) for v in sh[2:6]] + [int(sh[6]), int(sh[7])]
        out.append([t, col] + nums)
    return out


def build_smooth(sm):
    return {
        "outline": sm["outline"],
        "body": enc_shapes(sm["body"]),
        "detail": enc_shapes(sm["detail"]),
        "face": [enc_shapes(f) for f in sm["face"]],
        "extra": enc_shapes(sm["extra"]),
        "head": sm["head"],
    }


# 프레임 순서 (워치 코드의 FRAME_* 상수와 일치해야 함)
FRAMES = [
    ("open", "smile"),   # 0 기본
    ("blink", "smile"),  # 1 깜빡
    ("sleep", "yawn"),   # 2 하품
    ("sleep", "small"),  # 3 수면
    ("happy", "smile"),  # 4 기쁨 (걸음 목표 달성)
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
        # 가로 기준점 (반 칸 단위). 기본은 가운데, 꼬리가 있으면 몸 중심.
        "anchor2": int(round(ch.get("anchor", (w - 1) / 2) * 2)) + 1,
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
    "°": ["##.", "##.", "...", "...", "..."],
}

ICONS = {  # 5x5 (순서: 워치 코드의 ICON_* 상수)
    "heart": [".#.#.", "#####", "#####", ".###.", "..#.."],
    "bolt":  ["...#.", "..##.", ".###.", ".##..", ".#..."],
    "steps": [".##..", ".##..", "...##", "##.##", "##..."],
    "batt":  ["####.", "#..##", "#..##", "#..##", "####."],
    "flame": ["..#..", ".##..", ".###.", "#####", ".###."],
    "pin":   [".###.", "##.##", ".###.", "..#..", "..#.."],
    "stairs": ["....#", "...##", "..###", ".####", "#####"],
    "wave":  [".....", ".#...", "#.#.#", "...#.", "....."],
    "sun":   ["..#..", ".###.", "#####", ".###.", "..#.."],
    "cloud": [".....", ".##..", "####.", "#####", "....."],
    "rain":  [".##..", "####.", "#####", "#.#..", ".#.#."],
    "snow":  ["#.#.#", ".###.", "##.##", ".###.", "#.#.#"],
    "bell":  ["..#..", ".###.", ".###.", "#####", "..#.."],
}
ICON_ORDER = ["heart", "bolt", "steps", "batt", "flame", "pin", "stairs", "wave",
              "sun", "cloud", "rain", "snow", "bell"]



HANGUL_ORDER = ["일", "월", "화", "수", "목", "금", "토"]   # 요일 순서(일요일=0)와 같음
HANGUL = {  # 7x10
    "일": [".##..#.", "#..#.#.", "#..#.#.", ".##..#.", ".......",
           "######.", ".....#.", "######.", "#......", "######."],
    "월": [".##..#.", "#..#.#.", ".##.##.", "####.#.", ".#.....",
           "######.", ".....#.", "######.", "#......", "######."],
    "화": ["..#..#.", "####.#.", ".##..#.", "#..#.##", ".##..#.",
           "..#..#.", "####.#.", ".....#.", ".....#.", "......."],
    "수": ["...#...", "...#...", "..#.#..", ".#...#.", "#.....#",
           ".......", "#######", "...#...", "...#...", "...#..."],
    "목": [".#####.", ".#...#.", ".#####.", "...#...", "#######",
           ".......", ".#####.", ".....#.", ".....#.", ".....#."],
    "금": [".#####.", ".....#.", ".....#.", ".......", "#######",
           ".......", ".#####.", ".#...#.", ".#...#.", ".#####."],
    "토": [".#####.", ".#.....", ".#####.", ".#.....", ".#####.",
           "...#...", "...#...", "#######", ".......", "......."],
}

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


def emit_monkeyc(path, chars, smooth, font, names, labels):
    def arr(a):
        return "[" + ", ".join(str(x) for x in a) + "]"

    def hexarr(a):
        return "[" + ", ".join("0x%06X" % x for x in a) + "]"

    L = []
    L.append("// 자동 생성 파일 - 직접 수정하지 말 것 (tools/gen_sprites.py)")
    L.append("import Toybox.Lang;")
    L.append("")
    L.append("module Sprites {")
    L.append("    // 캐릭터: %s" % ", ".join("%d %s" % (i, n) for i, n in enumerate(labels)))
    L.append("    const CHARACTER_COUNT = %d;" % len(chars))
    L.append("    function characterNames() as Array<ResourceId> {")
    L.append("        return [%s] as Array<ResourceId>;" % ", ".join("Rez.Strings." + n for n in names))
    L.append("    }")
    L.append("    var W as Array<Number> = %s as Array<Number>;" % arr([c["w"] for c in chars]))
    L.append("    var H as Array<Number> = %s as Array<Number>;" % arr([c["h"] for c in chars]))
    L.append("    var HEAD as Array = [%s] as Array;" % ", ".join(arr(c["head"]) for c in chars))
    L.append("    // 가로 기준점 (반 칸 단위): 몸 중심이 화면 가운데에 오도록")
    L.append("    var ANCHOR2 as Array<Number> = %s as Array<Number>;" % arr([c["anchor2"] for c in chars]))
    L.append("    var PAL as Array = [")
    for c in chars:
        L.append("        %s," % hexarr(c["pal"]))
    L.append("    ] as Array;")
    L.append("    var BASE as Array = [")
    for c in chars:
        L.append("        %s," % arr(c["base"]))
    L.append("    ] as Array;")
    L.append("    // 프레임 1(깜빡) 2(하품) 3(수면) 차이분")
    L.append("    var FACE as Array = [")
    for c in chars:
        L.append("        [%s]," % ", ".join(arr(f) for f in c["face"]))
    L.append("    ] as Array;")
    L.append("    var EXTRA as Array = [%s] as Array;" % ", ".join(arr(c["extra"]) for c in chars))
    L.append("")
    L.append("    // 디지털(벡터) 캐릭터 - 좌표 0.1 단위, 100x100 상자")
    L.append("    var SM_OUTLINE as Array<Number> = %s as Array<Number>;" % hexarr([m["outline"] for m in smooth]))
    L.append("    var SM_HEAD as Array = [%s] as Array;" % ", ".join(arr(m["head"]) for m in smooth))

    def shapes(lst):
        return "[" + ", ".join(("[%d, 0x%06X, " % (sh[0], sh[1])) + ", ".join(str(v) for v in sh[2:]) + "]"
                               for sh in lst) + "]"
    for key in ("body", "detail", "extra"):
        L.append("    var SM_%s as Array = [" % key.upper())
        for m in smooth:
            L.append("        %s," % shapes(m[key]))
        L.append("    ] as Array;")
    L.append("    var SM_FACE as Array = [")
    for m in smooth:
        L.append("        [%s]," % ", ".join(shapes(f) for f in m["face"]))
    L.append("    ] as Array;")
    L.append("")
    L.append("    // 픽셀 폰트")
    L.append("    var BIG as Array = [%s] as Array;" % ", ".join(arr(d) for d in font["big"]))
    L.append('    var CHARS as String = "%s";' % font["chars"])
    L.append("    var SMALL as Array<Number> = %s as Array<Number>;" % arr(font["small"]))
    L.append("    var ICONS as Array<Number> = %s as Array<Number>;" % arr(font["icons"]))
    L.append("    // 한글 7x10 (일 월 화 수 목 금 토)")
    L.append("    var HANGUL as Array = [%s] as Array;" % ", ".join(arr(g) for g in font["hangul"]))
    L.append("}")
    L.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))



def main():
    chars = [build_character(c) for c in CHARACTERS]
    smooth = [build_smooth(sm) for sm in SMOOTH]
    small_chars = "".join(SMALL.keys())
    font = {
        "big": [row_masks(BIG[str(d)]) for d in range(10)],
        "chars": small_chars,
        "small": [bits(SMALL[c]) for c in small_chars],
        "icons": [bits(ICONS[k]) for k in ICON_ORDER],
        "hangul": [row_masks(HANGUL[k]) for k in HANGUL_ORDER],
    }

    # ---- Monkey C ----
    def arr(a):
        return "[" + ", ".join(str(x) for x in a) + "]"

    def hexarr(a):
        return "[" + ", ".join("0x%06X" % x for x in a) + "]"

    # 전체판 (개인 사용) / 스토어판 (오리지널 캐릭터만)
    emit_monkeyc(os.path.join(ROOT, "source-full", "Sprites.mc"), chars, smooth, font,
                 [c["label"] for c in CHARACTERS], [c["name"] for c in CHARACTERS])
    store = [i for i, c in enumerate(CHARACTERS) if c.get("store")]
    emit_monkeyc(os.path.join(ROOT, "source-store", "Sprites.mc"), [chars[i] for i in store],
                 [smooth[i] for i in store], font, [CHARACTERS[i]["label"] for i in store],
                 [CHARACTERS[i]["name"] for i in store])

    # ---- JS ----
    js = {"chars": chars, "smooth": smooth, "font": font}
    os.makedirs(os.path.join(ROOT, "preview"), exist_ok=True)
    with open(os.path.join(ROOT, "preview", "sprites.js"), "w", encoding="utf-8") as f:
        f.write("// 자동 생성 파일 - tools/gen_sprites.py\n")
        f.write("window.SPRITES = " + json.dumps(js) + ";\n")

    write_icon(chars[0], os.path.join(ROOT, "resources", "drawables", "launcher_icon.png"))
    os.makedirs(os.path.join(ROOT, "docs", "store"), exist_ok=True)
    write_icon(chars[0], os.path.join(ROOT, "docs", "store", "icon-512.png"), size=512, s=16)

    total = sum(len(c["base"]) + sum(len(x) for x in c["face"]) + len(c["extra"]) for c in chars)
    print("OK: %d characters, %d runs total" % (len(chars), total))


if __name__ == "__main__":
    main()
