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
    private var _stress as Number or Null = null;
    private var _floors as Number or Null = null;
    private var _bat as Number = 0;
    private var _steps as Number = 0;
    private var _goal as Number = 10000;
    private var _cal as Number = 0;
    private var _dist as Float = 0.0;   // km 또는 mi
    private var _sec as Number = 0;

    // 에셋 비트맵 캐시 (한 장만 들고 있음)
    private var _bmpId as ResourceId or Null = null;
    private var _bmp as BitmapResource or Null = null;

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
    // 강조색 설정 (0 = 자동)
    private var _accents as Array<Number> = [0, 0xFF9BB3, 0x4FC3F7, 0xFF8A50, 0x64E3B4, 0xB39DDB, 0xFFD23F] as Array<Number>;

    private var _stars as Array<Number> = [
        70, 110, 110, 70, 150, 150, 230, 60, 300, 110, 50, 190,
        320, 190, 200, 20, 260, 140, 95, 160, 140, 40, 285, 60
    ] as Array<Number>;

    private var _days as Array<String> = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Array<String>;
    private var _months as Array<String> = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                                            "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"] as Array<String>;
    private var _daysMed as Array<String> = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as Array<String>;
    private var _monthsMed as Array<String> = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as Array<String>;

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
        _sec = clock.sec;
        var ci = Settings.currentCharacter();

        if (_lowPower && _burnIn) {
            drawAod(dc, clock, ci);
            return;
        }

        readStats();
        var scene = sceneFor(clock.hour);
        var anim = Settings.animate && !_lowPower;
        var sec = clock.sec;

        // 캐릭터 상태 (시간대 기준)
        var frame = FRAME_OPEN;
        var bob = 0;
        if (isSleepHour(clock.hour)) {
            frame = FRAME_SLEEP;
            if (anim && (sec % 4) < 2) {
                bob = 2;
            }
        } else if (anim) {
            if (isYawnHour(clock.hour) && (sec % 15) >= 7 && (sec % 15) <= 8) {
                frame = FRAME_YAWN;
            } else if ((sec % 5) == 4) {
                frame = FRAME_BLINK;
            }
            if ((sec % 2) == 1) {
                bob = -3;
            }
        }
        var flicker = anim && (sec % 2) == 1;

        if (Settings.get(Settings.STYLE) == 0) {
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
        var bg = Settings.get(Settings.BACKGROUND);
        if (bg == 0) {
            return periodFor(hour);
        }
        if (bg == 5) {
            return SCENE_SIMPLE;
        }
        return bg - 1;
    }

    private function isSleepHour(hour as Number) as Boolean {
        var st = Settings.sleepHour();
        var wk = Settings.wakeHour();
        if (st > wk) {
            return hour >= st || hour < wk;
        }
        return hour >= st && hour < wk;
    }

    private function isYawnHour(hour as Number) as Boolean {
        var wk = Settings.wakeHour();
        return hour >= wk && hour < wk + 3;
    }

    private function displayHour(hour as Number) as Number {
        if (System.getDeviceSettings().is24Hour) {
            return hour;
        }
        var h = hour % 12;
        return h == 0 ? 12 : h;
    }

    // 강조색 (자동이면 fallback)
    private function accentColor(fallback as Number) as Number {
        var a = Settings.get(Settings.ACCENT);
        return a == 0 ? fallback : _accents[a];
    }

    // =====================================================================
    // 캐릭터 (픽셀 / 디지털 공용)
    //   cx: 가운데 x, baseline: 발바닥 y, s: 픽셀 배율
    //   반환: [머리 오른쪽 위 x, y] (Zzz 위치)
    // =====================================================================
    private function drawChar(dc as Dc, ci as Number, frame as Number, cx as Number, baseline as Number,
                              s as Number, bob as Number, flicker as Boolean, override as Number) as Array<Number> {
        if (Settings.smoothCharacter()) {
            var size = s * 22;
            var x = cx - size / 2;
            var y = baseline - size;
            // 외부 에셋 비트맵이 있으면 사용 (tools/fetch_assets.py)
            var rid = override >= 0 ? (s == 3 ? Assets.aod(ci) : null) : Assets.get(ci, s);
            if (rid != null) {
                dc.drawBitmap(x, y + bob, bitmap(rid));
                return [x + size * 3 / 4, y + size / 8] as Array<Number>;
            }
            Smooth.drawCharacter(dc, ci, frame, x, y + bob, size, flicker, override);
            var head = Sprites.SM_HEAD[ci] as Array<Number>;
            return [x + head[1] * size / 100, y + head[0] * size / 100] as Array<Number>;
        }
        var w = (Sprites.W[ci] as Number) * s;
        var h = (Sprites.H[ci] as Number) * s;
        var px = cx - w / 2;
        var py = baseline - h;
        Pix.drawCharacter(dc, ci, frame, px, py + bob, s, flicker, override);
        var hd = Sprites.HEAD[ci] as Array<Number>;
        return [px + hd[1] * s, py + hd[0] * s] as Array<Number>;
    }

    private function bitmap(rid as ResourceId) as BitmapResource {
        if (_bmp == null || _bmpId != rid) {
            _bmp = WatchUi.loadResource(rid) as BitmapResource;
            _bmpId = rid;
        }
        return _bmp as BitmapResource;
    }

    // 크기 설정 → 배율 (maxH 를 넘지 않게)
    private function charScale(ci as Number, sizes as Array<Number>, maxH as Number) as Number {
        var s = sizes[Settings.get(Settings.CHAR_SIZE)];
        var h = Settings.smoothCharacter() ? 22 : (Sprites.H[ci] as Number);
        while (s > 2 && h * s > maxH) {
            s--;
        }
        return s;
    }

    // =====================================================================
    // 정보 칸
    // =====================================================================
    // [아이콘, 색, 글자] / 없음이면 null
    private function slotInfo(slot as Number) as Array or Null {
        var t = Settings.get(Settings.SLOT1 + slot);
        if (t == Settings.DATA_HR) {
            return [Pix.ICON_HEART, 0xFF4D6D, numText(_hr)];
        } else if (t == Settings.DATA_BB) {
            return [Pix.ICON_BOLT, 0x4FC3F7, numText(_bb)];
        } else if (t == Settings.DATA_STEPS) {
            return [Pix.ICON_STEPS, 0xFFC94D, stepsText()];
        } else if (t == Settings.DATA_BATTERY) {
            return [Pix.ICON_BATT, _bat <= 20 ? 0xFF5252 : 0x7CFC8A, _bat.format("%d") + "%"];
        } else if (t == Settings.DATA_CALORIES) {
            return [Pix.ICON_FLAME, 0xFF8A50, _cal.format("%d")];
        } else if (t == Settings.DATA_DISTANCE) {
            return [Pix.ICON_PIN, 0x9CCC65, _dist.format("%.1f")];
        } else if (t == Settings.DATA_FLOORS) {
            return [Pix.ICON_STAIRS, 0xBA68C8, numText(_floors)];
        } else if (t == Settings.DATA_STRESS) {
            return [Pix.ICON_WAVE, 0xFFB74D, numText(_stress)];
        }
        return null;
    }

    private function numText(v as Number or Null) as String {
        return v == null ? "--" : (v as Number).format("%d");
    }

    private function stepsText() as String {
        if (_steps >= 100000) {
            return (_steps / 1000).format("%d") + "K";
        }
        return _steps.format("%d");
    }

    // 바깥 링 진행률 [0~1, 색]. 끄기면 null
    private function ringInfo(accent as Number) as Array or Null {
        var r = Settings.get(Settings.RING);
        if (r == 0) {
            var f = _goal > 0 ? _steps.toFloat() / _goal : 0.0;
            return [f > 1.0 ? 1.0 : f, _steps >= _goal ? 0x7CFC8A : accent];
        } else if (r == 1) {
            return [_bat / 100.0, _bat <= 20 ? 0xFF5252 : 0x7CFC8A];
        } else if (r == 2) {
            return [_bb == null ? 0.0 : (_bb as Number) / 100.0, 0x4FC3F7];
        } else if (r == 3) {
            return [_sec / 60.0, accent];
        }
        return null;
    }

    // =====================================================================
    // 픽셀아트 스타일
    // =====================================================================
    private function drawPixelFace(dc as Dc, clock as System.ClockTime, scene as Number, ci as Number,
                                   frame as Number, bob as Number, flicker as Boolean, anim as Boolean) as Void {
        var ox = _ox;
        var oy = _oy;
        var accent = accentColor(0xFFD23F);
        drawScene(dc, scene, clock, anim);
        drawTickRing(dc, ringInfo(accent));

        var shadow = 0x2B2B3A;

        // 날짜
        if (Settings.showDate) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dow = (info.day_of_week as Number) - 1;
            if (Settings.koreanDate()) {
                Pix.drawKoDate(dc, info.month as Number, info.day as Number, dow, 180 + ox, 30 + oy, 3, 2,
                               0xFFFFFF, shadow);
            } else {
                var date = _days[dow] + " " + (info.day as Number).format("%d") + " "
                           + _months[(info.month as Number) - 1];
                Pix.drawTextShadow(dc, date, 180 + ox, 34 + oy, 3, 0xFFFFFF, shadow);
            }
        }

        // 시각
        var h = displayHour(clock.hour);
        var is24 = System.getDeviceSettings().is24Hour;
        var colon = !anim || (clock.sec % 2) == 0;
        var timeY = Settings.showDate ? 60 : 50;
        dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
        Pix.drawTime(dc, h, clock.min, 180 + ox + 4, timeY + oy + 4, 7, colon, is24);
        dc.setColor(Settings.get(Settings.TIME_COLOR) == 1 ? accent : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        Pix.drawTime(dc, h, clock.min, 180 + ox, timeY + oy, 7, colon, is24);
        if (!is24) {
            var ampm = clock.hour < 12 ? "AM" : "PM";
            Pix.drawTextShadow(dc, ampm, 290 + ox, timeY + 4 + oy, 2, 0xFFFFFF, shadow);
        }

        // 캐릭터 + 그림자
        var s = charScale(ci, [4, 5, 6] as Array<Number>, 136);
        var shadowColor = scene == SCENE_SIMPLE ? 0x222222 : ((_grass[scene] as Array)[3] as Number);
        dc.setColor(shadowColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(180 + ox - 44, 252 + oy, 88, 5);
        dc.fillRectangle(180 + ox - 32, 257 + oy, 64, 4);
        var head = drawChar(dc, ci, frame, 180 + ox, 256 + oy, s, bob, flicker, -1);
        if (frame == FRAME_SLEEP) {
            drawZzz(dc, head[0], head[1], clock.sec, anim, 0xFFFFFF, true);
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
        dc.setColor(_sunColor[scene], Graphics.COLOR_TRANSPARENT);
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
        var gx0 = 0;
        while (gx0 < _w) {
            dc.fillRectangle(gx0, groundY + 6, 4, 4);
            gx0 += 12;
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

    private function drawTickRing(dc as Dc, ring as Array or Null) as Void {
        if (ring == null) {
            return;
        }
        var lit = ((ring[0] as Float) * 60).toNumber();
        if (lit > 60) {
            lit = 60;
        }
        for (var i = 0; i < 60; i++) {
            if (i < lit) {
                dc.setColor(ring[1] as Number, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_ringX[i] - 3, _ringY[i] - 3, 6, 6);
            } else {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(_ringX[i] - 1, _ringY[i] - 1, 2, 2);
            }
        }
    }

    // big = true 면 크기 2/3/4 + 그림자, 아니면 2/2/3
    private function drawZzz(dc as Dc, hx as Number, hy as Number, sec as Number, anim as Boolean,
                             color as Number, big as Boolean) as Void {
        var phase = anim ? (sec % 4) : 3;
        var sizes = big ? [2, 3, 4] : [2, 2, 3];
        var dx = big ? [4, 16, 32] : [2, 12, 24];
        var dy = big ? [-14, -32, -56] : [-8, -22, -38];
        for (var i = 0; i < 3; i++) {
            if (i < phase) {
                if (big) {
                    Pix.drawTextShadow(dc, "Z", hx + dx[i], hy + dy[i], sizes[i], color, 0x2B2B3A);
                } else {
                    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                    Pix.drawText(dc, "Z", hx + dx[i], hy + dy[i], sizes[i]);
                }
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

        var xs = [x0 + 12, x0 + 88, x0 + 12, x0 + 88];
        var ys = [y0 + 12, y0 + 12, y0 + 30, y0 + 30];
        for (var i = 0; i < 4; i++) {
            var info = slotInfo(i);
            if (info == null) {
                continue;
            }
            dc.setColor(info[1] as Number, Graphics.COLOR_TRANSPARENT);
            Pix.drawIcon(dc, info[0] as Number, xs[i], ys[i], 2);
            dc.setColor(0xFFF3D6, Graphics.COLOR_TRANSPARENT);
            Pix.drawText(dc, info[2] as String, xs[i] + 14, ys[i], 2);
        }
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
        var accent = accentColor(_digAccent[ti]);

        dc.setColor(_digBg[ti], _digBg[ti]);
        dc.clear();
        // 아래쪽 행성 언덕
        dc.setColor(_digHill[ti], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, 440 + oy, 200);

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // 좌: 배터리 / 우: 바깥 링 설정
        var r = 170;
        dc.setPenWidth(8);
        dc.setColor(0x333842, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, 180 + oy, r, Graphics.ARC_CLOCKWISE, 240, 120);
        var ring = ringInfo(accent);
        if (ring != null) {
            dc.setColor(0x333842, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, 180 + oy, r, Graphics.ARC_COUNTER_CLOCKWISE, 300, 60);
            var f = ring[0] as Float;
            if (f > 0.01) {
                var endS = (300 + (120 * f).toNumber()) % 360;
                dc.setColor(ring[1] as Number, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, 180 + oy, r, Graphics.ARC_COUNTER_CLOCKWISE, 300, endS);
            }
        }
        var fb = _bat / 100.0;
        if (fb > 0.01) {
            var endB = 240 - (120 * fb).toNumber();
            dc.setColor(_bat <= 20 ? 0xFF5252 : 0x7CFC8A, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, 180 + oy, r, Graphics.ARC_CLOCKWISE, 240, endB);
        }
        dc.setPenWidth(1);

        // 날짜 (영어: 시스템 글꼴 / 한글: 픽셀 한글)
        if (Settings.showDate) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dow = (info.day_of_week as Number) - 1;
            if (Settings.koreanDate()) {
                if (dc has :setAntiAlias) {
                    dc.setAntiAlias(false);
                }
                Pix.drawKoDate(dc, info.month as Number, info.day as Number, dow, cx, 45 + oy, 2, 2, 0xBBBBBB, -1);
                if (dc has :setAntiAlias) {
                    dc.setAntiAlias(true);
                }
            } else {
                var date = _daysMed[dow] + " " + (info.day as Number).format("%d") + " "
                           + _monthsMed[(info.month as Number) - 1];
                dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, 56 + oy, Graphics.FONT_TINY, date,
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // 시각
        var is24 = System.getDeviceSettings().is24Hour;
        var h = displayHour(clock.hour);
        var hs = is24 ? h.format("%02d") : h.format("%d");
        var time = hs + ":" + clock.min.format("%02d");
        var timeY = Settings.showDate ? 118 : 108;
        dc.setColor(Settings.get(Settings.TIME_COLOR) == 1 ? accent : 0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, timeY + oy, Graphics.FONT_NUMBER_HOT, time,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (!is24) {
            dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 124, timeY - 26 + oy, Graphics.FONT_XTINY, clock.hour < 12 ? "AM" : "PM",
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }

        // 캐릭터
        var s = charScale(ci, [3, 4, 5] as Array<Number>, 100);
        var head = drawChar(dc, ci, frame, cx, 256 + oy, s, bob, flicker, -1);
        if (frame == FRAME_SLEEP) {
            drawZzz(dc, head[0], head[1], clock.sec, anim, accent, false);
        }

        // 정보 칸 1~3 (가로 3칸) + 4 (아래)
        var cols = [cx - 70, cx, cx + 70];
        for (var i = 0; i < 3; i++) {
            var info = slotInfo(i);
            if (info == null) {
                continue;
            }
            dc.setColor(info[1] as Number, Graphics.COLOR_TRANSPARENT);
            Pix.drawIcon(dc, info[0] as Number, cols[i] - 5, 264 + oy, 2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cols[i], 293 + oy, Graphics.FONT_TINY, info[2] as String,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var i4 = slotInfo(3);
        if (i4 != null) {
            dc.setColor(i4[1] as Number, Graphics.COLOR_TRANSPARENT);
            Pix.drawIcon(dc, i4[0] as Number, cx - 30, 321 + oy, 2);
            dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 6, 326 + oy, Graphics.FONT_XTINY, i4[2] as String,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
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

        if (Settings.showDate) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dow = (info.day_of_week as Number) - 1;
            if (Settings.koreanDate()) {
                Pix.drawKoDate(dc, 0, info.day as Number, dow, cx, 70 + oy, 2, 2, 0x777777, -1);
            } else {
                var date = _days[dow] + " " + (info.day as Number).format("%d");
                dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
                Pix.drawText(dc, date, cx - Pix.textWidth(date, 2) / 2, 78 + oy, 2);
            }
        }

        if (Settings.get(Settings.STYLE) == 0) {
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            Pix.drawTime(dc, h, m, cx, 100 + oy, 5, true, is24);
        } else {
            var hs = is24 ? h.format("%02d") : h.format("%d");
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 124 + oy, Graphics.FONT_NUMBER_MEDIUM, hs + ":" + m.format("%02d"),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // 잠자는 캐릭터 외곽선만
        drawChar(dc, ci, FRAME_SLEEP, cx, 256 + oy, 3, 0, false, 0x5A5A5A);

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

        // 걸음 / 칼로리 / 거리 / 층수
        var am = ActivityMonitor.getInfo();
        _steps = (am.steps != null) ? (am.steps as Number) : 0;
        var g = am.stepGoal;
        _goal = (g != null && (g as Number) > 0) ? (g as Number) : 10000;
        _cal = (am.calories != null) ? (am.calories as Number) : 0;
        var cm = (am.distance != null) ? (am.distance as Number) : 0;
        var metric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
        _dist = metric ? cm / 100000.0 : cm / 160934.4;
        _floors = null;
        if (am has :floorsClimbed) {
            _floors = am.floorsClimbed;
        }

        // Body Battery / 스트레스
        _bb = null;
        _stress = null;
        if (Toybox has :SensorHistory) {
            if (SensorHistory has :getBodyBatteryHistory) {
                _bb = lastSample(SensorHistory.getBodyBatteryHistory({:period => 1}));
            }
            if (SensorHistory has :getStressHistory) {
                _stress = lastSample(SensorHistory.getStressHistory({:period => 1}));
            }
        }
    }

    private function lastSample(it) as Number or Null {
        if (it == null) {
            return null;
        }
        var s = it.next();
        if (s != null && s.data != null) {
            return (s.data as Numeric).toNumber();
        }
        return null;
    }
}
