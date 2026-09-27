import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// 픽셀 그리기 도우미 (스프라이트 / 픽셀 폰트 / 픽셀 원)
module Pix {
    const ICON_HEART = 0;
    const ICON_BOLT = 1;
    const ICON_STEPS = 2;
    const ICON_BATT = 3;

    // 런 배열 그리기. override >= 0 이면 외곽선(팔레트 1)만 해당 색으로 그림 (AOD용)
    function drawRuns(dc as Dc, runs as Array, pal as Array, x as Number, y as Number,
                      s as Number, override as Number) as Void {
        var last = -1;
        if (override >= 0) {
            dc.setColor(override, Graphics.COLOR_TRANSPARENT);
        }
        var n = runs.size();
        for (var i = 0; i < n; i++) {
            var v = runs[i] as Number;
            var c = (v >> 18) & 0xF;
            if (override >= 0) {
                if (c != 1) {
                    break; // 런은 색 인덱스 순으로 정렬되어 있음
                }
            } else if (c != last) {
                dc.setColor(pal[c] as Number, Graphics.COLOR_TRANSPARENT);
                last = c;
            }
            dc.fillRectangle(x + (v & 0x3F) * s, y + ((v >> 6) & 0x3F) * s,
                             ((v >> 12) & 0x3F) * s, s);
        }
    }

    // 캐릭터 1프레임 그리기
    //   frame: 0 기본, 1 깜빡, 2 하품, 3 수면 / flicker: 파이리 불꽃 깜빡임
    function drawCharacter(dc as Dc, ci as Number, frame as Number, x as Number, y as Number,
                           s as Number, flicker as Boolean, override as Number) as Void {
        var pal = Sprites.PAL[ci] as Array;
        drawRuns(dc, Sprites.BASE[ci] as Array, pal, x, y, s, override);
        if (frame > 0) {
            drawRuns(dc, (Sprites.FACE[ci] as Array)[frame - 1] as Array, pal, x, y, s, override);
        }
        var extra = Sprites.EXTRA[ci] as Array;
        if (flicker && extra.size() > 0 && override < 0) {
            drawRuns(dc, extra, pal, x, y, s, -1);
        }
    }

    // 비트마스크 글리프 (cols x rows, 비트 = r*cols + c)
    function drawBits(dc as Dc, g as Number, cols as Number, rows as Number,
                      x as Number, y as Number, s as Number) as Void {
        for (var r = 0; r < rows; r++) {
            var c = 0;
            while (c < cols) {
                if (((g >> (r * cols + c)) & 1) != 0) {
                    var st = c;
                    while (c < cols && ((g >> (r * cols + c)) & 1) != 0) {
                        c++;
                    }
                    dc.fillRectangle(x + st * s, y + r * s, (c - st) * s, s);
                } else {
                    c++;
                }
            }
        }
    }

    function drawIcon(dc as Dc, icon as Number, x as Number, y as Number, s as Number) as Void {
        drawBits(dc, Sprites.ICONS[icon], 5, 5, x, y, s);
    }

    // ---- 3x5 작은 글꼴 ----
    function textWidth(t as String, s as Number) as Number {
        return t.length() * 4 * s - s;
    }

    function drawText(dc as Dc, t as String, x as Number, y as Number, s as Number) as Void {
        var cs = t.toUpper().toCharArray();
        for (var i = 0; i < cs.size(); i++) {
            var idx = Sprites.CHARS.find(cs[i].toString());
            if (idx != null) {
                drawBits(dc, Sprites.SMALL[idx], 3, 5, x + i * 4 * s, y, s);
            }
        }
    }

    // 가운데 정렬 + 그림자
    function drawTextShadow(dc as Dc, t as String, cx as Number, y as Number, s as Number,
                            color as Number, shadow as Number) as Void {
        var x = cx - textWidth(t, s) / 2;
        dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
        drawText(dc, t, x + s, y + s, s);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        drawText(dc, t, x, y, s);
    }

    // ---- 5x7 큰 숫자 (HH:MM) ----
    function drawBigDigit(dc as Dc, d as Number, x as Number, y as Number, s as Number) as Void {
        var rows = Sprites.BIG[d] as Array;
        for (var r = 0; r < 7; r++) {
            var m = rows[r] as Number;
            var c = 0;
            while (c < 5) {
                if (((m >> c) & 1) != 0) {
                    var st = c;
                    while (c < 5 && ((m >> c) & 1) != 0) {
                        c++;
                    }
                    dc.fillRectangle(x + st * s, y + r * s, (c - st) * s, s);
                } else {
                    c++;
                }
            }
        }
    }

    // 폭: 5+1+5 +2+1+2 +5+1+5 = 27 단위
    function timeWidth(s as Number) as Number {
        return 27 * s;
    }

    function drawTime(dc as Dc, h as Number, m as Number, cx as Number, y as Number,
                      s as Number, colon as Boolean, leadingZero as Boolean) as Void {
        var x = cx - timeWidth(s) / 2;
        if (h >= 10 || leadingZero) {
            drawBigDigit(dc, h / 10, x, y, s);
        }
        drawBigDigit(dc, h % 10, x + 6 * s, y, s);
        if (colon) {
            dc.fillRectangle(x + 13 * s, y + 2 * s, s, s);
            dc.fillRectangle(x + 13 * s, y + 4 * s, s, s);
        }
        drawBigDigit(dc, m / 10, x + 16 * s, y, s);
        drawBigDigit(dc, m % 10, x + 22 * s, y, s);
    }

    // ---- 픽셀 원 (u = 픽셀 단위) ----
    function disc(dc as Dc, cx as Number, cy as Number, r as Number, u as Number) as Void {
        var dy = -r;
        while (dy < r) {
            var mid = dy + u / 2;
            var sq = r * r - mid * mid;
            if (sq > 0) {
                var hw = Math.sqrt(sq).toNumber();
                hw = ((hw + u / 2) / u) * u;
                dc.fillRectangle(cx - hw, cy + dy, hw * 2, u);
            }
            dy += u;
        }
    }
}
