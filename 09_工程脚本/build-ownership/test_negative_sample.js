// 构建归属门禁负向样本测试（WO-20260919-AUDIT-乙 B3 验收：注入孤儿单元/新轨进包/生产uses新轨 ⇒ 门禁报错）
// 用法: node test_negative_sample.js   （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'owngate-'));
fs.mkdirSync(path.join(tmp, 'Core'), { recursive: true });
const NL = String.fromCharCode(10);
// 正常单元：被 dpk contains 引用 ⇒ 非孤儿
fs.writeFileSync(path.join(tmp, 'Core', 'Bar.pas'), 'unit Bar;' + NL + 'interface' + NL + 'implementation' + NL + 'end.' + NL);
// 孤儿单元：任何构建文件零引用 ⇒ O1 应报（空基线下）
fs.writeFileSync(path.join(tmp, 'Core', 'FooOrphan.pas'), 'unit FooOrphan;' + NL + 'interface' + NL + 'implementation' + NL + 'end.' + NL);
// 生产单元 uses 新轨 ⇒ O4 应报
fs.writeFileSync(path.join(tmp, 'Core', 'Evil.pas'), 'unit Evil;' + NL + 'interface' + NL + 'uses' + NL + '  DeepBase.Plugins.Manager;' + NL + 'implementation' + NL + 'end.' + NL);
// 生产包把新轨装进 contains ⇒ O2 应报
fs.writeFileSync(path.join(tmp, 'prod.dpk'), 'package prod;' + NL + 'contains' + NL + '  Bar,' + NL + '  DeepBase.Plugins.Manager;');

const emptyBaseline = path.join(tmp, 'baseline.json');
fs.writeFileSync(emptyBaseline, JSON.stringify({ orphans: {} }));
let failed = false;
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_build_ownership.js'), '--root', tmp, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.error('负向样本测试失败：门禁未拦截任何违规'); failed = true;
} catch (e) {
  const out = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8');
  console.log('门禁输出（预期包含 O1/O2/O4 违规；O3 因 tmp 无新轨 Manager.pas 文件不适用）:' + NL + out);
  for (const tag of ['O1', 'O2', 'O4']) {
    if (!out.includes(tag)) { console.error('缺少 ' + tag + ' 报错'); failed = true; }
  }
  if (out.includes('Bar') && out.includes('O1')) { /* Bar 不得被判孤儿 */ }
  if (/O1.*Bar\.pas/.test(out)) { console.error('O1 误报已入构建单元 Bar'); failed = true; }
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'OWNERSHIP-NEGATIVE-TEST: FAIL' : 'OWNERSHIP-NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
