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

// WO-20260922-AUDIT-乙-P2 §七 参数 fail-open 5 类负样本（每类必须 EXIT=3）。
// 旧裂根因：校验侧把 --ROOT 小写归一后放行、取值侧大小写敏感取空 ⇒ 静默回落默认 root，
// 扫全仓 1452 个文件报 EXIT=0，把「我按指定 root 扫过了」变成假象。取值侧现已与校验侧
// 共用 09_工程脚本/gate-args.js 同一份归一结果，该裂缝在实现层不存在。
const ARG_CASES = [
  ['未知参数',        ['--rot', '.']],
  ['已知参数缺值',    ['--root']],
  ['裸位置参数',      ['stray']],
  ['大小写不符',      ['--ROOT', '/nonexistent']],
  ['值形似参数',      ['--root', '--root']],
];

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
// WO-20260921-AUDIT-乙-P1 §〇 第 4 条：负向样本①——--root 指向不存在的目录必须红（fail-closed）。
{
  const missingRoot = path.join(os.tmpdir(), 'eolgate-missing-' + Date.now());
  while (fs.existsSync(missingRoot)) fs.rmSync(missingRoot, { recursive: true, force: true });
  let red = false;
  try {
    execFileSync(process.execPath, [path.join(HERE, 'check_eol.js'), '--root', missingRoot], { stdio: 'pipe' });
  } catch (e) { red = true; }
  if (!red) { console.error('负向样本①失败：--root 指向不存在目录时门禁仍放行（fail-open 未修复）'); failed = true; }
  else console.log('负向样本①通过：不存在目录被 fail-closed 拦截');
}
// WO-20260921-AUDIT-乙-P1 §〇 第 4 条：负向样本②——空目录（存在但无 .pas/.md）必须红（空扫描不是通过）。
{
  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'eolgate-empty-'));
  let red = false;
  try {
    execFileSync(process.execPath, [path.join(HERE, 'check_eol.js'), '--root', emptyRoot], { stdio: 'pipe' });
  } catch (e) { red = true; }
  fs.rmSync(emptyRoot, { recursive: true, force: true });
  if (!red) { console.error('负向样本②失败：空目录（0 个文件）门禁仍报通过（真空绿未修复）'); failed = true; }
  else console.log('负向样本②通过：空扫描被 fail-closed 拦截');
}

// WO-20260922-AUDIT-乙-P2 §七：5 类参数 fail-open 负样本（WO-20260921-P1 §〇的 ①② 已在上方）
for (const [label, argv] of ARG_CASES) {
  let code = null;
  try {
    execFileSync(process.execPath, [path.join(HERE, 'check_eol.js'), ...argv], { stdio: 'pipe' });
  } catch (e) { code = e.status; }
  if (code !== 3) {
    console.error('参数负样本失败(' + label + ')：期望 EXIT=3，实际 ' + code);
    failed = true;
  } else {
    console.log('参数负样本通过(' + label + ')：[' + argv.join(' ') + '] => EXIT=3');
  }
}
// 决定性判据 §7.3#2：--root 指向存在目录时必须真的按该目录扫描，不得回落默认根。
// 用「扫描计数 ≠ 全仓量级」反证。tmp 内注入的是违规样本，门禁会走违规分支而非打印计数，
// 故改用一份干净的只读子目录来取计数；全仓量级上千，干净子目录仅 2 个，量级差一个数量级。
{
  const clean = fs.mkdtempSync(path.join(os.tmpdir(), 'eolgate-clean-'));
  fs.mkdirSync(path.join(clean, 'src'), { recursive: true });
  fs.writeFileSync(path.join(clean, 'src', 'Ok.pas'), Buffer.from('unit Ok;\r\nimplementation\r\nend.\r\n', 'utf8'));
  let out = '';
  try {
    out = execFileSync(process.execPath, [path.join(HERE, 'check_eol.js'), '--root', clean], { stdio: 'pipe' }).toString('utf8');
  } catch (e) { out = (e.stdout || Buffer.alloc(0)).toString('utf8'); }
  fs.rmSync(clean, { recursive: true, force: true });
  const m = out.match(/检查了\s+(\d+)\s+个文件/);
  const scanned = m ? Number(m[1]) : -1;
  if (scanned <= 0 || scanned > 100) {
    console.error('决定性判据2失败：--root <存在目录> 扫描计数异常（' + scanned + '），疑似回落默认根');
    failed = true;
  } else {
    console.log('决定性判据2通过：--root <存在目录> 真按该目录扫描（' + scanned + ' 个文件，非全仓量级）');
  }
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
