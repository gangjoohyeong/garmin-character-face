import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// 모든 좌표는 360x360 기준으로 설계하고 (_ox, _oy) 만큼 옮겨 그린다.
// (FR265S = 360x360, FR265 = 416x416 에서는 가운데 정렬)
class MochiFaceView extends WatchUi.WatchFace {
    // 캐릭터 프레임
    const FRAME_OPEN = 0;
    const FRAME_BLINK = 1;
    const FRAME_YAWN = 2;
    const FRAME_SLEEP = 3;

    // 장면(배경) : 0 아침, 1 낮, 2 저녁, 3 밤, -1 심플
    const SCENE_SIMPLE = -1;

    private var _w as Number = 360;
    private var _h as Number = 360;
    private var _ox as Number = 0;
    private var _oy as Number = 0;
    private var _lowPower as Boolean = false;
    private var _burnIn as Boolean = false;

    // 걸음 링 눈금 위치 (60개)
    private var _ringX as Array<Number> = [] as Array<Number>;
    private var _ringY as Array<Number> = [] as Array<Number>;

    // 데이터
    private var _hr as Number or Null = null;
    private var _bb as Number or Null = null;
    private var _bat as Number = 0;
    private var _steps as Number = 0;
    private var _goal as Number = 10000;

    // 색 테이블
    private var _sky as Array = [
        [0xF7A8B8, 0xF9B9BE, 0xFBCAC2, 0xFDDCC6, 0xFFE9C9, 0xFFF3D6],   // 아침
        [0x3FA9F5, 0x5AB8F7, 0x75C6F9, 0x90D3FB, 0xABE0FD, 0xC6ECFF],   // 낮
        [0x3A2C6E, 0x6A3A7E, 0x9C4A7E, 0xCF5F6E, 0xF08A5D, 0xFFB26B],   // 저녁
        [0x070B24, 0x0C1433, 0x121C42, 0x182552, 0x1F2E61, 0x273870]    // 밤
    ] as Array;
    // [언덕, 잔디 윗줄, 잔디, 잔디 어두운 점]
    private var _grass as Array = [
        [0xC9A3C8, 0xA8E08C, 0x7FC96A, 0x5FA84F],
        [0x6FAFD8, 0x9BE07A, 0x6CCB4E, 0x4FA63A],
        [0x7A4A7E, 0x8FA35A, 0x6E8544, 0x546A33],
        [0x1A2350, 0x2F6A4A, 0x214F37, 0x173B29]
    ] as Array;
    private var _cloud as Array<Number> = [0xFFF4F6, 0xFFFFFF, 0xF6B8A0, 0x000000] as Array<Number>;
    private var _sunColor as Array<Number> = [0xFFD66B, 0xFFE45C, 0xFF7A45, 0xFFF2B0] as Array<Number>;
    // 디지털 스타일 배경 / 강조색 (마지막 = 심플)
    private var _digBg as Array<Number> = [0x2A1B2E, 0x0E2238, 0x26142F, 0x05060D, 0x000000] as Array<Number>;
    private var _digHill as Array<Number> = [0x3A2640, 0x16324F, 0x351C40, 0x0C0F1E, 0x111111] as Array<Number>;
    private var _digAccent as Array<Number> = [0xFF9BB3, 0x4FC3F7, 0xFF8A50, 0xB39DDB, 0xFFD23F] as Array<Number>;

    private var _stars as Array<Number> = [
        70, 110, 110, 70, 150, 150, 230, 60, 300, 110, 50, 190,
        320, 190, 200, 20, 260, 140, 95, 160, 140, 40, 285, 60
    ] as Array<Number>;

    private var _days as Array<String> = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Array<String>;
    private var _months as Array<String> = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                            "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"] as Array<String>;

    function initialize() {
        WatchFace.initialize();
        Settings.load();
        var ds = System.getDeviceSettings();
        if (ds has :requiresBurnInProtection) {
            _burnIn = ds.requiresBurnInProtection;
        }
    }

    function onLayout(dc as Dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        _ox = (_w - 360) / 2;
        _oy = (_h - 360) / 2;
        _ringX = new Array<Number>[60];
        _ringY = new Array<Number>[60];
        for (var i = 0; i < 60; i++) {
            var a = i * Math.PI / 30.0;
            _ringX[i] = (180 + 171 * Math.sin(a)).toNumber() / 2 * 2 + _ox;
            _ringY[i] = (180 - 171 * Math.cos(a)).toNumber() / 2 * 2 + _oy;
        }
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

    // =====================================================================
    function onUpdate(dc as Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }
        var clock = System.getClockTime();
        var ci = Settings.currentCharacter();

        if (_lowPower && _burnIn) {
            drawAod(dc, clock, ci);
            return;
        }

        readStats();
        var scene = sceneFor(clock.hour);
        var anim = Settings.animate && !_lowPower;
        var sec = clock.sec;
        var sleeping = isSleepHour(clock.hour);

        // 캐릭터 상태 (시간대 기준)
        var frame = FRAME_OPEN;
        var bob = 0;
        if (sleeping) {
            frame = FRAME_SLEEP;
            if (anim && (sec % 4) < 2) {
                bob = 2;
            }
        } else if (anim) {
            if (clock.hour >= 6 && clock.hour < 10 && (sec % 15) >= 7 && (sec % 15) <= 8) {
                frame = FRAME_YAWN;
            } else if ((sec % 5) == 4) {
                frame = FRAME_BLINK;
            }
            if ((sec % 2) == 1) {
                bob = -3;
            }
        }
        var flicker = anim && (sec % 2) == 1;

        if (Settings.style == 0) {
            drawPixelFace(dc, clock, scene, ci, frame, bob, flicker, anim);
        } else {
            drawDigitalFace(dc, clock, scene, ci, frame, bob, flicker, anim);
        }
    }

    // ---- 시간대 ----
    private function periodFor(hour as Number) as Number {
        if (hour >= 5 && hour < 10) {
            return 0;
        } else if (hour >= 10 && hour < 17) {
            return 1;
        } else if (hour >= 17 && hour < 20) {
            return 2;
        }
        return 3;
    }

    private function sceneFor(hour as Number) as Number {
        var bg = Settings.background;
        if (bg == 0) {
            return periodFor(hour);
        }
        if (bg == 5) {
            return SCENE_SIMPLE;
        }
        return bg - 1;
    }

    private function isSleepHour(hour as Number) as Boolean {
        return hour >= 23 || hour < 6;
    }

    private function displayHour(hour as Number) as Number {
        if (System.getDeviceSettings().is24Hour) {
            return hour;
        }
        var h = hour % 12;
        return h == 0 ? 12 : h;
    }

    // =====================================================================
    // 픽셀아트 스타일
    // =====================================================================
    private function drawPixelFace(dc as Dc, clock as System.ClockTime, scene as Number, ci as Number,
                                   frame as Number, bob as Number, flicker as Boolean, anim as Boolean) as Void {
        var ox = _ox;
        var oy = _oy;
        drawScene(dc, scene, clock, anim);
        drawStepRing(dc);

        var shadow = 0x2B2B3A;
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        // 날짜
        var date = _days[(info.day_of_week as Number) - 1] + " " + (info.day as Number).format("%d") + " "
                   + _months[(info.month as Number) - 1];
        Pix.drawTextShadow(dc, date, 180 + ox, 34 + oy, 3, 0xFFFFFF, shadow);

        // 시각
        var h = displayHour(clock.hour);
        var is24 = System.getDeviceSettings().is24Hour;
        var colon = !anim || (clock.sec % 2) == 0;
        dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
        Pix.drawTime(dc, h, clock.min, 180 + ox + 4, 60 + oy + 4, 7, colon, is24);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        Pix.drawTime(dc, h, clock.min, 180 + ox, 60 + oy, 7, colon, is24);
        if (!is24) {
            var ampm = clock.hour < 12 ? "AM" : "PM";
            Pix.drawTextShadow(dc, ampm, 290 + ox, 64 + oy, 2, 0xFFFFFF, shadow);
        }

        // 캐릭터 + 그림자
        var s = 5;
        var cw = (Sprites.W[ci] as Number) * s;
        var ch = (Sprites.H[ci] as Number) * s;
        var cx = 180 + ox - cw / 2;
        var cy = 256 + oy - ch;
        var shadowColor = scene == SCENE_SIMPLE ? 0x222222 : ((_grass[scene] as Array)[3] as Number);
        dc.setColor(shadowColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(180 + ox - 44, 252 + oy, 88, 5);
        dc.fillRectangle(180 + ox - 32, 257 + oy, 64, 4);
        Pix.drawCharacter(dc, ci, frame, cx, cy + bob, s, flicker, -1);
        if (frame == FRAME_SLEEP) {
            drawZzz(dc, ci, cx, cy, s, clock.sec, anim);
        }

        // 정보 패널
        drawPixelPanel(dc, ox, oy);
    }

    private function drawScene(dc as Dc, scene as Number, clock as System.ClockTime, anim as Boolean) as Void {
        if (scene == SCENE_SIMPLE) {
            dc.setColor(0x000000, 0x000000);
            dc.clear();
            return;
        }
        var ox = _ox;
        var oy = _oy;
        var sky = _sky[scene] as Array;
        var grass = _grass[scene] as Array;
        var groundY = 246 + oy;

        // 하늘 띠 (6단 + 디더링)
        for (var i = 0; i < 6; i++) {
            var y0 = groundY * i / 6;
            var y1 = groundY * (i + 1) / 6;
            dc.setColor(sky[i] as Number, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, y0, _w, y1 - y0);
        }
        for (var i = 1; i < 6; i++) {
            var yb = groundY * i / 6;
            dc.setColor(sky[i] as Number, Graphics.COLOR_TRANSPARENT);
            var dxx = (i % 2) * 4;
            while (dxx < _w) {
                dc.fillRectangle(dxx, yb - 4, 4, 4);
                dxx += 8;
            }
        }

        // 해 / 달 / 별
        var sun = _sunColor[scene];
        dc.setColor(sun, Graphics.COLOR_TRANSPARENT);
        if (scene == 0) {
            Pix.disc(dc, 78 + ox, 196 + oy, 22, 4);
        } else if (scene == 1) {
            Pix.disc(dc, 292 + ox, 150 + oy, 20, 4);
            dc.fillRectangle(292 + ox - 2, 150 + oy - 34, 4, 8);
            dc.fillRectangle(292 + ox - 2, 150 + oy + 26, 4, 8);
            dc.fillRectangle(292 + ox - 34, 150 + oy - 2, 8, 4);
            dc.fillRectangle(292 + ox + 26, 150 + oy - 2, 8, 4);
        } else if (scene == 2) {
            Pix.disc(dc, 270 + ox, 244 + oy, 28, 4);
        } else {
            Pix.disc(dc, 288 + ox, 148 + oy, 18, 4);
            dc.setColor(sky[3] as Number, Graphics.COLOR_TRANSPARENT);
            Pix.disc(dc, 298 + ox, 140 + oy, 16, 4);
            // 별 (반짝임)
            for (var i = 0; i < _stars.size() / 2; i++) {
                if (anim && ((clock.sec + i * 3) % 7) == 0) {
                    continue;
                }
                var sx = _stars[i * 2] + ox;
                var sy = _stars[i * 2 + 1] + oy;
                dc.setColor(i % 3 == 0 ? 0xFFF2B0 : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                if (i % 4 == 0) {
                    dc.fillRectangle(sx - 2, sy - 6, 4, 12);
                    dc.fillRectangle(sx - 6, sy - 2, 12, 4);
                } else {
                    dc.fillRectangle(sx - 2, sy - 2, 4, 4);
                }
            }
        }

        // 구름 (분 단위로 천천히 이동)
        if (scene != 3) {
            dc.setColor(_cloud[scene], Graphics.COLOR_TRANSPARENT);
            drawCloud(dc, ((clock.min * 3 + 40) % 440) - 60 + ox, 128 + oy);
            drawCloud(dc, ((clock.min * 2 + 250) % 440) - 60 + ox, 186 + oy);
        }

        // 먼 언덕
        dc.setColor(grass[0] as Number, Graphics.COLOR_TRANSPARENT);
        Pix.disc(dc, 70 + ox, 268 + oy, 64, 4);
        Pix.disc(dc, 300 + ox, 276 + oy, 76, 4);

        // 땅
        dc.setColor(grass[2] as Number, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, _w, _h - groundY);
        dc.setColor(grass[1] as Number, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, _w, 6);
        var x = 0;
        while (x < _w) {
            dc.fillRectangle(x, groundY + 6, 4, 4);
            x += 12;
        }
        // 풀 무늬
        dc.setColor(grass[3] as Number, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 14; i++) {
            var gx = (i * 53 + 17) % 360 + ox;
            var gy = groundY + 20 + (i * 29) % 90;
            dc.fillRectangle(gx, gy, 4, 8);
            dc.fillRectangle(gx + 6, gy + 2, 4, 6);
        }
    }

    private function drawCloud(dc as Dc, x as Number, y as Number) as Void {
        dc.fillRectangle(x + 12, y, 20, 8);
        dc.fillRectangle(x + 4, y + 8, 44, 8);
        dc.fillRectangle(x, y + 16, 56, 8);
    }

    private function drawStepRing(dc as Dc) as Void {
        var lit = _goal > 0 ? (_steps * 60 / _goal) : 0;
        if (lit > 60) {
            lit = 60;
        }
        var done = _steps >= _goal;
        for (var i = 0; i < 60; i++) {
            if (i < lit) {
                dc.setColor(done ? 0x7CFC8A : 0xFFD23F, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_ringX[i] - 3, _ringY[i] - 3, 6, 6);
            } else {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_ringX[i] - 1, _ringY[i] - 1, 2, 2);
            }
        }
    }

    private function drawZzz(dc as Dc, ci as Number, cx as Number, cy as Number, s as Number,
                             sec as Number, anim as Boolean) as Void {
        var head = Sprites.HEAD[ci] as Array;
        var hx = cx + (head[1] as Number) * s;
        var hy = cy + (head[0] as Number) * s;
        var phase = anim ? (sec % 4) : 3;
        var sizes = [2, 3, 4];
        var dx = [4, 16, 32];
        var dy = [-14, -32, -56];
        for (var i = 0; i < 3; i++) {
            if (i < phase) {
                Pix.drawTextShadow(dc, "Z", hx + dx[i], hy + dy[i], sizes[i], 0xFFFFFF, 0x2B2B3A);
            }
        }
    }

    private function drawPixelPanel(dc as Dc, ox as Number, oy as Number) as Void {
        var x0 = 100 + ox;
        var y0 = 270 + oy;
        var pw = 160;
        var ph = 52;
        // 나무 판자 (모서리 픽셀 깎기)
        dc.setColor(0x8B5E3C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + 4, y0, pw - 8, ph);
        dc.fillRectangle(x0, y0 + 4, pw, ph - 8);
        dc.setColor(0x3B2A20, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 + 4, y0 + 4, pw - 8, ph - 8);

        var text = 0xFFF3D6;
        var lx = x0 + 12;
        var rx = x0 + 88;
        var r1 = y0 + 12;
        var r2 = y0 + 30;

        dc.setColor(0xFF4D6D, Graphics.COLOR_TRANSPARENT);
        Pix.drawIcon(dc, Pix.ICON_HEART, lx, r1, 2);
        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        Pix.drawText(dc, _hr == null ? "--" : (_hr as Number).format("%d"), lx + 14, r1, 2);

        dc.setColor(_bat <= 20 ? 0xFF5252 : 0x7CFC8A, Graphics.COLOR_TRANSPARENT);
        Pix.drawIcon(dc, Pix.ICON_BATT, rx, r1, 2);
        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        Pix.drawText(dc, _bat.format("%d") + "%", rx + 14, r1, 2);

        dc.setColor(0x4FC3F7, Graphics.COLOR_TRANSPARENT);
        Pix.drawIcon(dc, Pix.ICON_BOLT, lx, r2, 2);
        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        Pix.drawText(dc, _bb == null ? "--" : (_bb as Number).format("%d"), lx + 14, r2, 2);

        dc.setColor(0xFFC94D, Graphics.COLOR_TRANSPARENT);
        Pix.drawIcon(dc, Pix.ICON_STEPS, rx, r2, 2);
        dc.setColor(text, Graphics.COLOR_TRANSPARENT);
        Pix.drawText(dc, stepsText(), rx + 14, r2, 2);
    }

    private function stepsText() as String {
        if (_steps >= 100000) {
            return (_steps / 1000).format("%d") + "K";
        }
        return _steps.format("%d");
    }

    // =====================================================================
    // 디지털 스타일
    // =====================================================================
    private function drawDigitalFace(dc as Dc, clock as System.ClockTime, scene as Number, ci as Number,
                                     frame as Number, bob as Number, flicker as Boolean, anim as Boolean) as Void {
        var ox = _ox;
        var oy = _oy;
        var cx = 180 + ox;
        var ti = scene == SCENE_SIMPLE ? 4 : scene;
        var accent = _digAccent[ti];

        dc.setColor(_digBg[ti], _digBg[ti]);
        dc.clear();
        // 아래쪽 행성 언덕
        dc.setColor(_digHill[ti], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, 440 + oy, 200);

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // 좌: 배터리 / 우: 걸음 아크
        var r = 170;
        dc.setPenWidth(8);
        dc.setColor(0x333842, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, 180 + oy, r, Graphics.ARC_COUNTER_CLOCKWISE, 300, 60);
        dc.drawArc(cx, 180 + oy, r, Graphics.ARC_CLOCKWISE, 240, 120);

        var fs = _goal > 0 ? _steps.toFloat() / _goal : 0.0;
        if (fs > 1.0) {
            fs = 1.0;
        }
        if (fs > 0.01) {
            var endS = (300 + (120 * fs).toNumber()) % 360;
            dc.setColor(_steps >= _goal ? 0x7CFC8A : accent, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, 180 + oy, r, Graphics.ARC_COUNTER_CLOCKWISE, 300, endS);
        }
        var fb = _bat / 100.0;
        if (fb > 0.01) {
            var endB = 240 - (120 * fb).toNumber();
            dc.setColor(_bat <= 20 ? 0xFF5252 : 0x7CFC8A, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, 180 + oy, r, Graphics.ARC_CLOCKWISE, 240, endB);
        }
        dc.setPenWidth(1);

        // 날짜
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var date = info.day_of_week + " " + (info.day as Number).format("%d") + " " + info.month;
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 56 + oy, Graphics.FONT_TINY, date, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 시각
        var is24 = System.getDeviceSettings().is24Hour;
        var h = displayHour(clock.hour);
        var hs = is24 ? h.format("%02d") : h.format("%d");
        var time = hs + ":" + clock.min.format("%02d");
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 122 + oy, Graphics.FONT_NUMBER_HOT, time, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (!is24) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 124, 96 + oy, Graphics.FONT_XTINY, clock.hour < 12 ? "AM" : "PM",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }

        // 캐릭터 (작게)
        var s = 4;
        var cw = (Sprites.W[ci] as Number) * s;
        var ch = (Sprites.H[ci] as Number) * s;
        var px = cx - cw / 2;
        var py = 252 + oy - ch;
        Pix.drawCharacter(dc, ci, frame, px, py + bob, s, flicker, -1);
        if (frame == FRAME_SLEEP) {
            var phase = anim ? (clock.sec % 4) : 3;
            var head = Sprites.HEAD[ci] as Array;
            var hx = px + (head[1] as Number) * s;
            var hy = py + (head[0] as Number) * s;
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            if (phase > 0) { Pix.drawText(dc, "Z", hx + 2, hy - 8, 2); }
            if (phase > 1) { Pix.drawText(dc, "Z", hx + 12, hy - 22, 2); }
            if (phase > 2) { Pix.drawText(dc, "Z", hx + 24, hy - 38, 3); }
        }

        // 정보 3칸
        var cols = [cx - 70, cx, cx + 70];
        var icons = [Pix.ICON_HEART, Pix.ICON_BOLT, Pix.ICON_STEPS];
        var colors = [0xFF4D6D, 0x4FC3F7, accent];
        var vals = [_hr == null ? "--" : (_hr as Number).format("%d"),
                    _bb == null ? "--" : (_bb as Number).format("%d"),
                    stepsText()];
        for (var i = 0; i < 3; i++) {
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            Pix.drawIcon(dc, icons[i], cols[i] - 5, 262 + oy, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cols[i], 292 + oy, Graphics.FONT_TINY, vals[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        // 배터리 %
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 326 + oy, Graphics.FONT_XTINY, _bat.format("%d") + "%",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // =====================================================================
    // AOD (항상 켜짐) - 번인 방지: 켜진 픽셀 최소화 + 매분 위치 이동
    // =====================================================================
    private function drawAod(dc as Dc, clock as System.ClockTime, ci as Number) as Void {
        dc.setColor(0x000000, 0x000000);
        dc.clear();
        var m = clock.min;
        var dx = ((m % 5) - 2) * 4;
        var dy = (((m / 5) % 5) - 2) * 4;
        var cx = 180 + _ox + dx;
        var oy = _oy + dy;
        var is24 = System.getDeviceSettings().is24Hour;
        var h = displayHour(clock.hour);

        if (Settings.style == 0) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var date = _days[(info.day_of_week as Number) - 1] + " " + (info.day as Number).format("%d");
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            Pix.drawText(dc, date, cx - Pix.textWidth(date, 2) / 2, 78 + oy, 2);
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            Pix.drawTime(dc, h, m, cx, 100 + oy, 5, true, is24);
        } else {
            var hs = is24 ? h.format("%02d") : h.format("%d");
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 120 + oy, Graphics.FONT_NUMBER_MEDIUM, hs + ":" + m.format("%02d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // 잠자는 캐릭터 외곽선만
        var s = 3;
        var cw = (Sprites.W[ci] as Number) * s;
        var ch = (Sprites.H[ci] as Number) * s;
        Pix.drawCharacter(dc, ci, FRAME_SLEEP, cx - cw / 2, 256 + oy - ch, s, false, 0x5A5A5A);

        // 분마다 도는 점
        var a = m * Math.PI / 30.0;
        var px = (180 + _ox + 158 * Math.sin(a)).toNumber();
        var py = (180 + _oy - 158 * Math.cos(a)).toNumber();
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 2, py - 2, 4, 4);
    }

    // =====================================================================
    // 데이터 읽기
    // =====================================================================
    private function readStats() as Void {
        // 심박
        _hr = null;
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null) {
            _hr = ai.currentHeartRate;
        }
        if (_hr == null && (ActivityMonitor has :getHeartRateHistory)) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            if (it != null) {
                var sample = it.next();
                if (sample != null && sample.heartRate != null
                    && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    _hr = sample.heartRate;
                }
            }
        }

        // 배터리
        _bat = System.getSystemStats().battery.toNumber();

        // 걸음
        var am = ActivityMonitor.getInfo();
        _steps = (am.steps != null) ? (am.steps as Number) : 0;
        var g = am.stepGoal;
        _goal = (g != null && (g as Number) > 0) ? (g as Number) : 10000;

        // Body Battery
        _bb = null;
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var bi = SensorHistory.getBodyBatteryHistory({:period => 1});
            if (bi != null) {
                var b = bi.next();
                if (b != null && b.data != null) {
                    _bb = (b.data as Numeric).toNumber();
                }
            }
        }
    }
}
