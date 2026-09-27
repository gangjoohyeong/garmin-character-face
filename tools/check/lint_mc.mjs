// Monkey C 문법 검사 (SDK 없이). 사용법: node lint_mc.mjs <source 폴더>
// Prettier용 Monkey C 파서로 모든 .mc 파일을 파싱해서 문법 오류를 찾는다.
// 없는 API 호출이나 타입 오류는 잡지 못한다 (실제 컴파일은 monkeyc).
import * as prettier from 'prettier';
import fs from 'fs';
import path from 'path';

const plugin = (await import('@markw65/prettier-plugin-monkeyc')).default;
const dir = process.argv[2] || '../../source';
let bad = 0;
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.mc')).sort()) {
  try {
    await prettier.format(fs.readFileSync(path.join(dir, f), 'utf8'), { parser: 'monkeyc', plugins: [plugin], filepath: f });
    console.log('ok    ' + f);
  } catch (e) {
    bad++;
    const loc = e.loc && e.loc.start ? `:${e.loc.start.line}:${e.loc.start.column}` : '';
    console.log('ERROR ' + f + loc + '\n      ' + String(e.message).split('\n')[0]);
  }
}
console.log(bad ? `\n${bad}개 파일에 문법 오류` : '\n문법 오류 없음');
process.exit(bad ? 1 : 0);
