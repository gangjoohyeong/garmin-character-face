// 미리보기 렌더러로 설정 조합을 전부 그려서 점검한다 (Playwright 필요).
//   node render_matrix.mjs [출력 폴더]
//
//  - AOD: 켜진 픽셀 비율(가이드 10% 이하), 연속 2분 켜진 픽셀 수(0이어야 함)
//  - 일반 화면: 조합별 모아보기 이미지(sheet-*.png) → 겹침·잘림을 눈으로 확인
//
// preview/assets.js 가 있으면(에셋 생성 후) 이미지 캐릭터까지 포함된다.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(process.argv[2] || path.join(here, 'out'));
fs.mkdirSync(out, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 400, height: 400 } });
await page.goto('file://' + path.resolve(here, '../../preview/index.html'));
await page.waitForTimeout(800);

const result = await page.evaluate(() => {
  const base = {
    style: 0, character: 0, charStyle: 0, charSize: 1, background: 0, accent: 0, timeColor: 0, ring: 0,
    slots: [1, 4, 2, 3], showDate: true, dateLang: 2, watchKorean: true, sleepAt: 2, wakeAt: 1,
    animate: false, aod: false, is24: true, hour: 13, min: 58, sec: 30, dow: 6, date: 27, month: 8, day: 0,
    hr: 128, bat: 100, bb: 100, steps: 12345, goal: 10000, cal: 2888, dist: 12.3, floors: 18, stress: 88,
    scenery: 0, wx: 0, temp: -12, notif: 28, sunrise: 380, sunset: 1130, nowSec: 1790000000, weatherFx: true,
  };
  const cv = document.createElement('canvas'); cv.width = 360; cv.height = 360;
  const ctx = cv.getContext('2d', { willReadFrequently: true });
  function draw(st) {
    ctx.save(); ctx.fillStyle = '#000'; ctx.fillRect(0, 0, 360, 360);
    ctx.beginPath(); ctx.arc(180, 180, 180, 0, Math.PI * 2); ctx.clip();
    WatchFace.render(ctx, st); ctx.restore();
    return ctx.getImageData(0, 0, 360, 360).data;
  }
  const area = Math.PI * 180 * 180;
  // ---- AOD ----
  const aod = [];
  for (const style of [0, 1]) for (let character = 0; character < 2; character++) for (const charStyle of [1, 2]) {
    let maxRatio = 0, maxLum = 0, overlap = 0;
    let prev = null;
    for (let min = 0; min < 12; min++) {
      const d = draw({ ...base, style, character, charStyle, aod: true, hour: 10, min });
      let lit = 0, lum = 0;
      const cur = new Uint8Array(360 * 360);
      for (let i = 0, p = 0; i < d.length; i += 4, p++) {
        const l = Math.max(d[i], d[i + 1], d[i + 2]);
        if (l > 8) { lit++; lum += l / 255; cur[p] = 1; if (prev && prev[p]) overlap++; }
      }
      maxRatio = Math.max(maxRatio, lit / area); maxLum = Math.max(maxLum, lum / area);
      prev = cur;
    }
    aod.push({ style, character, charStyle, maxRatio, maxLum, overlap });
  }
  // ---- 그리기 호출 수 (워치의 dc 호출과 거의 1:1) ----
  const calls = [];
  {
    const P = CanvasRenderingContext2D.prototype;
    let n = 0;
    const wrap = k => { const f = P[k]; P[k] = function (...a) { n++; return f.apply(this, a); }; return () => { P[k] = f; }; };
    const undo = ['fillRect', 'fill', 'stroke', 'fillText', 'drawImage'].map(wrap);
    for (const style of [0, 1]) for (const charStyle of [1, 2]) for (let background = 0; background < 6; background++) {
      let max = 0;
      for (let character = 0; character < 2; character++) {
        n = 0; draw({ ...base, style, character, charStyle, background, hour: background === 4 ? 23 : 13 });
        max = Math.max(max, n - 1);   // 바탕 지우기 1회 제외
      }
      calls.push({ style, charStyle, background, max });
    }
    undo.forEach(u => u());
  }
  // ---- 일반 화면 모아보기 ----
  const sheets = {};
  function sheet(name, list) {
    const cols = 6, sz = 180, rows = Math.ceil(list.length / cols);
    const sc = document.createElement('canvas'); sc.width = cols * sz; sc.height = rows * (sz + 16);
    const sctx = sc.getContext('2d'); sctx.fillStyle = '#ddd'; sctx.fillRect(0, 0, sc.width, sc.height);
    list.forEach((o, i) => {
      draw({ ...base, ...o.st });
      const x = (i % cols) * sz, y = Math.floor(i / cols) * (sz + 16);
      sctx.drawImage(cv, x, y, sz, sz);
      sctx.fillStyle = '#222'; sctx.font = '11px sans-serif'; sctx.fillText(o.label, x + 4, y + sz + 12);
    });
    sheets[name] = sc.toDataURL('image/png');
  }
  const N = ['mochi', 'dorongi'];
  for (const style of [0, 1]) {
    const list = [];
    for (let character = 0; character < 2; character++) for (const charStyle of [1, 2]) for (const charSize of [0, 1, 2])
      list.push({ label: `${N[character]} ${charStyle === 1 ? 'pix' : 'dig'} size${charSize}`, st: { style, character, charStyle, charSize } });
    sheet('sheet-style' + style + '-characters', list);
    const list2 = [];
    for (let background = 0; background < 6; background++) for (const is24 of [true, false])
      list2.push({ label: `bg${background} ${is24 ? '24h' : '12h'} ${background % 2 ? 'en' : 'ko'}`,
        st: { style, background, is24, hour: 21, dateLang: background % 2 ? 1 : 2, character: background % 2, showDate: background !== 4 } });
    sheet('sheet-style' + style + '-backgrounds', list2);
  }
  // 날씨 / 달의 위상 / 새 정보 칸
  const wxList = [];
  for (const style of [0, 1]) for (const wx of [-1, 1, 2, 3]) {
    wxList.push({ label: `s${style} wx${wx} day`, st: { style, wx, hour: 13, animate: true, sec: 7, slots: [9, 10, 1, 9], character: 1 } });
    wxList.push({ label: `s${style} wx${wx} night`, st: { style, wx, hour: 21, animate: true, sec: 7, slots: [9, 10, 1, 9], character: 0 } });
  }
  sheet('sheet-weather', wxList);
  const moonList = [];
  for (let k = 0; k < 8; k++) moonList.push({ label: `moon ${k}/8`, st: { hour: 21, nowSec: 947182440 + Math.round(k * 29.530588853 / 8 * 86400), steps: 100 } });
  moonList.push({ label: 'happy (goal met)', st: { hour: 13, steps: 12000, character: 0 } });
  moonList.push({ label: 'happy digital', st: { hour: 13, steps: 12000, character: 3, charStyle: 2 } });
  sheet('sheet-moon-happy', moonList);
  // 풍경 7종 × 시간대 (픽셀) + 디지털
  const scnList = [];
  const SN = ['meadow', 'sea', 'city', 'snow', 'cherry', 'autumn', 'space'];
  for (let scenery = 0; scenery < 7; scenery++) {
    for (const [hour, tn] of [[7, 'morn'], [13, 'day'], [18, 'eve'], [21, 'night']])
      scnList.push({ label: `${SN[scenery]} ${tn}`, st: { scenery, hour, character: scenery % 2, animate: true, sec: 5 } });
    scnList.push({ label: `${SN[scenery]} digital`, st: { scenery, hour: 13, style: 1, character: scenery % 2 } });
    scnList.push({ label: `${SN[scenery]} dig night`, st: { scenery, hour: 21, style: 1, character: scenery % 2 } });
  }
  sheet('sheet-scenery', scnList);
  return { aod, sheets, calls };
});

let fail = 0;
console.log('AOD (12분 동안 최댓값)');
console.log('style char  charStyle  켜진픽셀  밝기가중  2분연속');
for (const r of result.aod) {
  const bad = r.maxRatio > 0.10 || r.overlap > 0;
  if (bad) fail++;
  console.log(`${r.style}     ${r.character}     ${r.charStyle === 1 ? 'pixel  ' : 'digital'}    ${(r.maxRatio * 100).toFixed(1).padStart(5)}%   ${(r.maxLum * 100).toFixed(1).padStart(5)}%   ${String(r.overlap).padStart(5)}${bad ? '  <-- 문제' : ''}`);
}
console.log('\n그리기 호출 수 (화면 1회, 캐릭터 중 최댓값)');
for (const c of result.calls) {
  console.log(`style ${c.style} ${c.charStyle === 1 ? 'pixel  ' : 'digital'} bg${c.background}: ${c.max}`);
}
for (const [name, uri] of Object.entries(result.sheets)) {
  fs.writeFileSync(path.join(out, name + '.png'), Buffer.from(uri.split(',')[1], 'base64'));
}
console.log(`\n모아보기 이미지: ${out}`);
await browser.close();
process.exit(fail ? 1 : 0);
