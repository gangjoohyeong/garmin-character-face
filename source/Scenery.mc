import Toybox.Graphics;
import Toybox.Lang;

// 픽셀아트 풍경 (풀밭 제외. 풀밭은 MochiFaceView 의 기본 장면)
//   sc    : 1 바다, 2 도시, 3 설산, 4 벚꽃, 5 단풍, 6 우주
//   scene : 시간대 0 아침, 1 낮, 2 저녁, 3 밤 (색 명암에 사용)
//   cols  : colors() 가 돌려준 시간대 적용 색 8개
// 좌표는 360x360 기준, (ox, oy) 만큼 옮겨 그림. 땅 윗선 groundY = 246.
module Scenery {
    const MEADOW = 0;
    const SEA = 1;
    const CITY = 2;
    const SNOW = 3;
    const CHERRY = 4;
    const AUTUMN = 5;
    const SPACE = 6;
    const SEASONAL = 7;
    const HORIZON = 200;   // 바다 수평선

    // 기본 색 (낮 기준). 인덱스 의미는 풍경마다 다름 (각 draw 함수 주석 참고)
    var BASE as Array = [
        [],
        [0x2E86C1, 0x5DADE2, 0xEAF6FF, 0xF2D9A0, 0xD9B878, 0x8B5E3C, 0x3FA34D, 0x2E7D32],
        [0x6C7A96, 0x4A5670, 0xFFE08A, 0x5D636E, 0x9AA0AA, 0xF4F4F4, 0xBFD9F2, 0x39435A],
        [0x8FA3C0, 0x6F84A6, 0xFFFFFF, 0xEEF4FA, 0xC9D8EA, 0x2F6B4F, 0x1F4D38, 0x6B4A2E],
        [0x7FC96A, 0xA8E08C, 0x5FA84F, 0x7A5238, 0xF8B9CF, 0xFFD9E6, 0xE88AAE, 0xC9E4B8],
        [0xB5A24E, 0xD1BF6A, 0x8E7E36, 0x6B4630, 0xF08A3C, 0xF7C948, 0xD9482B, 0xC98E5A],
        [0x0B0B1E, 0x15123A, 0xE0875A, 0xB8623E, 0xF3D5A0, 0x8C8C99, 0x6B6B78, 0x55555F]
    ] as Array;

    // 계절 자동: 월(1~12) → 풍경
    function seasonal(month as Number) as Number {
        if (month >= 3 && month <= 5) {
            return CHERRY;
        } else if (month >= 6 && month <= 8) {
            return SEA;
        } else if (month >= 9 && month <= 11) {
            return AUTUMN;
        }
        return SNOW;
    }

    // 시간대에 맞춘 색 8개 (도시 창문 불빛·우주는 명암을 적용하지 않음)
    function colors(sc as Number, scene as Number) as Array<Number> {
        var base = BASE[sc] as Array<Number>;
        var out = [] as Array<Number>;
        for (var i = 0; i < base.size(); i++) {
            var c = base[i];
            if (sc == SPACE || (sc == CITY && i == 2 && scene >= 2)) {
                out.add(c);
            } else {
                out.add(shade(c, scene));
            }
        }
        return out;
    }

    function shade(c as Number, scene as Number) as Number {
        var k = ([96, 100, 80, 46] as Array<Number>)[scene];
        var r = ((c >> 16) & 0xFF) * k / 100;
        var g = ((c >> 8) & 0xFF) * k / 100;
        var b = (c & 0xFF) * k / 100;
        if (scene == 3) {          // 밤: 푸른빛
            r = r + 6;
            g = g + 12;
            b = b + 34;
        } else if (scene == 2) {   // 저녁: 붉은빛
            r = r + 22;
            b = b + 6;
        }
        r = r > 255 ? 255 : r;
        g = g > 255 ? 255 : g;
        b = b > 255 ? 255 : b;
        return (r << 16) | (g << 8) | b;
    }

    // 계단식 픽셀 삼각형 (산, 나무)
    function tri(dc as Dc, cx as Number, baseY as Number, halfW as Number, height as Number, u as Number) as Void {
        var r = 0;
        while (r < height) {
            var hw = ((halfW * (r + u) / height) / u) * u;
            dc.fillRectangle(cx - hw, baseY - height + r, hw * 2, u);
            r += u;
        }
    }

    // ---------------------------------------------------------------------
    // 고정 부분 (버퍼 비트맵에 캐시). 하늘·해/달은 이미 그려진 상태.
    // ---------------------------------------------------------------------
    function drawStatic(dc as Dc, sc as Number, scene as Number, cols as Array<Number>,
                        ox as Number, oy as Number, w as Number, h as Number) as Void {
        var gy = 246 + oy;
        if (sc == SEA) {
            drawSea(dc, cols, ox, oy, w, h, gy);
        } else if (sc == CITY) {
            drawCity(dc, cols, ox, oy, w, h, gy, scene);
        } else if (sc == SNOW) {
            drawSnow(dc, cols, ox, oy, w, h, gy);
        } else if (sc == CHERRY || sc == AUTUMN) {
            drawTrees(dc, cols, ox, oy, w, h, gy);
        } else if (sc == SPACE) {
            drawSpace(dc, cols, ox, oy, w, h, gy);
        }
    }

    // 바다: 0 깊은 물, 1 밝은 물결, 2 물거품, 3 모래, 4 모래 점, 5 야자 줄기, 6 잎, 7 잎 그늘
    function drawSea(dc as Dc, c as Array<Number>, ox as Number, oy as Number, w as Number, h as Number, gy as Number) as Void {
        var hz = HORIZON + oy;
        dc.setColor(c[0], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, hz, w, gy - hz);
        dc.setColor(c[1], Graphics.COLOR_TRANSPARENT);
        var rows = [4, 14, 26, 38] as Array<Number>;
        for (var i = 0; i < rows.size(); i++) {
            var x = (i * 12) % 32;
            while (x < w) {
                dc.fillRectangle(x, hz + rows[i], 12 + i * 2, 2);
                x += 32;
            }
        }
        // 모래
        dc.setColor(c[3], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, h - gy);
        dc.setColor(c[2], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy - 2, w, 4);
        var fx = 0;
        while (fx < w) {
            dc.fillRectangle(fx, gy + 2, 8, 2);
            fx += 20;
        }
        dc.setColor(c[4], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 16; i++) {
            dc.fillRectangle((i * 53 + 11) % 360 + ox, gy + 16 + (i * 31) % 90, 4, 4);
        }
        // 야자수
        var tx = 44 + ox;
        dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 10; i++) {
            dc.fillRectangle(tx + (i / 3) * 4, gy - 10 - i * 10, 8, 10);
        }
        var lx = tx + 16;
        var ly = gy - 108;
        dc.setColor(c[6], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 40, ly, 40, 6);
        dc.fillRectangle(lx - 48, ly + 6, 12, 6);
        dc.fillRectangle(lx, ly - 6, 38, 6);
        dc.fillRectangle(lx + 34, ly, 10, 8);
        dc.fillRectangle(lx - 26, ly - 12, 26, 6);
        dc.fillRectangle(lx - 4, ly - 16, 8, 10);
        dc.fillRectangle(lx + 4, ly + 6, 28, 6);
        dc.fillRectangle(lx + 26, ly + 12, 8, 8);
        dc.setColor(c[7], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx - 36, ly + 6, 24, 2);
        dc.fillRectangle(lx + 8, ly + 12, 16, 2);
        dc.fillRectangle(lx - 4, ly - 2, 10, 8);
    }

    // 도시: 0 먼 빌딩, 1 가까운 빌딩, 2 창문 불빛(밤), 3 도로, 4 인도, 5 차선, 6 창문(낮), 7 지붕
    function drawCity(dc as Dc, c as Array<Number>, ox as Number, oy as Number, w as Number, h as Number,
                      gy as Number, scene as Number) as Void {
        var far = [0, 40, 70, 36, 30, 104, 64, 44, 62, 104, 26, 122, 128, 40, 82, 166, 30, 142,
                   194, 44, 92, 236, 28, 112, 262, 40, 72, 300, 36, 96, 334, 30, 62] as Array<Number>;
        var near = [-4, 52, 50, 60, 36, 66, 120, 48, 44, 200, 40, 58, 252, 56, 48, 316, 48, 56] as Array<Number>;
        var lit = scene >= 2;
        for (var i = 0; i < far.size(); i += 3) {
            var bx = far[i] + ox;
            var bw = far[i + 1];
            var bh = far[i + 2];
            dc.setColor(c[0], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, gy - bh, bw, bh);
            dc.setColor(lit ? c[2] : c[6], Graphics.COLOR_TRANSPARENT);
            var wy = gy - bh + 8;
            var row = 0;
            while (wy < gy - 12) {
                var wx = bx + 6;
                var col = 0;
                while (wx < bx + bw - 6) {
                    if (((row + col + i) % 3) == 0) {
                        dc.fillRectangle(wx, wy, 4, 4);
                    }
                    wx += 10;
                    col++;
                }
                wy += 12;
                row++;
            }
        }
        for (var i = 0; i < near.size(); i += 3) {
            var bx = near[i] + ox;
            dc.setColor(c[1], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, gy - near[i + 2], near[i + 1], near[i + 2]);
            dc.setColor(c[7], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx, gy - near[i + 2], near[i + 1], 4);
        }
        // 인도 + 도로
        dc.setColor(c[3], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, h - gy);
        dc.setColor(c[4], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, 12);
        dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
        var lx = 0;
        while (lx < w) {
            dc.fillRectangle(lx, gy + 40, 16, 3);
            lx += 32;
        }
    }

    // 설산: 0 먼 산, 1 가까운 산, 2 눈 모자, 3 눈밭, 4 눈 그늘, 5 소나무, 6 소나무 그늘, 7 줄기
    function drawSnow(dc as Dc, c as Array<Number>, ox as Number, oy as Number, w as Number, h as Number, gy as Number) as Void {
        var mts = [90, 124, 124, 272, 136, 144] as Array<Number>;   // cx, halfW, height
        for (var i = 0; i < mts.size(); i += 3) {
            dc.setColor(c[0], Graphics.COLOR_TRANSPARENT);
            tri(dc, mts[i] + ox, gy, mts[i + 1], mts[i + 2], 4);
            var capH = mts[i + 2] * 3 / 10;
            dc.setColor(c[2], Graphics.COLOR_TRANSPARENT);
            tri(dc, mts[i] + ox, gy - mts[i + 2] + capH, mts[i + 1] * 3 / 10, capH, 4);
        }
        dc.setColor(c[1], Graphics.COLOR_TRANSPARENT);
        tri(dc, 196 + ox, gy, 100, 84, 4);
        dc.setColor(c[2], Graphics.COLOR_TRANSPARENT);
        tri(dc, 196 + ox, gy - 84 + 20, 24, 20, 4);
        // 눈밭
        dc.setColor(c[3], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, h - gy);
        dc.setColor(c[4], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 16; i++) {
            dc.fillRectangle((i * 47 + 23) % 360 + ox, gy + 14 + (i * 37) % 90, 8, 4);
        }
        // 소나무
        var trees = [34, 64, 300, 330] as Array<Number>;
        for (var i = 0; i < trees.size(); i++) {
            var tx = trees[i] + ox;
            var by = gy + 8 + (i % 2) * 6;
            dc.setColor(c[7], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 2, by - 8, 4, 8);
            dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
            tri(dc, tx, by - 8, 14, 20, 4);
            tri(dc, tx, by - 20, 11, 18, 4);
            tri(dc, tx, by - 32, 8, 14, 4);
            dc.setColor(c[6], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx, by - 16, 12, 4);
            dc.setColor(c[2], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 4, by - 44, 8, 4);
        }
    }

    // 벚꽃/단풍: 0 땅, 1 땅 윗줄, 2 땅 점, 3 줄기, 4 잎(꽃), 5 밝은 잎, 6 어두운 잎, 7 언덕
    function drawTrees(dc as Dc, c as Array<Number>, ox as Number, oy as Number, w as Number, h as Number, gy as Number) as Void {
        dc.setColor(c[7], Graphics.COLOR_TRANSPARENT);
        Pix.disc(dc, 70 + ox, 268 + oy, 64, 4);
        Pix.disc(dc, 300 + ox, 276 + oy, 76, 4);
        dc.setColor(c[0], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, h - gy);
        dc.setColor(c[1], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, 6);
        dc.setColor(c[2], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 14; i++) {
            dc.fillRectangle((i * 53 + 17) % 360 + ox, gy + 20 + (i * 29) % 90, 4, 8);
        }
        // 떨어진 잎/꽃잎
        dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 18; i++) {
            dc.fillRectangle((i * 41 + 7) % 360 + ox, gy + 8 + (i * 23) % 100, 4, 4);
        }
        // 나무 두 그루 (왼쪽 큰 나무, 오른쪽 작은 나무)
        var ts = [50, 32, 316, 24] as Array<Number>;   // x, 수관 반지름
        for (var i = 0; i < ts.size(); i += 2) {
            var tx = ts[i] + ox;
            var r = ts[i + 1];
            var by = gy + 10;
            var th = r * 2;
            dc.setColor(c[3], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - 4, by - th, 8, th);
            dc.fillRectangle(tx, by - th + 10, r / 2 + 4, 4);
            var cy = by - th - r / 2;
            dc.setColor(c[4], Graphics.COLOR_TRANSPARENT);
            Pix.disc(dc, tx, cy, r, 4);
            Pix.disc(dc, tx + r * 2 / 3, cy + r / 3, r * 2 / 3, 4);
            Pix.disc(dc, tx - r * 2 / 3, cy + r / 3, r * 3 / 5, 4);
            dc.setColor(c[6], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - r / 2, cy + r / 2, 8, 4);
            dc.fillRectangle(tx + r / 3, cy + r * 2 / 3, 8, 4);
            dc.fillRectangle(tx - r, cy + r / 2 + 4, 6, 4);
            dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(tx - r / 3, cy - r / 2, 8, 4);
            dc.fillRectangle(tx + r / 4, cy - r / 4, 4, 4);
            dc.fillRectangle(tx - r * 2 / 3, cy, 4, 4);
        }
    }

    // 우주: 0 배경, 1 배경 밝은 띠, 2 행성, 3 행성 그늘, 4 고리, 5 지면, 6 지면 어두운, 7 크레이터
    //   하늘 대신 우주 배경을 직접 칠함 (시간대 무관)
    function drawSpace(dc as Dc, c as Array<Number>, ox as Number, oy as Number, w as Number, h as Number, gy as Number) as Void {
        dc.setColor(c[0], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, gy);
        dc.setColor(c[1], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 150 + oy, w, 40);
        var x = 0;
        while (x < w) {
            dc.fillRectangle(x, 146 + oy, 4, 4);
            dc.fillRectangle(x + 4, 190 + oy, 4, 4);
            x += 8;
        }
        // 고리 행성
        // 고리 행성 (시각 숫자 아래 오른쪽)
        dc.setColor(c[4], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(244 + ox, 162 + oy, 96, 4);
        dc.setColor(c[3], Graphics.COLOR_TRANSPARENT);
        Pix.disc(dc, 292 + ox, 164 + oy, 26, 4);
        dc.setColor(c[2], Graphics.COLOR_TRANSPARENT);
        Pix.disc(dc, 287 + ox, 159 + oy, 21, 4);
        dc.setColor(c[4], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(248 + ox, 170 + oy, 88, 4);
        dc.fillRectangle(258 + ox, 174 + oy, 68, 4);
        // 작은 달
        dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
        Pix.disc(dc, 72 + ox, 180 + oy, 10, 4);
        // 달 표면
        dc.setColor(c[5], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, h - gy);
        dc.setColor(c[6], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gy, w, 4);
        var cr = [40, 18, 12, 128, 60, 8, 236, 30, 16, 300, 70, 10, 180, 96, 12, 84, 84, 8] as Array<Number>;
        for (var i = 0; i < cr.size(); i += 3) {
            var cx = cr[i] + ox;
            var cy = gy + cr[i + 1];
            var r = cr[i + 2];
            dc.setColor(c[7], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r, cy, r * 2, r / 2 + 2);
            dc.setColor(c[6], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r + 2, cy - 2, r * 2 - 4, 2);
        }
    }

    // ---------------------------------------------------------------------
    // 매 프레임 그리는 부분 (꽃잎, 낙엽, 우주 별)
    // ---------------------------------------------------------------------
    function drawDynamic(dc as Dc, sc as Number, t as Number, cols as Array<Number>, ox as Number, oy as Number,
                         stars as Array<Number>) as Void {
        if (sc == CHERRY || sc == AUTUMN) {
            for (var i = 0; i < 10; i++) {
                dc.setColor(cols[4 + (i % 3)], Graphics.COLOR_TRANSPARENT);
                var x = (i * 71 + t * 6) % 360 + ox;
                var y = (i * 43 + t * 4) % 230 + 10 + oy;
                dc.fillRectangle(x, y, 4, 4);
                if (sc == AUTUMN) {
                    dc.fillRectangle(x + 2, y + 4, 2, 2);
                }
            }
        } else if (sc == SPACE) {
            for (var i = 0; i < stars.size() / 2; i++) {
                if (((t + i * 3) % 7) == 0) {
                    continue;
                }
                dc.setColor(i % 3 == 0 ? 0xFFF2B0 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                var sx = stars[i * 2] + ox;
                var sy = stars[i * 2 + 1] + oy;
                dc.fillRectangle(sx - 2, sy - 2, 4, 4);
                dc.fillRectangle((sx * 7 + 40) % 360 + ox, (sy * 3 + 20) % 230 + oy, 2, 2);
            }
        }
    }

    // ---------------------------------------------------------------------
    // 디지털 스타일 실루엣 (어두운 배경 위, 한 가지 색)
    // ---------------------------------------------------------------------
    function drawDigital(dc as Dc, sc as Number, color as Number, accent as Number, ox as Number, oy as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (sc == SEA) {
            for (var r = 0; r < 3; r++) {
                var x = (r * 10) % 24;
                while (x < 360) {
                    dc.fillRectangle(x + ox, 226 + r * 8 + oy, 12, 3);
                    x += 24;
                }
            }
        } else if (sc == CITY) {
            var b = [36, 30, 40, 68, 24, 62, 94, 36, 34, 236, 30, 56, 268, 26, 40, 296, 24, 50] as Array<Number>;
            for (var i = 0; i < b.size(); i += 3) {
                dc.fillRectangle(b[i] + ox, 252 - b[i + 2] + oy, b[i + 1], b[i + 2]);
            }
        } else if (sc == SNOW) {
            tri(dc, 84 + ox, 252 + oy, 80, 64, 4);
            tri(dc, 280 + ox, 252 + oy, 90, 80, 4);
        } else if (sc == CHERRY || sc == AUTUMN) {
            dc.fillRectangle(58 + ox, 206 + oy, 6, 46);
            dc.fillRectangle(298 + ox, 210 + oy, 6, 42);
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            Pix.disc(dc, 60 + ox, 200 + oy, 24, 4);
            Pix.disc(dc, 300 + ox, 204 + oy, 20, 4);
        } else if (sc == SPACE) {
            Pix.disc(dc, 296 + ox, 214 + oy, 18, 4);
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(266 + ox, 214 + oy, 60, 3);
        }
    }
}
