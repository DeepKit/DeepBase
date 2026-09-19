// 行尾门禁负向样本测试（WO-20260919-AUDIT-乙-R2 E9）
// 向临时副本注入：
// 1. .pas 纯 LF（L1 违规）
// 2. .md 包含 CRLF（L2 违规）
// 3. .pas 混用 CRLF 与 LF（L3 违规）
// 断言门禁逐项拦截并输出相应违规标识。
// 用法: node test_negative_sample.js （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'eolgate-'));
fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
fs.mkdirSync(path.join(tmp, 'docs'), { recursive: true });

// 正向样本：合法 CRLF .pas 与 LF .md
fs.writeFileSync(path.join(tmp, 'src', 'Ok.pas'), Buffer.from('unit Ok;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8'));
fs.writeFileSync(path.join(tmp, 'docs', 'Ok.md'), Buffer.from('# Doc\nContent in LF\n', 'utf8'));

// 负向样本 1：.pas 故意写入纯 LF（违规 L1）
fs.writeFileSync(path.join(tmp, 'src', 'Bad_LF.pas'), Buffer.from('unit Bad_LF;\ninterface\nimplementation\nend.\n', 'utf8'));

// 负向样本 2：.md 故意写入 CRLF（违规 L2）
fs.writeFileSync(path.join(tmp, 'docs', 'Bad_CRLF.md'), Buffer.from('# Doc\r\nContent in CRLF\r\n', 'utf8'));

// 负向样本 3：.pas 混用 CRLF 与 LF（违规 L3）
fs.writeFileSync(path.join(tmp, 'src', 'Bad_Mixed.pas'), Buffer.from('unit Bad_Mixed;\r\ninterface\nimplementation\r\nend.\n', 'utf8'));

const emptyBaseline = path.join(tmp, 'empty_baseline.json');
fs.writeFileSync(emptyBaseline, JSON.stringify({ pas_lf_exceptions: [], pas_mixed_exceptions: [], md_crlf_exceptions: [] }, null, 2), 'utf8');

let failed = false;
let stdoutErr = '';
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_eol.js'), '--root', tmp, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.error('负向样本测试失败：门禁未拦截任何违规！');
  failed = true;
} catch (e) {
  stdoutErr = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8');
  console.log('门禁输出（预期包含 L1, L2, L3 违规）:\n' + stdoutErr);
  for (const tag of ['L1', 'L2', 'L3']) {
    if (!stdoutErr.includes(tag)) {
      console.error('缺少 ' + tag + ' 报错');
      failed = true;
    }
  }
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
