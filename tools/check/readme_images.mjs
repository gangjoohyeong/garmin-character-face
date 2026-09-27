// README 예시 이미지 → docs/images/*.png   (Playwright 필요, 먼저 python tools/fetch_assets.py)
//   node readme_images.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(here, '../../docs/images');
fs.mkdirSync(out, { recursive: true });

const SHOTS = [
  ['pixel-mochi-meadow', { style: 0, hour: 13, min: 24 }],
  ['pixel-dorongi-sea', { style: 0, hour: 18, min: 20, character: 1, scenery: 1 }],
  ['pixel-mochi-cherry', { style: 0, hour: 8, min: 5, scenery: 4, animate: true, sec: 8 }],
  ['pixel-dorongi-snow-sleep', { style: 0, hour: 23, min: 48, character: 1, scenery: 3, animate: true, sec: 3, wx: 3 }],
  ['pixel-mochi-city-night', { style: 0, hour: 21, min: 15, scenery: 2, steps: 11200 }],
  ['pixel-dorongi-space', { style: 0, hour: 22, min: 5, character: 1, scenery: 6, animate: true, sec: 2, dateLang: 1 }],
  ['digital-dorongi-image', { style: 1, hour: 10, min: 9, character: 1, charStyle: 0, accent: 4, dateLang: 1 }],
  ['digital-mochi-autumn', { style: 1, hour: 16, min: 30, scenery: 5, wx: 2, charStyle: 1, sec: 5, animate: true, slots: [9, 3, 1, 4] }],
  ['aod', { style: 0, aod: true, hour: 1, min: 12, character: 1 }],
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
    scenery: 0, wx: 0, temp: 21, notif: 2, sunrise: 380, sunset: 1130, nowSec: 1790000000, weatherFx: true,
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
