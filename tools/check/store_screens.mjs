// 스토어용 스크린샷 (모찌만) → docs/store/screenshots/*.png   (Playwright 필요)
//   node store_screens.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(here, '../../docs/store/screenshots');
fs.mkdirSync(out, { recursive: true });

const SHOTS = [
  ['01-pixel-day', { style: 0, hour: 13, min: 24 }],
  ['02-pixel-morning', { style: 0, hour: 7, min: 5, sec: 8, animate: true }],
  ['03-pixel-evening', { style: 0, hour: 18, min: 42, charStyle: 2 }],
  ['04-pixel-night-sleep', { style: 0, hour: 23, min: 48, sec: 3, animate: true, wx: 3 }],
  ['05-digital', { style: 1, hour: 10, min: 9, accent: 4, dateLang: 1 }],
  ['06-digital-rain', { style: 1, hour: 16, min: 30, wx: 2, charStyle: 1, sec: 5, animate: true, slots: [9, 3, 1, 4] }],
  ['07-aod', { style: 0, aod: true, hour: 1, min: 12 }],
];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 400, height: 400 } });
await page.goto('file://' + path.resolve(here, '../../preview/index.html'));
await page.waitForTimeout(800);
const shots = await page.evaluate((SHOTS) => {
  const base = {
    style: 0, character: 0, charStyle: 1, charSize: 1, background: 0, accent: 0, timeColor: 0, ring: 0,
    slots: [1, 4, 2, 3], showDate: true, dateLang: 2, watchKorean: true, sleepAt: 2, wakeAt: 1,
    animate: false, aod: false, is24: true, hour: 13, min: 24, sec: 0, dow: 6, date: 27, month: 8, day: 0,
    hr: 64, bat: 78, bb: 71, steps: 6840, goal: 10000, cal: 1520, dist: 5.1, floors: 6, stress: 24,
    wx: 0, temp: 21, notif: 2, sunrise: 380, sunset: 1130, nowSec: 1790000000, weatherFx: true,
  };
  const cv = document.createElement('canvas'); cv.width = 360; cv.height = 360;
  const ctx = cv.getContext('2d');
  return SHOTS.map(([name, o]) => {
    ctx.save(); ctx.fillStyle = '#000'; ctx.fillRect(0, 0, 360, 360);
    ctx.beginPath(); ctx.arc(180, 180, 180, 0, Math.PI * 2); ctx.clip();
    WatchFace.render(ctx, { ...base, ...o }); ctx.restore();
    return [name, cv.toDataURL('image/png')];
  });
}, SHOTS);
for (const [name, uri] of shots) fs.writeFileSync(path.join(out, name + '.png'), Buffer.from(uri.split(',')[1], 'base64'));
console.log(`${shots.length}장 → ${out}`);
await browser.close();
