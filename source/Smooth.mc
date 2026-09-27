import Toybox.Graphics;
import Toybox.Lang;

// 디지털(벡터) 캐릭터 그리기
// 도형 데이터는 Sprites.SM_* (100x100 상자, 좌표 0.1 단위)
//   [0 원, 색, x, y, r] / [1 타원, 색, x, y, rx, ry]
//   [4 호, 색, x, y, r, 굵기, 시작각, 끝각] / [5 선, 색, x1, y1, x2, y2, 굵기]
module Smooth {
    // (x, y) = 상자 왼쪽 위, size = 상자 한 변(px)
    // override >= 0 이면 외곽선과 얼굴만 그 색으로, 몸은 검정으로 채움 (AOD용)
    function drawCharacter(dc as Dc, ci as Number, frame as Number, x as Number, y as Number,
                           size as Number, flicker as Boolean, override as Number) as Void {
        var k = size / 1000.0;
        var grow = (size * 0.03).toNumber();
        if (grow < 2) {
            grow = 2;
        }
        var outline = override >= 0 ? override : (Sprites.SM_OUTLINE[ci] as Number);
        var body = Sprites.SM_BODY[ci] as Array;
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        shapes(dc, body, x, y, k, grow, outline);
        shapes(dc, body, x, y, k, 0, override >= 0 ? 0x000000 : -1);
        if (override < 0) {
            var extra = Sprites.SM_EXTRA[ci] as Array;
            if (flicker && extra.size() > 0) {
                shapes(dc, extra, x, y, k, grow, outline);
                shapes(dc, extra, x, y, k, 0, -1);
            }
            shapes(dc, Sprites.SM_DETAIL[ci] as Array, x, y, k, 0, -1);
        }
        shapes(dc, (Sprites.SM_FACE[ci] as Array)[frame] as Array, x, y, k, 0, override);
        dc.setPenWidth(1);
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }
    }

    // grow > 0 : 외곽선 단계 (도형을 grow 만큼 키워서 color 로 칠함, 선/호는 건너뜀)
    // color < 0 : 도형 자체 색 사용
    function shapes(dc as Dc, list as Array, x as Number, y as Number, k as Float,
                    grow as Number, color as Number) as Void {
        for (var i = 0; i < list.size(); i++) {
            var sh = list[i] as Array<Number>;
            var t = sh[0];
            if (grow > 0 && t >= 4) {
                continue;
            }
            dc.setColor(color >= 0 ? color : sh[1], Graphics.COLOR_TRANSPARENT);
            var cx = x + (sh[2] * k).toNumber();
            var cy = y + (sh[3] * k).toNumber();
            if (t == 0) {
                dc.fillCircle(cx, cy, (sh[4] * k).toNumber() + grow);
            } else if (t == 1) {
                dc.fillEllipse(cx, cy, (sh[4] * k).toNumber() + grow, (sh[5] * k).toNumber() + grow);
            } else if (t == 4) {
                dc.setPenWidth(pen(sh[5], k));
                dc.drawArc(cx, cy, (sh[4] * k).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, sh[6], sh[7]);
            } else if (t == 5) {
                dc.setPenWidth(pen(sh[6], k));
                dc.drawLine(cx, cy, x + (sh[4] * k).toNumber(), y + (sh[5] * k).toNumber());
            }
        }
    }

    function pen(w as Number, k as Float) as Number {
        var p = (w * k + 0.5).toNumber();
        return p < 1 ? 1 : p;
    }
}
