// 워치 코드(source/*.mc)를 그대로 옮긴 미리보기 렌더러.
// MochiFaceView.mc / Pix.mc / Smooth.mc 를 수정하면 이 파일도 같이 맞춰 주세요.
(function () {
  const S = window.SPRITES;
  const TRANSPARENT = -1;

  // ---- Garmin Dc 흉내 ----
  class Dc {
    constructor(ctx, w, h) { this.ctx = ctx; this.w = w; this.h = h; this.fg = 0xffffff; this.bg = 0; this.pen = 1; }
    hex(c) { return '#' + (c >>> 0).toString(16).padStart(6, '0'); }
    setColor(fg, bg) { this.fg = fg; if (bg !== undefined && bg !== TRANSPARENT) this.bg = bg; }
    clear() { this.ctx.fillStyle = this.hex(this.bg); this.ctx.fillRect(0, 0, this.w, this.h); }
    fillRectangle(x, y, w, h) { this.ctx.fillStyle = this.hex(this.fg); this.ctx.fillRect(x, y, w, h); }
    fillCircle(x, y, r) { const c = this.ctx; c.fillStyle = this.hex(this.fg); c.beginPath(); c.arc(x, y, Math.max(0, r), 0, Math.PI * 2); c.fill(); }
    fillEllipse(x, y, a, b) { const c = this.ctx; c.fillStyle = this.hex(this.fg); c.beginPath(); c.ellipse(x, y, Math.max(0, a), Math.max(0, b), 0, 0, Math.PI * 2); c.fill(); }
    setPenWidth(p) { this.pen = p; }
    drawLine(x1, y1, x2, y2) { const c = this.ctx; c.strokeStyle = this.hex(this.fg); c.lineWidth = this.pen; c.lineCap = 'round'; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke(); }
    // Garmin: 0도 = 3시, 반시계 방향이 +
    drawArc(x, y, r, dir, a0, a1) {
      const c = this.ctx; c.strokeStyle = this.hex(this.fg); c.lineWidth = this.pen; c.lineCap = 'butt';
      c.beginPath(); c.arc(x, y, r, -a0 * Math.PI / 180, -a1 * Math.PI / 180, dir === 'ccw'); c.stroke();
    }
    drawText(x, y, font, text) {
      const c = this.ctx; c.fillStyle = this.hex(this.fg);
      c.font = FONTS[font]; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(text, x, y);
    }
  }
  // FR265S 시스템 폰트 대략치
  const FONTS = {
    XTINY: '600 19px "Roboto Condensed", "Arial Narrow", sans-serif',
    TINY: '600 25px "Roboto Condensed", "Arial Narrow", sans-serif',
    NUMBER_MEDIUM: '700 64px "Roboto Condensed", "Arial Narrow", sans-serif',
    NUMBER_HOT: '700 92px "Roboto Condensed", "Arial Narrow", sans-serif',
  };
  const T = Math.trunc;

  // 외부 에셋 (preview/assets.js, tools/fetch_assets.py 가 만듦)
  const ASSETS = {};
  const AD = window.ASSET_DATA || {};
  for (const ci of Object.keys(AD)) {
    const load = uri => { const im = new Image(); im.src = uri; return im; };
    ASSETS[ci] = { sizes: {}, aod: load(AD[ci].aod) };
    for (const s of Object.keys(AD[ci].sizes)) ASSETS[ci].sizes[s] = [].concat(AD[ci].sizes[s]).map(load);
  }
  // 표정 이미지가 없으면 기본 표정 (워치의 Assets.get 과 같음)
  function assetImage(ci, s, override, frame) {
    const a = ASSETS[ci]; if (!a) return null;
    const fr = a.sizes[s];
    const im = override >= 0 ? (s === 3 ? a.aod : null) : (fr ? (fr[frame] || fr[0]) : null);
    return im && im.complete && im.naturalWidth ? im : null;
  }

  // ---- Pix 모듈 ----
  const Pix = {
    drawRuns(dc, runs, pal, x, y, s, override) {
      let last = -1;
      if (override >= 0) dc.setColor(override, TRANSPARENT);
      for (const v of runs) {
        const c = (v >> 18) & 0xf;
        if (override >= 0) { if (c !== 1) break; }
        else if (c !== last) { dc.setColor(pal[c], TRANSPARENT); last = c; }
        dc.fillRectangle(x + (v & 0x3f) * s, y + ((v >> 6) & 0x3f) * s, ((v >> 12) & 0x3f) * s, s);
      }
    },
    drawCharacter(dc, ci, frame, x, y, s, flicker, override) {
      const ch = S.chars[ci];
      Pix.drawRuns(dc, ch.base, ch.pal, x, y, s, override);
      if (frame > 0) Pix.drawRuns(dc, ch.face[frame - 1], ch.pal, x, y, s, override);
      if (flicker && ch.extra.length > 0 && override < 0) Pix.drawRuns(dc, ch.extra, ch.pal, x, y, s, -1);
    },
    drawBits(dc, g, cols, rows, x, y, s) {
      for (let r = 0; r < rows; r++) {
        let c = 0;
        while (c < cols) {
          if ((g >> (r * cols + c)) & 1) {
            const st = c; while (c < cols && ((g >> (r * cols + c)) & 1)) c++;
            dc.fillRectangle(x + st * s, y + r * s, (c - st) * s, s);
          } else c++;
        }
      }
    },
    drawIcon(dc, icon, x, y, s) { Pix.drawBits(dc, S.font.icons[icon], 5, 5, x, y, s); },
    textWidth(t, s) { return t.length * 4 * s - s; },
    drawText(dc, t, x, y, s) {
      const u = t.toUpperCase();
      for (let i = 0; i < u.length; i++) {
        const idx = S.font.chars.indexOf(u[i]);
        if (idx >= 0) Pix.drawBits(dc, S.font.small[idx], 3, 5, x + i * 4 * s, y, s);
      }
    },
    drawTextShadow(dc, t, cx, y, s, color, shadow) {
      const x = cx - T(Pix.textWidth(t, s) / 2);
      dc.setColor(shadow, TRANSPARENT); Pix.drawText(dc, t, x + s, y + s, s);
      dc.setColor(color, TRANSPARENT); Pix.drawText(dc, t, x, y, s);
    },
    drawRows(dc, rows, cols, x, y, s) {
      for (let r = 0; r < rows.length; r++) {
        const m = rows[r]; let c = 0;
        while (c < cols) {
          if ((m >> c) & 1) { const st = c; while (c < cols && ((m >> c) & 1)) c++; dc.fillRectangle(x + st * s, y + r * s, (c - st) * s, s); }
          else c++;
        }
      }
    },
    drawBigDigit(dc, d, x, y, s) { Pix.drawRows(dc, S.font.big[d], 5, x, y, s); },
    drawHangul(dc, idx, x, y, s) { Pix.drawRows(dc, S.font.hangul[idx], 7, x, y, s); },
    koDate(dc, month, day, dow, x, y, sd, sh, draw) {
      let cx = x; const dy = y + 10 * sh - 5 * sd, space = sh * 3;
      if (month > 0) {
        const m = String(month);
        if (draw) Pix.drawText(dc, m, cx, dy, sd);
        cx += Pix.textWidth(m, sd) + sd;
        if (draw) Pix.drawHangul(dc, 1, cx, y, sh);
        cx += 7 * sh + space;
      }
      const d = String(day);
      if (draw) Pix.drawText(dc, d, cx, dy, sd);
      cx += Pix.textWidth(d, sd) + sd;
      if (draw) Pix.drawHangul(dc, 0, cx, y, sh);
      cx += 7 * sh + space;
      if (draw) Pix.drawHangul(dc, dow, cx, y, sh);
      cx += 7 * sh;
      return cx - x;
    },
    drawKoDate(dc, month, day, dow, cx, y, sd, sh, color, shadow) {
      const x = cx - T(Pix.koDate(dc, month, day, dow, 0, 0, sd, sh, false) / 2);
      if (shadow >= 0) { dc.setColor(shadow, TRANSPARENT); Pix.koDate(dc, month, day, dow, x + sh, y + sh, sd, sh, true); }
      dc.setColor(color, TRANSPARENT); Pix.koDate(dc, month, day, dow, x, y, sd, sh, true);
    },
    drawTime(dc, h, m, cx, y, s, colon, leadingZero) {
      let x = cx - T(27 * s / 2);
      if (h < 10 && !leadingZero) x -= 3 * s;
      if (h >= 10 || leadingZero) Pix.drawBigDigit(dc, T(h / 10), x, y, s);
      Pix.drawBigDigit(dc, h % 10, x + 6 * s, y, s);
      if (colon) { dc.fillRectangle(x + 13 * s, y + 2 * s, s, s); dc.fillRectangle(x + 13 * s, y + 4 * s, s, s); }
      Pix.drawBigDigit(dc, T(m / 10), x + 16 * s, y, s);
      Pix.drawBigDigit(dc, m % 10, x + 22 * s, y, s);
    },
    disc(dc, cx, cy, r, u) {
      for (let dy = -r; dy < r; dy += u) {
        const mid = dy + T(u / 2); const sq = r * r - mid * mid;
        if (sq > 0) { let hw = T(Math.sqrt(sq)); hw = T((hw + T(u / 2)) / u) * u; dc.fillRectangle(cx - hw, cy + dy, hw * 2, u); }
      }
    },
  };
  const ICON = { HEART: 0, BOLT: 1, STEPS: 2, BATT: 3, FLAME: 4, PIN: 5, STAIRS: 6, WAVE: 7, SUN: 8, CLOUD: 9, RAIN: 10, SNOW: 11, BELL: 12 };

  // ---- Smooth 모듈 (벡터 캐릭터) ----
  const Smooth = {
    drawCharacter(dc, ci, frame, x, y, size, flicker, override) {
      const m = S.smooth[ci], k = size / 1000;
      let grow = T(size * 0.03); if (grow < 2) grow = 2;
      const outline = override >= 0 ? override : m.outline;
      Smooth.shapes(dc, m.body, x, y, k, grow, outline);
      Smooth.shapes(dc, m.body, x, y, k, 0, override >= 0 ? 0 : -1);
      if (override < 0) {
        if (flicker && m.extra.length > 0) { Smooth.shapes(dc, m.extra, x, y, k, grow, outline); Smooth.shapes(dc, m.extra, x, y, k, 0, -1); }
        Smooth.shapes(dc, m.detail, x, y, k, 0, -1);
      }
      Smooth.shapes(dc, m.face[frame], x, y, k, 0, override);
      dc.setPenWidth(1);
    },
    shapes(dc, list, x, y, k, grow, color) {
      for (const sh of list) {
        const t = sh[0];
        if (grow > 0 && t >= 4) continue;
        dc.setColor(color >= 0 ? color : sh[1], TRANSPARENT);
        const cx = x + T(sh[2] * k), cy = y + T(sh[3] * k);
        if (t === 0) dc.fillCircle(cx, cy, T(sh[4] * k) + grow);
        else if (t === 1) dc.fillEllipse(cx, cy, T(sh[4] * k) + grow, T(sh[5] * k) + grow);
        else if (t === 4) { dc.setPenWidth(Smooth.pen(sh[5], k)); dc.drawArc(cx, cy, T(sh[4] * k), 'ccw', sh[6], sh[7]); }
        else if (t === 5) { dc.setPenWidth(Smooth.pen(sh[6], k)); dc.drawLine(cx, cy, x + T(sh[4] * k), y + T(sh[5] * k)); }
      }
    },
    pen(w, k) { const p = T(w * k + 0.5); return p < 1 ? 1 : p; },
  };

  // ---- 색 테이블 (MochiFaceView.mc 와 동일) ----
  const SKY = [
    [0xF7A8B8, 0xF9B9BE, 0xFBCAC2, 0xFDDCC6, 0xFFE9C9, 0xFFF3D6],
    [0x3FA9F5, 0x5AB8F7, 0x75C6F9, 0x90D3FB, 0xABE0FD, 0xC6ECFF],
    [0x3A2C6E, 0x6A3A7E, 0x9C4A7E, 0xCF5F6E, 0xF08A5D, 0xFFB26B],
    [0x070B24, 0x0C1433, 0x121C42, 0x182552, 0x1F2E61, 0x273870]];
  const GRASS = [
    [0xC9A3C8, 0xA8E08C, 0x7FC96A, 0x5FA84F], [0x6FAFD8, 0x9BE07A, 0x6CCB4E, 0x4FA63A],
    [0x7A4A7E, 0x8FA35A, 0x6E8544, 0x546A33], [0x1A2350, 0x2F6A4A, 0x214F37, 0x173B29]];
  const CLOUD = [0xFFF4F6, 0xFFFFFF, 0xF6B8A0, 0x000000];
  const SUN = [0xFFD66B, 0xFFE45C, 0xFF7A45, 0xFFF2B0];
  const DIG_BG = [0x2A1B2E, 0x0E2238, 0x26142F, 0x05060D, 0x000000];
  const DIG_HILL = [0x3A2640, 0x16324F, 0x351C40, 0x0C0F1E, 0x111111];
  const DIG_ACCENT = [0xFF9BB3, 0x4FC3F7, 0xFF8A50, 0xB39DDB, 0xFFD23F];
  const ACCENTS = [0, 0xFF9BB3, 0x4FC3F7, 0xFF8A50, 0x64E3B4, 0xB39DDB, 0xFFD23F];
  const STARS = [70, 110, 110, 70, 150, 150, 230, 60, 300, 110, 50, 190, 320, 190, 200, 20, 260, 140, 95, 160, 140, 40, 285, 60];
  const DAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  const DAYS_MED = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const MONTHS_MED = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const SLEEP_HOURS = [21, 22, 23, 0, 1], WAKE_HOURS = [5, 6, 7, 8, 9];
  const FRAME_OPEN = 0, FRAME_BLINK = 1, FRAME_YAWN = 2, FRAME_SLEEP = 3, FRAME_HAPPY = 4, SCENE_SIMPLE = -1;
  const ICON_WX = [8, 9, 10, 11], WX_COLORS = [0xFFD23F, 0xB0BEC5, 0x64B5F6, 0xFFFFFF];
  function moonPhase(nowSec) {
    let p = (nowSec - 947182440) / 86400 / 29.530588853; p -= Math.floor(p);
    return T(p * 8 + 0.5) % 8;
  }
  const CHARACTER_COUNT = 4;

  const RING = [];
  for (let i = 0; i < 60; i++) {
    const a = i * Math.PI / 30;
    RING.push([T(T(180 + 171 * Math.sin(a)) / 2) * 2, T(T(180 - 171 * Math.cos(a)) / 2) * 2]);
  }
  const periodFor = h => (h >= 5 && h < 10) ? 0 : (h >= 10 && h < 17) ? 1 : (h >= 17 && h < 20) ? 2 : 3;
  const fmt2 = n => String(n).padStart(2, '0');

  function render(ctx, st) {
    const dc = new Dc(ctx, 360, 360);
    const W = 360, H = 360;
    const displayHour = h => st.is24 ? h : (h % 12 === 0 ? 12 : h % 12);
    const ci = st.character < CHARACTER_COUNT ? st.character : st.day % CHARACTER_COUNT;
    const smooth = st.charStyle === 0 ? st.style === 1 : st.charStyle === 2;
    const korean = st.dateLang === 0 ? st.watchKorean : st.dateLang === 2;
    const sleepH = SLEEP_HOURS[st.sleepAt], wakeH = WAKE_HOURS[st.wakeAt];
    const isSleepHour = h => sleepH > wakeH ? (h >= sleepH || h < wakeH) : (h >= sleepH && h < wakeH);
    const accentColor = fb => st.accent === 0 ? fb : ACCENTS[st.accent];
    const stepsText = () => st.steps >= 100000 ? T(st.steps / 1000) + 'K' : String(st.steps);
    const numText = v => v == null ? '--' : String(v);

    function drawChar(ci, frame, cx, baseline, s, bob, flicker, override) {
      if (smooth) {
        const size = s * 22, x = cx - T(size / 2), y = baseline - size;
        const im = assetImage(ci, s, override, frame);
        if (im) { dc.ctx.drawImage(im, x, y + bob); return [x + T(size * 3 / 4), y + T(size / 8)]; }
        Smooth.drawCharacter(dc, ci, frame, x, y + bob, size, flicker, override);
        const hd = S.smooth[ci].head;
        return [x + T(hd[1] * size / 100), y + T(hd[0] * size / 100)];
      }
      const ch = S.chars[ci], h = ch.h * s, px = cx - T(ch.anchor2 * s / 2), py = baseline - h;
      Pix.drawCharacter(dc, ci, frame, px, py + bob, s, flicker, override);
      return [px + ch.head[1] * s, py + ch.head[0] * s];
    }
    function charScale(ci, sizes, maxH) {
      let s = sizes[st.charSize];
      const h = smooth ? 22 : S.chars[ci].h;
      while (s > 2 && h * s > maxH) s--;
      return s;
    }
    function slotInfo(slot) {
      switch (st.slots[slot]) {
        case 1: return [ICON.HEART, 0xFF4D6D, numText(st.hr)];
        case 2: return [ICON.BOLT, 0x4FC3F7, numText(st.bb)];
        case 3: return [ICON.STEPS, 0xFFC94D, stepsText()];
        case 4: return [ICON.BATT, st.bat <= 20 ? 0xFF5252 : 0x7CFC8A, st.bat + '%'];
        case 5: return [ICON.FLAME, 0xFF8A50, String(st.cal)];
        case 6: return [ICON.PIN, 0x9CCC65, st.dist.toFixed(1)];
        case 7: return [ICON.STAIRS, 0xBA68C8, numText(st.floors)];
        case 8: return [ICON.WAVE, 0xFFB74D, numText(st.stress)];
        case 9: { const k = st.wx < 0 ? 0 : st.wx; return [ICON_WX[k], WX_COLORS[k], st.temp == null ? '--' : st.temp + '°']; }
        case 10: return [ICON.BELL, 0xFFB74D, String(st.notif)];
      }
      return null;
    }
    function ringInfo(accent) {
      switch (st.ring) {
        case 0: { const f = st.goal > 0 ? st.steps / st.goal : 0; return [f > 1 ? 1 : f, st.steps >= st.goal ? 0x7CFC8A : accent]; }
        case 1: return [st.bat / 100, st.bat <= 20 ? 0xFF5252 : 0x7CFC8A];
        case 2: return [st.bb == null ? 0 : st.bb / 100, 0x4FC3F7];
        case 3: return [st.sec / 60, accent];
      }
      return null;
    }
    function drawZzz(hx, hy, sec, anim, color, big) {
      const phase = anim ? sec % 4 : 3;
      const sizes = big ? [2, 3, 4] : [2, 2, 3], dx = big ? [4, 16, 32] : [2, 12, 24], dy = big ? [-14, -32, -56] : [-8, -22, -38];
      for (let i = 0; i < 3; i++) if (i < phase) {
        if (big) Pix.drawTextShadow(dc, 'Z', hx + dx[i], hy + dy[i], sizes[i], color, 0x2B2B3A);
        else { dc.setColor(color, TRANSPARENT); Pix.drawText(dc, 'Z', hx + dx[i], hy + dy[i], sizes[i]); }
      }
    }

    if (st.aod) return drawAod();

    function periodNow() {
      const mins = st.hour * 60 + st.min, sr = st.sunrise, ss = st.sunset;
      if (sr >= 0 && ss - sr > 240) {
        if (mins >= sr - 30 && mins < sr + 180) return 0;
        if (mins >= sr + 180 && mins < ss - 60) return 1;
        if (mins >= ss - 60 && mins < ss + 60) return 2;
        return 3;
      }
      return periodFor(st.hour);
    }
    const moon = moonPhase(st.nowSec);
    function drawMoon(x, y, r, skyColor) {
      const p = moon;
      if (p === 0) { dc.setColor(0x3A4478, TRANSPARENT); Pix.disc(dc, x, y, r, 4); return; }
      dc.setColor(SUN[3], TRANSPARENT); Pix.disc(dc, x, y, r, 4);
      if (p === 4) return;
      const waxing = p < 4, q = waxing ? p : 8 - p;
      dc.setColor(skyColor, TRANSPARENT);
      if (q === 2) dc.fillRectangle(waxing ? x - r - 4 : x, y - r - 4, r + 4, 2 * r + 8);
      else { const off = q === 1 ? T(r * 6 / 10) : T(r * 3 / 2); Pix.disc(dc, waxing ? x - off : x + off, y, r, 4); }
    }
    function drawWeatherFx(bottom, pixel, night) {
      if (!st.weatherFx || st.wx < 1) return;
      const t = anim ? sec : 0;
      if (st.wx === 1) {
        if (pixel) { dc.setColor(night ? 0x39426B : 0xDCE3EA, TRANSPARENT); cloud((st.min * 4 + 150) % 440 - 60, 96); cloud((st.min * 3 + 330) % 440 - 60, 160); }
      } else if (st.wx === 2) {
        dc.setColor(pixel ? 0xCFE3FF : 0x5A7BA8, TRANSPARENT);
        for (let i = 0; i < 18; i++) dc.fillRectangle((i * 47 + 13) % 360, (i * 53 + t * 24) % bottom, 2, 8);
      } else {
        dc.setColor(pixel ? 0xFFFFFF : 0x9AA4B5, TRANSPARENT);
        const sz = pixel ? 4 : 3;
        for (let i = 0; i < 16; i++) dc.fillRectangle((i * 61 + 29 + (t % 2) * 2) % 360, (i * 37 + t * 8) % bottom, sz, sz);
      }
    }
    const scene = st.background === 0 ? periodNow() : st.background === 5 ? SCENE_SIMPLE : st.background - 1;
    const anim = st.animate, sec = st.sec;
    let frame = FRAME_OPEN, bob = 0;
    if (isSleepHour(st.hour)) { frame = FRAME_SLEEP; if (anim && sec % 4 < 2) bob = 2; }
    else if (anim) {
      if (st.hour >= wakeH && st.hour < wakeH + 3 && sec % 15 >= 7 && sec % 15 <= 8) frame = FRAME_YAWN;
      else if (sec % 5 === 4) frame = FRAME_BLINK;
      if (sec % 2 === 1) bob = -3;
    }
    if (frame === FRAME_OPEN && st.steps >= st.goal) frame = FRAME_HAPPY;
    const flicker = anim && sec % 2 === 1;
    if (st.style === 0) pixelFace(); else digitalFace();
    return;

    function pixelFace() {
      const accent = accentColor(0xFFD23F), shadow = 0x2B2B3A;
      drawScene();
      const ring = ringInfo(accent);
      if (ring) {
        let lit = T(ring[0] * 60); if (lit > 60) lit = 60;
        for (let i = 0; i < 60; i++) {
          if (i < lit) { dc.setColor(ring[1], TRANSPARENT); dc.fillRectangle(RING[i][0] - 3, RING[i][1] - 3, 6, 6); }
          else { dc.setColor(0xFFFFFF, TRANSPARENT); dc.fillRectangle(RING[i][0] - 1, RING[i][1] - 1, 2, 2); }
        }
      }
      if (st.showDate) {
        if (korean) Pix.drawKoDate(dc, st.month + 1, st.date, st.dow, 180, 30, 3, 2, 0xFFFFFF, shadow);
        else Pix.drawTextShadow(dc, DAYS[st.dow] + ' ' + st.date + ' ' + MONTHS[st.month], 180, 34, 3, 0xFFFFFF, shadow);
      }
      const h = displayHour(st.hour), colon = !anim || sec % 2 === 0, timeY = st.showDate ? 60 : 50;
      dc.setColor(shadow, TRANSPARENT); Pix.drawTime(dc, h, st.min, 184, timeY + 4, 7, colon, st.is24);
      dc.setColor(st.timeColor === 1 ? accent : 0xFFFFFF, TRANSPARENT); Pix.drawTime(dc, h, st.min, 180, timeY, 7, colon, st.is24);
      if (!st.is24) Pix.drawTextShadow(dc, st.hour < 12 ? 'AM' : 'PM', 290, timeY + 4, 2, 0xFFFFFF, shadow);

      const s = charScale(ci, [4, 5, 6], 136);
      dc.setColor(scene === SCENE_SIMPLE ? 0x222222 : GRASS[scene][3], TRANSPARENT);
      dc.fillRectangle(136, 252, 88, 5); dc.fillRectangle(148, 257, 64, 4);
      const head = drawChar(ci, frame, 180, 256, s, bob, flicker, -1);
      if (frame === FRAME_SLEEP) drawZzz(head[0], head[1], sec, anim, 0xFFFFFF, true);

      const x0 = 100, y0 = 270, pw = 160, ph = 52;
      dc.setColor(0x8B5E3C, TRANSPARENT); dc.fillRectangle(x0 + 4, y0, pw - 8, ph); dc.fillRectangle(x0, y0 + 4, pw, ph - 8);
      dc.setColor(0x3B2A20, TRANSPARENT); dc.fillRectangle(x0 + 4, y0 + 4, pw - 8, ph - 8);
      const xs = [x0 + 12, x0 + 88, x0 + 12, x0 + 88], ys = [y0 + 12, y0 + 12, y0 + 30, y0 + 30];
      for (let i = 0; i < 4; i++) {
        const info = slotInfo(i); if (!info) continue;
        dc.setColor(info[1], TRANSPARENT); Pix.drawIcon(dc, info[0], xs[i], ys[i], 2);
        dc.setColor(0xFFF3D6, TRANSPARENT); Pix.drawText(dc, info[2], xs[i] + 14, ys[i], 2);
      }
    }

    function drawScene() {
      if (scene === SCENE_SIMPLE) { dc.setColor(0, 0); dc.clear(); return; }
      const sky = SKY[scene], grass = GRASS[scene], groundY = 246;
      for (let i = 0; i < 6; i++) {
        const y0 = T(groundY * i / 6), y1 = T(groundY * (i + 1) / 6);
        dc.setColor(sky[i], TRANSPARENT); dc.fillRectangle(0, y0, W, y1 - y0);
      }
      for (let i = 1; i < 6; i++) {
        const yb = T(groundY * i / 6); dc.setColor(sky[i], TRANSPARENT);
        for (let x = (i % 2) * 4; x < W; x += 8) dc.fillRectangle(x, yb - 4, 4, 4);
      }
      dc.setColor(SUN[scene], TRANSPARENT);
      if (scene === 0) Pix.disc(dc, 78, 196, 22, 4);
      else if (scene === 1) {
        Pix.disc(dc, 292, 150, 20, 4);
        dc.fillRectangle(290, 116, 4, 8); dc.fillRectangle(290, 176, 4, 8); dc.fillRectangle(258, 148, 8, 4); dc.fillRectangle(318, 148, 8, 4);
      } else if (scene === 2) Pix.disc(dc, 270, 244, 28, 4);
      else {
        drawMoon(288, 148, 18, sky[3]);
      }
      dc.setColor(grass[0], TRANSPARENT); Pix.disc(dc, 70, 268, 64, 4); Pix.disc(dc, 300, 276, 76, 4);
      dc.setColor(grass[2], TRANSPARENT); dc.fillRectangle(0, groundY, W, H - groundY);
      dc.setColor(grass[1], TRANSPARENT); dc.fillRectangle(0, groundY, W, 6);
      for (let x = 0; x < W; x += 12) dc.fillRectangle(x, groundY + 6, 4, 4);
      dc.setColor(grass[3], TRANSPARENT);
      for (let i = 0; i < 14; i++) {
        const gx = (i * 53 + 17) % 360, gy = groundY + 20 + (i * 29) % 90;
        dc.fillRectangle(gx, gy, 4, 8); dc.fillRectangle(gx + 6, gy + 2, 4, 6);
      }
      // 여기까지 고정 배경 (워치에서는 버퍼 비트맵에 캐시) / 아래는 매번 그림
      if (scene === 3) {
        for (let i = 0; i < STARS.length / 2; i++) {
          if (anim && (sec + i * 3) % 7 === 0) continue;
          const sx = STARS[i * 2], sy = STARS[i * 2 + 1];
          dc.setColor(i % 3 === 0 ? 0xFFF2B0 : 0xFFFFFF, TRANSPARENT);
          if (i % 4 === 0) { dc.fillRectangle(sx - 2, sy - 6, 4, 12); dc.fillRectangle(sx - 6, sy - 2, 12, 4); }
          else dc.fillRectangle(sx - 2, sy - 2, 4, 4);
        }
      } else {
        dc.setColor(CLOUD[scene], TRANSPARENT);
        cloud((st.min * 3 + 40) % 440 - 60, 128); cloud((st.min * 2 + 250) % 440 - 60, 186);
      }
      drawWeatherFx(240, true, scene === 3);
    }
    function cloud(x, y) { dc.fillRectangle(x + 12, y, 20, 8); dc.fillRectangle(x + 4, y + 8, 44, 8); dc.fillRectangle(x, y + 16, 56, 8); }

    function digitalFace() {
      const cx = 180, ti = scene === SCENE_SIMPLE ? 4 : scene, accent = accentColor(DIG_ACCENT[ti]);
      dc.setColor(DIG_BG[ti], DIG_BG[ti]); dc.clear();
      dc.setColor(DIG_HILL[ti], TRANSPARENT); dc.fillCircle(cx, 440, 200);
      drawWeatherFx(250, false, ti === 3);
      const r = 170;
      dc.setPenWidth(8); dc.setColor(0x333842, TRANSPARENT); dc.drawArc(cx, 180, r, 'cw', 240, 120);
      const ring = ringInfo(accent);
      if (ring) {
        dc.setColor(0x333842, TRANSPARENT); dc.drawArc(cx, 180, r, 'ccw', 300, 60);
        if (ring[0] > 0.01) { dc.setColor(ring[1], TRANSPARENT); dc.drawArc(cx, 180, r, 'ccw', 300, (300 + T(120 * ring[0])) % 360); }
      }
      const fb = st.bat / 100;
      if (fb > 0.01) { dc.setColor(st.bat <= 20 ? 0xFF5252 : 0x7CFC8A, TRANSPARENT); dc.drawArc(cx, 180, r, 'cw', 240, 240 - T(120 * fb)); }
      dc.setPenWidth(1);
      if (st.showDate) {
        if (korean) Pix.drawKoDate(dc, st.month + 1, st.date, st.dow, cx, 38, 3, 2, 0xCCCCCC, -1);
        else { dc.setColor(0xBBBBBB, TRANSPARENT); dc.drawText(cx, 50, 'TINY', DAYS_MED[st.dow] + ' ' + st.date + ' ' + MONTHS_MED[st.month]); }
      }
      const h = displayHour(st.hour), timeY = st.showDate ? 112 : 104;
      dc.setColor(st.timeColor === 1 ? accent : 0xFFFFFF, TRANSPARENT);
      dc.drawText(cx, timeY, 'NUMBER_HOT', (st.is24 ? fmt2(h) : String(h)) + ':' + fmt2(st.min));
      if (!st.is24) { dc.setColor(accent, TRANSPARENT); dc.drawText(cx + 124, timeY - 26, 'XTINY', st.hour < 12 ? 'AM' : 'PM'); }

      const s = charScale(ci, [3, 4, 5], 110);
      const head = drawChar(ci, frame, cx, 256, s, bob, flicker, -1);
      if (frame === FRAME_SLEEP) drawZzz(head[0], head[1], sec, anim, accent, false);

      const cols = [cx - 70, cx, cx + 70];
      for (let i = 0; i < 3; i++) {
        const info = slotInfo(i); if (!info) continue;
        dc.setColor(info[1], TRANSPARENT); Pix.drawIcon(dc, info[0], cols[i] - 5, 264, 2);
        dc.setColor(0xFFFFFF, TRANSPARENT); dc.drawText(cols[i], 293, 'TINY', info[2]);
      }
      const i4 = slotInfo(3);
      if (i4) {
        dc.setColor(i4[1], TRANSPARENT); Pix.drawIcon(dc, i4[0], cx - 30, 321, 2);
        dc.setColor(0xBBBBBB, TRANSPARENT); dc.drawText(cx + 6, 326, 'XTINY', i4[2]);
      }
    }

    function drawAod() {
      dc.setColor(0, 0); dc.clear();
      const m = st.min, dx = (m % 5 - 2) * 4, dy = (T(m / 5) % 5 - 2) * 4;
      const cx = 180 + dx, oy = dy, h = displayHour(st.hour);
      if (st.showDate) {
        if (korean) Pix.drawKoDate(dc, 0, st.date, st.dow, cx, 70 + oy, 2, 2, 0x777777, -1);
        else { const date = DAYS[st.dow] + ' ' + st.date; dc.setColor(0x777777, TRANSPARENT); Pix.drawText(dc, date, cx - T(Pix.textWidth(date, 2) / 2), 78 + oy, 2); }
      }
      if (st.style === 0) { dc.setColor(0xAAAAAA, TRANSPARENT); Pix.drawTime(dc, h, m, cx, 100 + oy, 5, true, st.is24); }
      else { dc.setColor(0xAAAAAA, TRANSPARENT); dc.drawText(cx, 124 + oy, 'NUMBER_MEDIUM', (st.is24 ? fmt2(h) : String(h)) + ':' + fmt2(m)); }
      drawChar(ci, FRAME_SLEEP, cx, 256 + oy, 3, 0, false, 0x5A5A5A);
      const a = m * Math.PI / 30;
      dc.setColor(0x888888, TRANSPARENT);
      dc.fillRectangle(T(180 + 158 * Math.sin(a)) - 2, T(180 - 158 * Math.cos(a)) - 2, 4, 4);
      dc.setColor(0, TRANSPARENT);
      for (let y = m % 2; y < H; y += 2) dc.fillRectangle(0, y, W, 1);
    }
  }

  window.WatchFace = { render };
})();
