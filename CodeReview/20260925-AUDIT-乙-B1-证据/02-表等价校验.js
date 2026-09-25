// B1§2 GB18030 反表三处合一——新旧表逐字节等价校验（一次性，对照 git HEAD 的真实旧实现）
// 判据（总单 §B1-2）：新旧表对全仓 .pas 扫描结果一致。
// 用法: node 02-表等价校验.js   （从 git show HEAD:<file> 提取旧实现，与新共享模块比对）
'use strict';
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..', '..');
const HERE = __dirname;
let failed = false;
function ok(cond, label, detail) {
  if (cond) console.log('  PASS ' + label);
  else { failed = true; console.error('  FAIL ' + label + (detail ? ' :: ' + detail : '')); }
}
function headSrc(rel) { return execFileSync('git', ['-C', REPO, 'show', 'HEAD:' + rel], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }); }
// 括号配平提取 function <name>(...) { ... } 源码（对已知闭合格式的旧文件足够可靠，提取结果以 eval 成功 + 深比对为准）
function extractFn(src, name) {
  const start = src.indexOf('function ' + name + '(');
  if (start < 0) throw new Error('function not found: ' + name);
  let i = src.indexOf('{', start), depth = 0;
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++;
    else if (src[i] === '}') { depth--; if (depth === 0) break; }
  }
  return src.slice(start, i + 1);
}
function buildFromExtracted(src, fnName, varDecl) {
  return new Function(varDecl + '\n' + extractFn(src, fnName) + '\nreturn ' + fnName + '();')();
}
function tableDigest(m) {
  const keys = [...m.keys()].sort();
  const h = require('crypto').createHash('sha256');
  for (const k of keys) h.update(k).update(Buffer.from(m.get(k)));
  return { n: m.size, sha256: h.digest('hex'), hasFFFD: m.has('�') };
}
function sameTable(a, b) {
  if (a.size !== b.size) return 'size ' + a.size + ' vs ' + b.size;
  for (const [k, v] of a) { const w = b.get(k); if (!w || w[0] !== v[0] || w[1] !== v[1]) return 'key ' + JSON.stringify(k); }
  return null;
}
function diffKeys(a, b) {
  const onlyA = [...a.keys()].filter(k => !b.has(k));
  const onlyB = [...b.keys()].filter(k => !a.has(k));
  return { onlyOld: onlyA, onlyNew: onlyB };
}

console.log('== 1. 旧表（git HEAD 真实实现）vs 新共享模块 ==');
const oldCore = (() => {
  const tmp = path.join(require('os').tmpdir(), 'old_mojibake_core_head.js');
  fs.writeFileSync(tmp, headSrc('09_工程脚本/mojibake-core.js'));
  const m = require(tmp).gbkReverseTable();
  fs.unlinkSync(tmp);
  return m;
})();
const oldEvid = buildFromExtracted(headSrc('09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js'), 'gbkReverseTable', 'let GB_REV = null;');
const oldPas = buildFromExtracted(headSrc('09_工程脚本/encoding-gate/check_pas_encoding.js'), 'buildGbkReverseTable', 'let GBK_REV = null;');

const shared = require(path.join(REPO, '09_工程脚本', 'gb18030-reverse-table.js'));
const newDefault = shared.gbkReverseTable();          // gb18030（mojibake-core / evidence 口径）
const newGbk = shared.buildReverseTable('gbk');       // encoding-gate G6 历史口径

ok(oldCore && newDefault && !sameTable(oldCore, newDefault), 'mojibake-core 旧表 == 新表(gb18030)',
  oldCore && newDefault ? sameTable(oldCore, newDefault) : 'null table');
ok(oldEvid && !sameTable(oldEvid, newDefault), 'evidence-encoding 旧表 == 新表(gb18030)',
  oldEvid ? sameTable(oldEvid, newDefault) : 'null table');
ok(oldPas && !sameTable(oldPas, newGbk), 'encoding-gate 旧表(gbk) == 新表(gbk 参数)',
  oldPas ? sameTable(oldPas, newGbk) : 'null table');

console.log('== 2. gb18030 vs gbk 两口径差异（决定 encoding-gate 是否可换口径）==');
const dd = diffKeys(newDefault, newGbk);
console.log('  差异键: oldOnly=' + dd.onlyOld.length + ' newOnly=' + dd.onlyNew.length);
console.log('  digest gb18030: ' + JSON.stringify(tableDigest(newDefault)));
console.log('  digest gbk:     ' + JSON.stringify(tableDigest(newGbk)));

console.log('== 3. 全仓风险行扫描（含任一差异键的行；覆盖 .pas 全集 + 门禁另扫的证据面文件）==');
const files = execFileSync('git', ['-C', REPO, '-c', 'core.quotepath=false', 'ls-files', '-z'],
  { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 }).toString('utf8').split('\0').filter(Boolean);
const pasFiles = files.filter(f => f.toLowerCase().endsWith('.pas'));
const riskChars = new Set([...dd.onlyOld, ...dd.onlyNew]);
const riskLines = [];
const riskPas = [];
let lineCount = 0;
for (const f of files) {
  const abs = path.join(REPO, f);
  let text;
  try { if (fs.statSync(abs).size > 4 * 1024 * 1024) continue; text = fs.readFileSync(abs, 'utf8'); } catch (e) { continue; }
  const isPas = f.toLowerCase().endsWith('.pas');
  text.split('\n').forEach((line, idx) => {
    if (isPas) lineCount++;
    for (const ch of line) if (riskChars.has(ch)) {
      const rec = f + ':' + (idx + 1) + ' ' + line.trim().slice(0, 80);
      riskLines.push(rec); if (isPas) riskPas.push(rec);
      break;
    }
  });
}
console.log('  扫描 ' + files.length + ' 个跟踪文件（其中 .pas ' + pasFiles.length + ' 个 / ' + lineCount + ' 行）；风险行 ' + riskLines.length + ' 行（.pas 内 ' + riskPas.length + ' 行）');
riskLines.slice(0, 20).forEach(l => console.log('    ' + l));
const encSrc = fs.readFileSync(path.join(REPO, '09_工程脚本/encoding-gate/check_pas_encoding.js'), 'utf8');
const encKeepsGbk = /buildReverseTable\(\s*'gbk'\s*\)/.test(encSrc);
if (encKeepsGbk) {
  ok(true, 'encoding-gate 保持 gbk 历史口径 ⇒ 与旧实现逐键一致（§1 已证），风险行仅供换口径决策参考');
} else {
  ok(riskLines.length === 0, 'encoding-gate 已换 gb18030 默认口径 ⇒ 必须零风险行（否则行为变化）');
}

console.log('== 4. 数据件 == gb18030-reverse-table.json 与重建表一致（防漂移）==');
const data = JSON.parse(fs.readFileSync(path.join(REPO, '09_工程脚本', 'gb18030-reverse-table.json'), 'utf8'));
let mismatch = 0;
for (const [ch, pair] of newDefault) { const v = data[ch]; if (!v || v[0] !== Buffer.from(pair).toString('hex')) mismatch++; }
for (let b = 0; b < 0x80; b++) { const v = data[String.fromCharCode(b)]; if (!v || v[0] !== b.toString(16).padStart(2, '0')) mismatch++; }
const extra = Object.keys(data).length - (newDefault.size + 0x80);
ok(mismatch === 0 && extra === 0, 'JSON 数据件与算法重建表逐键一致', `mismatch=${mismatch} extra=${extra}`);

console.log(failed ? 'EQUIV: FAIL' : 'EQUIV: PASS');
process.exit(failed ? 1 : 0);
