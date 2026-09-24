// DeepBase 编译噪声门禁负向样例（WO-20260924-AUDIT-甲-D9 段4 / 外单 DB-006）
//
// 覆盖 check_build.js 的噪声判定核心：从 dcc64 原始输出解析按码计数（parseNoise）、拆分 H/W（sumCodes）、
// 与基线比对「只拦增长与新增码、不拦存量下降」（compareAgainstBaseline），以及基线不可信时 fail-closed 到 EXIT=2。
//
// 为什么用纯函数 + 子进程混合，而不是跑一次真实 --all 全量编译：
// 真实全量编译 3~4 分钟且依赖 dcc64，作为负向样例会让「验证器本身」既慢又脆；
// 判定逻辑（哪些码算增长、缺码算不算新增、下降放行）是纯字符串/数值运算，直接喂构造样本即可穷举边界，
// 真实全量绿由 --emit-baseline + --all 比对在交付时单独跑一次留证（见 noise-baseline.json 的 generatedFrom）。
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { parseNoise, sumCodes, compareAgainstBaseline } = require('./check_build.js');

let pass = 0, fail = 0;
function ok(name) { pass++; console.log('  PASS ' + name); }
function bad(name, detail) { fail++; console.log('  FAIL ' + name + (detail ? ' :: ' + detail : '')); }
function expect(cond, name, detail) { cond ? ok(name) : bad(name, detail); }

// 构造贴近 dcc64 真实形态的输出：形如 `<file>(<line>) Hint: H2443 ...`（严重级前是右括号+空格，非冒号）。
// 曾用带冒号的 `: Hint:` 造样本，恰好迎合写错的解析正则 → 测试给 bug 背书；这里必须锁真实格式。
const SAMPLE = [
  'Embarcadero Delphi for Win64 compiler',
  'Core\\DeepBase.LLM.pas(120) Hint: H2443 Inline function "Foo" has not been expanded',
  'Core\\DeepBase.LLM.pas(201) Hint: H2443 Inline function "Bar" has not been expanded',
  'Core\\DeepBase.ORM.pas(88) Hint: H2077 Value assigned to "x" never used',
  'VCL\\DeepBase.VCL.pas(10) Warning: W1035 Return value of function "Y" assumed to be undefined',
  'Persistence\\DeepBase.DB.pas(5) Fatal: F2063 Could not compile needed unit',
  'Some random line without a code marker: not a hint',
  'Core\\DeepBase.Net.pas(3) Hint: W1000 Symbol "legacy" is deprecated',
].join('\r\n');

console.log('# 1. parseNoise：按码计数，非噪声行不计入');
const codes = parseNoise(SAMPLE);
expect(codes.H2443 === 2, 'H2443 计 2', 'got ' + codes.H2443);
expect(codes.H2077 === 1, 'H2077 计 1', 'got ' + codes.H2077);
expect(codes.W1035 === 1, 'W1035 计 1', 'got ' + codes.W1035);
expect(codes.W1000 === 1, 'W1000（Hint 前缀但 W 码）按码名计入', 'got ' + codes.W1000);
expect(!('F2063' in codes), 'Fatal 码不入噪声集', 'got F2063=' + codes.F2063);

console.log('# 2. sumCodes：按码名前缀拆 H/W');
const t = sumCodes(codes);
expect(t.hints === 3, 'H 码合计 3 (H2443x2+H2077x1)', 'got ' + t.hints);
expect(t.warnings === 2, 'W 码合计 2 (W1035x1+W1000x1)', 'got ' + t.warnings);

console.log('# 3. compareAgainstBaseline：只拦增长与新增码');
const base = { H2443: 2, H2077: 1, W1035: 1 };

let v = compareAgainstBaseline(base, new Map([['H2443', 3]]));
expect(v.length === 1 && /H2443/.test(v[0]), 'H2443 由 2 增长到 3 → 报红', JSON.stringify(v));

v = compareAgainstBaseline(base, new Map([['H2443', 2], ['H2077', 1], ['W1035', 1]]));
expect(v.length === 0, '全部与基线相等 → 放行', JSON.stringify(v));

v = compareAgainstBaseline(base, new Map([['H2443', 1]]));
expect(v.length === 0, 'H2443 下降到 1（存量减少=修复结果）→ 放行', JSON.stringify(v));

v = compareAgainstBaseline(base, new Map([['H2443', 0]]));
expect(v.length === 0, 'H2443 归零 → 放行', JSON.stringify(v));

v = compareAgainstBaseline(base, new Map([['H9999', 1]]));
expect(v.length === 1 && /新增噪声/.test(v[0]), '基线中不存在的新码出现 → 报红并标注新增', JSON.stringify(v));

v = compareAgainstBaseline({}, new Map([['W1035', 1]]));
expect(v.length === 1, '空基线（无记录）下任何噪声都算增长', JSON.stringify(v));

v = compareAgainstBaseline(base, new Map([['W1035', 2], ['H2077', 3]]));
expect(v.length === 2, '多码同时增长 → 逐码报', JSON.stringify(v));

console.log('# 4. 基线文件不可信时 fail-closed 到 EXIT=2；跨面时如实跳过（子进程验证，避免拖崩本测试进程）');
function runCompareWithBaseline(file, currentSurface) {
  const driver = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'd9noise-')), 'driver.js');
  fs.writeFileSync(driver,
    "const {compareNoise}=require(" + JSON.stringify(path.resolve(__dirname, 'check_build.js')) + ");" +
    "const r=compareNoise(process.argv[2], new Map([['H2443',1]]), process.argv[3]||undefined);" +
    "console.log('RESULT ' + JSON.stringify(r));",
    'utf8');
  const r = spawnSync(process.execPath, [driver, file, currentSurface || ''], { encoding: 'utf8' });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
// 4a. 噪声基线缺溯源字段（T3）
const noProv = path.join(os.tmpdir(), 'd9-noise-bad-' + Date.now() + '.json');
fs.writeFileSync(noProv, JSON.stringify({ noise: { H2443: 2 } }), 'utf8');
let rc = runCompareWithBaseline(noProv);
expect(rc.code === 2, '缺溯源 → EXIT=2', 'code=' + rc.code + ' ' + rc.out.trim().slice(0, 120));
// 4b. noise 键类型错（应为对象，实为数组）→ T4
const badType = path.join(os.tmpdir(), 'd9-noise-badtype-' + Date.now() + '.json');
fs.writeFileSync(badType, JSON.stringify({ generated: 'x', noise: [] }), 'utf8');
rc = runCompareWithBaseline(badType);
expect(rc.code === 2, 'noise 非对象 → EXIT=2', 'code=' + rc.code + ' ' + rc.out.trim().slice(0, 120));
// 4c. 可信基线 + 面一致 → 正常比对、不退出（H2443=1<5 不增长）
const good = path.join(os.tmpdir(), 'd9-noise-good-' + Date.now() + '.json');
fs.writeFileSync(good, JSON.stringify({ generated: 'g', surface: 'manifest:T0.txt', noise: { H2443: 5 } }), 'utf8');
rc = runCompareWithBaseline(good, 'manifest:T0.txt');
expect(rc.code === 0 && /"compared":true/.test(rc.out) && /"violations":\[\]/.test(rc.out),
  '面一致可信基线正常比对（1<5 不增长）', 'code=' + rc.code + ' ' + rc.out.trim());
// 4d. 面不一致 → compared=false 跳过、不比对也不退出（跨面计数不可比）
rc = runCompareWithBaseline(good, 'all');
expect(rc.code === 0 && /"compared":false/.test(rc.out), '面不一致 → 跳过比对（不红）', 'code=' + rc.code + ' ' + rc.out.trim());

console.log(`\n编译噪声负向样例：PASS=${pass} FAIL=${fail}`);
process.exit(fail === 0 ? 0 : 1);
