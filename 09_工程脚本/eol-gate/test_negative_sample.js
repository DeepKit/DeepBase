// 行尾门禁负向样本测试（WO-20260919-AUDIT-乙-R2 E9；L8 四态扩展见 WO-20260920-AUDIT-乙-R4）
// 向临时副本注入：
// 1. .pas 纯 LF（L1 违规）
// 2. .md 包含 CRLF（L2 违规）
// 3. .pas 混用 CRLF 与 LF（L3 违规）
// 4. .pas 多重CR行尾 \r\r\n（L4 违规）——且必须归 L4，不得混入 L3 分类
// 5. .pas 多重CR + CRLF/LF 混用并存（四态归属：只报 L4，不报 L3/L1）
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

// 负向样本 4：.pas 多重CR行尾 \r\r\n（违规 L4，WO-20260920-AUDIT-乙-R4 L8）
fs.writeFileSync(path.join(tmp, 'src', 'Bad_MultiCR.pas'), Buffer.from('unit Bad_MultiCR;\r\r\ninterface\r\r\nimplementation\r\r\nend.\r\r\n', 'utf8'));

// 负向样本 5：.pas 多重CR 与 CRLF/LF 混用并存——四态纪律：只归 L4，不得同时报 L3
fs.writeFileSync(path.join(tmp, 'src', 'Bad_MultiCR_Mixed.pas'), Buffer.from('unit Bad_MultiCR_Mixed;\r\r\r\r\ninterface\nimplementation\r\nend.\r\n', 'utf8'));

const emptyBaseline = path.join(tmp, 'empty_baseline.json');
fs.writeFileSync(emptyBaseline, JSON.stringify({ pas_lf_exceptions: [], pas_mixed_exceptions: [], md_crlf_exceptions: [], pas_multicr_exceptions: [] }, null, 2), 'utf8');

let failed = false;
let stdoutErr = '';
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_eol.js'), '--root', tmp, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.error('负向样本测试失败：门禁未拦截任何违规！');
  failed = true;
} catch (e) {
  stdoutErr = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8');
  console.log('门禁输出（预期包含 L1, L2, L3, L4 违规）:\n' + stdoutErr);
  for (const tag of ['L1', 'L2', 'L3', 'L4']) {
    if (!stdoutErr.includes(tag)) {
      console.error('缺少 ' + tag + ' 报错');
      failed = true;
    }
  }
  // 四态不混淆断言：多重CR文件必须且只能出现在 L4 行，不得落入 L3/L1 分类
  for (const line of stdoutErr.split('\n')) {
    if (/L[13]/.test(line) && /Bad_MultiCR/.test(line)) {
      console.error('四态混淆：多重CR文件被混入 L1/L3 分类 -> ' + line.trim());
      failed = true;
    }
  }
  for (const name of ['Bad_MultiCR.pas', 'Bad_MultiCR_Mixed.pas']) {
    if (!new RegExp('L4[^\\n]*' + name.replace('.', '\\.')).test(stdoutErr)) {
      console.error('缺少对 ' + name + ' 的 L4 报错');
      failed = true;
    }
  }
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
