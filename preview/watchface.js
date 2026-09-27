// 워치 코드(source/*.mc)를 그대로 옮긴 미리보기 렌더러.
// MochiFaceView.mc 를 수정하면 이 파일도 같이 맞춰 주세요.
(function () {
  const S = window.SPRITES;
  const TRANSPARENT = -1;

  // ---- Garmin Dc 흉내 ----
  class Dc {
    constructor(ctx, w, h) { this.ctx = ctx; this.w = w; this.h = h; this.fg = 0xffffff; this.bg = 0; this.pen = 1; }
    hex(c) { return '#' + (c >>> 0).toString(16).padStart(6, '0'); }
    getWidth() { return this.w; }
    getHeight() { return this.h; }
    setColor(fg, bg) { this.fg = fg; if (bg !== undefined && bg !== TRANSPARENT) this.bg = bg; }
    clear() { this.ctx.fillStyle = this.hex(this.bg); this.ctx.fillRect(0, 0, this.w, this.h); }
    fillRectangle(x, y, w, h) { this.ctx.fillStyle = this.hex(this.fg); this.ctx.fillRect(x, y, w, h); }
    fillCircle(x, y, r) { const c = this.ctx; c.fillStyle = this.hex(this.fg); c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill(); }
    setPenWidth(p) { this.pen = p; }
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
      const x = cx - Math.trunc(Pix.textWidth(t, s) / 2);
      dc.setColor(shadow, TRANSPARENT); Pix.drawText(dc, t, x + s, y + s, s);
      dc.setColor(color, TRANSPARENT); Pix.drawText(dc, t, x, y, s);
    },
    drawBigDigit(dc, d, x, y, s) {
      const rows = S.font.big[d];
      for (let r = 0; r < 7; r++) {
        const m = rows[r]; let c = 0;
        while (c < 5) {
          if ((m >> c) & 1) { const st = c; while (c < 5 && ((m >> c) & 1)) c++; dc.fillRectangle(x + st * s, y + r * s, (c - st) * s, s); }
          else c++;
        }
      }
    },
    drawTime(dc, h, m, cx, y, s, colon, leadingZero) {
      const x = cx - Math.trunc(27 * s / 2);
      if (h >= 10 || leadingZero) Pix.drawBigDigit(dc, Math.trunc(h / 10), x, y, s);
      Pix.drawBigDigit(dc, h % 10, x + 6 * s, y, s);
      if (colon) { dc.fillRectangle(x + 13 * s, y + 2 * s, s, s); dc.fillRectangle(x + 13 * s, y + 4 * s, s, s); }
      Pix.drawBigDigit(dc, Math.trunc(m / 10), x + 16 * s, y, s);
      Pix.drawBigDigit(dc, m % 10, x + 22 * s, y, s);
    },
    disc(dc, cx, cy, r, u) {
      for (let dy = -r; dy < r; dy += u) {
        const mid = dy + Math.trunc(u / 2); const sq = r * r - mid * mid;
        if (sq > 0) { let hw = Math.trunc(Math.sqrt(sq)); hw = Math.trunc((hw + Math.trunc(u / 2)) / u) * u; dc.fillRectangle(cx - hw, cy + dy, hw * 2, u); }
      }
    },
  };
  const ICON_HEART = 0, ICON_BOLT = 1, ICON_STEPS = 2, ICON_BATT = 3;

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
  const STARS = [70, 110, 110, 70, 150, 150, 230, 60, 300, 110, 50, 190, 320, 190, 200, 20, 260, 140, 95, 160, 140, 40, 285, 60];
  const DAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  const DAYS_MED = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const MONTHS_MED = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const FRAME_OPEN = 0, FRAME_BLINK = 1, FRAME_YAWN = 2, FRAME_SLEEP = 3, SCENE_SIMPLE = -1;

  const RING = [];
  for (let i = 0; i < 60; i++) {
    const a = i * Math.PI / 30;
    RING.push([Math.trunc(Math.trunc(180 + 171 * Math.sin(a)) / 2) * 2, Math.trunc(Math.trunc(180 - 171 * Math.cos(a)) / 2) * 2]);
  }

  const periodFor = h => (h >= 5 && h < 10) ? 0 : (h >= 10 && h < 17) ? 1 : (h >= 17 && h < 20) ? 2 : 3;
  const isSleepHour = h => h >= 23 || h < 6;
  const fmt2 = n => String(n).padStart(2, '0');

  function render(ctx, st) {
    const dc = new Dc(ctx, 360, 360);
    const W = 360, H = 360;
    const displayHour = h => st.is24 ? h : (h % 12 === 0 ? 12 : h % 12);
    const ci = st.character < 3 ? st.character : st.day % 3;

    if (st.aod) return drawAod();

    const scene = st.background === 0 ? periodFor(st.hour) : st.background === 5 ? SCENE_SIMPLE : st.background - 1;
    const anim = st.animate;
    const sec = st.sec;
    let frame = FRAME_OPEN, bob = 0;
    if (isSleepHour(st.hour)) { frame = FRAME_SLEEP; if (anim && sec % 4 < 2) bob = 2; }
    else if (anim) {
      if (st.hour >= 6 && st.hour < 10 && sec % 15 >= 7 && sec % 15 <= 8) frame = FRAME_YAWN;
      else if (sec % 5 === 4) frame = FRAME_BLINK;
      if (sec % 2 === 1) bob = -3;
    }
    const flicker = anim && sec % 2 === 1;
    const stepsText = () => st.steps >= 100000 ? Math.trunc(st.steps / 1000) + 'K' : String(st.steps);

    if (st.style === 0) pixelFace(); else digitalFace();
    return;

    function pixelFace() {
      drawScene();
      // 걸음 링
      let lit = st.goal > 0 ? Math.trunc(st.steps * 60 / st.goal) : 0; if (lit > 60) lit = 60;
      const done = st.steps >= st.goal;
      for (let i = 0; i < 60; i++) {
        if (i < lit) { dc.setColor(done ? 0x7CFC8A : 0xFFD23F, TRANSPARENT); dc.fillRectangle(RING[i][0] - 3, RING[i][1] - 3, 6, 6); }
        else { dc.setColor(0xFFFFFF, TRANSPARENT); dc.fillRectangle(RING[i][0] - 1, RING[i][1] - 1, 2, 2); }
      }
      const shadow = 0x2B2B3A;
      Pix.drawTextShadow(dc, DAYS[st.dow] + ' ' + st.date + ' ' + MONTHS[st.month], 180, 34, 3, 0xFFFFFF, shadow);
      const h = displayHour(st.hour);
      const colon = !anim || sec % 2 === 0;
      dc.setColor(shadow, TRANSPARENT); Pix.drawTime(dc, h, st.min, 184, 64, 7, colon, st.is24);
      dc.setColor(0xFFFFFF, TRANSPARENT); Pix.drawTime(dc, h, st.min, 180, 60, 7, colon, st.is24);
      if (!st.is24) Pix.drawTextShadow(dc, st.hour < 12 ? 'AM' : 'PM', 290, 64, 2, 0xFFFFFF, shadow);

      const s = 5, ch = S.chars[ci];
      const cw = ch.w * s, chh = ch.h * s;
      const cx = 180 - Math.trunc(cw / 2), cy = 256 - chh;
      dc.setColor(scene === SCENE_SIMPLE ? 0x222222 : GRASS[scene][3], TRANSPARENT);
      dc.fillRectangle(136, 252, 88, 5); dc.fillRectangle(148, 257, 64, 4);
      Pix.drawCharacter(dc, ci, frame, cx, cy + bob, s, flicker, -1);
      if (frame === FRAME_SLEEP) {
        const hx = cx + ch.head[1] * s, hy = cy + ch.head[0] * s;
        const phase = anim ? sec % 4 : 3;
        const sizes = [2, 3, 4], dx = [4, 16, 32], dy = [-14, -32, -56];
        for (let i = 0; i < 3; i++) if (i < phase) Pix.drawTextShadow(dc, 'Z', hx + dx[i], hy + dy[i], sizes[i], 0xFFFFFF, 0x2B2B3A);
      }
      // 패널
      const x0 = 100, y0 = 270, pw = 160, ph = 52;
      dc.setColor(0x8B5E3C, TRANSPARENT); dc.fillRectangle(x0 + 4, y0, pw - 8, ph); dc.fillRectangle(x0, y0 + 4, pw, ph - 8);
      dc.setColor(0x3B2A20, TRANSPARENT); dc.fillRectangle(x0 + 4, y0 + 4, pw - 8, ph - 8);
      const text = 0xFFF3D6, lx = x0 + 12, rx = x0 + 88, r1 = y0 + 12, r2 = y0 + 30;
      const cell = (color, icon, x, y, str) => { dc.setColor(color, TRANSPARENT); Pix.drawIcon(dc, icon, x, y, 2); dc.setColor(text, TRANSPARENT); Pix.drawText(dc, str, x + 14, y, 2); };
      cell(0xFF4D6D, ICON_HEART, lx, r1, st.hr == null ? '--' : String(st.hr));
      cell(st.bat <= 20 ? 0xFF5252 : 0x7CFC8A, ICON_BATT, rx, r1, st.bat + '%');
      cell(0x4FC3F7, ICON_BOLT, lx, r2, st.bb == null ? '--' : String(st.bb));
      cell(0xFFC94D, ICON_STEPS, rx, r2, stepsText());
    }

    function drawScene() {
      if (scene === SCENE_SIMPLE) { dc.setColor(0, 0); dc.clear(); return; }
      const sky = SKY[scene], grass = GRASS[scene], groundY = 246;
      for (let i = 0; i < 6; i++) {
        const y0 = Math.trunc(groundY * i / 6), y1 = Math.trunc(groundY * (i + 1) / 6);
        dc.setColor(sky[i], TRANSPARENT); dc.fillRectangle(0, y0, W, y1 - y0);
      }
      for (let i = 1; i < 6; i++) {
        const yb = Math.trunc(groundY * i / 6); dc.setColor(sky[i], TRANSPARENT);
        for (let x = (i % 2) * 4; x < W; x += 8) dc.fillRectangle(x, yb - 4, 4, 4);
      }
      dc.setColor(SUN[scene], TRANSPARENT);
      if (scene === 0) Pix.disc(dc, 78, 196, 22, 4);
      else if (scene === 1) {
        Pix.disc(dc, 292, 150, 20, 4);
        dc.fillRectangle(290, 116, 4, 8); dc.fillRectangle(290, 176, 4, 8); dc.fillRectangle(258, 148, 8, 4); dc.fillRectangle(318, 148, 8, 4);
      } else if (scene === 2) Pix.disc(dc, 270, 244, 28, 4);
      else {
        Pix.disc(dc, 288, 148, 18, 4);
        dc.setColor(sky[3], TRANSPARENT); Pix.disc(dc, 298, 140, 16, 4);
        for (let i = 0; i < STARS.length / 2; i++) {
          if (anim && (sec + i * 3) % 7 === 0) continue;
          const sx = STARS[i * 2], sy = STARS[i * 2 + 1];
          dc.setColor(i % 3 === 0 ? 0xFFF2B0 : 0xFFFFFF, TRANSPARENT);
          if (i % 4 === 0) { dc.fillRectangle(sx - 2, sy - 6, 4, 12); dc.fillRectangle(sx - 6, sy - 2, 12, 4); }
          else dc.fillRectangle(sx - 2, sy - 2, 4, 4);
        }
      }
      if (scene !== 3) {
        dc.setColor(CLOUD[scene], TRANSPARENT);
        cloud((st.min * 3 + 40) % 440 - 60, 128); cloud((st.min * 2 + 250) % 440 - 60, 186);
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
    }
    function cloud(x, y) { dc.fillRectangle(x + 12, y, 20, 8); dc.fillRectangle(x + 4, y + 8, 44, 8); dc.fillRectangle(x, y + 16, 56, 8); }

    function digitalFace() {
      const cx = 180, ti = scene === SCENE_SIMPLE ? 4 : scene, accent = DIG_ACCENT[ti];
      dc.setColor(DIG_BG[ti], DIG_BG[ti]); dc.clear();
      dc.setColor(DIG_HILL[ti], TRANSPARENT); dc.fillCircle(cx, 440, 200);
      const r = 170;
      dc.setPenWidth(8); dc.setColor(0x333842, TRANSPARENT);
      dc.drawArc(cx, 180, r, 'ccw', 300, 60); dc.drawArc(cx, 180, r, 'cw', 240, 120);
      let fs = st.goal > 0 ? st.steps / st.goal : 0; if (fs > 1) fs = 1;
      if (fs > 0.01) { dc.setColor(st.steps >= st.goal ? 0x7CFC8A : accent, TRANSPARENT); dc.drawArc(cx, 180, r, 'ccw', 300, (300 + Math.trunc(120 * fs)) % 360); }
      const fb = st.bat / 100;
      if (fb > 0.01) { dc.setColor(st.bat <= 20 ? 0xFF5252 : 0x7CFC8A, TRANSPARENT); dc.drawArc(cx, 180, r, 'cw', 240, 240 - Math.trunc(120 * fb)); }
      dc.setPenWidth(1);
      dc.setColor(0xBBBBBB, TRANSPARENT); dc.drawText(cx, 56, 'TINY', DAYS_MED[st.dow] + ' ' + st.date + ' ' + MONTHS_MED[st.month]);
      const h = displayHour(st.hour);
      dc.setColor(0xFFFFFF, TRANSPARENT); dc.drawText(cx, 122, 'NUMBER_HOT', (st.is24 ? fmt2(h) : String(h)) + ':' + fmt2(st.min));
      if (!st.is24) { dc.setColor(accent, TRANSPARENT); dc.drawText(cx + 124, 96, 'XTINY', st.hour < 12 ? 'AM' : 'PM'); }

      const s = 4, ch = S.chars[ci], cw = ch.w * s, chh = ch.h * s;
      const px = cx - Math.trunc(cw / 2), py = 252 - chh;
      Pix.drawCharacter(dc, ci, frame, px, py + bob, s, flicker, -1);
      if (frame === FRAME_SLEEP) {
        const phase = anim ? sec % 4 : 3, hx = px + ch.head[1] * s, hy = py + ch.head[0] * s;
        dc.setColor(accent, TRANSPARENT);
        if (phase > 0) Pix.drawText(dc, 'Z', hx + 2, hy - 8, 2);
        if (phase > 1) Pix.drawText(dc, 'Z', hx + 12, hy - 22, 2);
        if (phase > 2) Pix.drawText(dc, 'Z', hx + 24, hy - 38, 3);
      }
      const cols = [cx - 70, cx, cx + 70], icons = [ICON_HEART, ICON_BOLT, ICON_STEPS];
      const colors = [0xFF4D6D, 0x4FC3F7, accent];
      const vals = [st.hr == null ? '--' : String(st.hr), st.bb == null ? '--' : String(st.bb), stepsText()];
      for (let i = 0; i < 3; i++) {
        dc.setColor(colors[i], TRANSPARENT); Pix.drawIcon(dc, icons[i], cols[i] - 5, 262, 2);
        dc.setColor(0xFFFFFF, TRANSPARENT); dc.drawText(cols[i], 292, 'TINY', vals[i]);
      }
      dc.setColor(0x999999, TRANSPARENT); dc.drawText(cx, 326, 'XTINY', st.bat + '%');
    }

    function drawAod() {
      dc.setColor(0, 0); dc.clear();
      const m = st.min, dx = (m % 5 - 2) * 4, dy = (Math.trunc(m / 5) % 5 - 2) * 4;
      const cx = 180 + dx, oy = dy, h = displayHour(st.hour);
      if (st.style === 0) {
        const date = DAYS[st.dow] + ' ' + st.date;
        dc.setColor(0x777777, TRANSPARENT); Pix.drawText(dc, date, cx - Math.trunc(Pix.textWidth(date, 2) / 2), 78 + oy, 2);
        dc.setColor(0xAAAAAA, TRANSPARENT); Pix.drawTime(dc, h, m, cx, 100 + oy, 5, true, st.is24);
      } else {
        dc.setColor(0xAAAAAA, TRANSPARENT); dc.drawText(cx, 120 + oy, 'NUMBER_MEDIUM', (st.is24 ? fmt2(h) : String(h)) + ':' + fmt2(m));
      }
      const s = 3, ch = S.chars[ci];
      Pix.drawCharacter(dc, ci, FRAME_SLEEP, cx - Math.trunc(ch.w * s / 2), 256 + oy - ch.h * s, s, false, 0x5A5A5A);
      const a = m * Math.PI / 30;
      dc.setColor(0x888888, TRANSPARENT);
      dc.fillRectangle(Math.trunc(180 + 158 * Math.sin(a)) - 2, Math.trunc(180 - 158 * Math.cos(a)) - 2, 4, 4);
    }
  }

  window.WatchFace = { render };
})();
