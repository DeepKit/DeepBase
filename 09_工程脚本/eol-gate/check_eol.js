// DeepBase 行尾一致性门禁（WO-20260919-AUDIT-乙-R2 E9）
// 规则：
//  L1 CRLF 规则：*.pas 必须使用 CRLF 行尾（\r\n），禁止纯 LF。历史存量由 baseline 豁免，禁止新增违规。
//  L2 LF 规则：*.md 必须使用 LF 行尾（\n），禁止包含 CR（\r）。历史存量由 baseline 豁免，禁止新增违规。
//  L3 混用规则：任何文本文件禁止在同一文件内混用 CRLF 与 LF。历史存量由 baseline 豁免，禁止新增违规。
// 用法: node check_eol.js [--root <dir>] [--baseline <file>] [--emit-baseline]
// 退出码：0 通过；1 违规。
const fs = require('fs');
const path = require('path');

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}
const ROOT = path.resolve(arg('root', path.join(__dirname, '../..')));
const BASELINE_P = arg('baseline', path.join(__dirname, 'eol_baseline.json'));
const EMIT = process.argv.includes('--emit-baseline');
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy', 'TestResults']);

function walk(dir, out) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.isFile()) {
      const ext = path.extname(e.name).toLowerCase();
      if (ext === '.pas' || ext === '.md') out.push(p);
    }
  }
  return out;
}

const files = walk(ROOT, []);
let baseline = { pas_lf_exceptions: [], pas_mixed_exceptions: [], md_crlf_exceptions: [] };
if (fs.existsSync(BASELINE_P)) {
  try { baseline = JSON.parse(fs.readFileSync(BASELINE_P, 'utf8')); } catch (e) {}
}

const pasLfAllowed = new Set(baseline.pas_lf_exceptions || []);
const pasMixedAllowed = new Set(baseline.pas_mixed_exceptions || []);
const mdCrlfAllowed = new Set(baseline.md_crlf_exceptions || []);

if (EMIT) {
  const newBaseline = {
    _comment: 'DeepBase 历史行尾存量基线 (WO-20260919-AUDIT-乙-R2 E9)，禁止新增或扩增',
    pas_lf_exceptions: [],
    pas_mixed_exceptions: [],
    md_crlf_exceptions: []
  };
  for (const f of files) {
    const rel = path.relative(ROOT, f).replace(/\\/g, '/');
    const buf = fs.readFileSync(f);
    let crlf = 0;
    let lf = 0;
    for (let i = 0; i < buf.length; i++) {
      if (buf[i] === 0x0A) {
        lf++;
        if (i > 0 && buf[i - 1] === 0x0D) crlf++;
      }
    }
    const ext = path.extname(f).toLowerCase();
    if (ext === '.pas') {
      if (lf > 0 && crlf === 0) newBaseline.pas_lf_exceptions.push(rel);
      else if (lf > 0 && crlf > 0 && crlf !== lf) newBaseline.pas_mixed_exceptions.push(rel);
    } else if (ext === '.md') {
      if (crlf > 0) newBaseline.md_crlf_exceptions.push(rel);
    }
  }
  newBaseline.pas_lf_exceptions.sort();
  newBaseline.pas_mixed_exceptions.sort();
  newBaseline.md_crlf_exceptions.sort();
  fs.writeFileSync(BASELINE_P, JSON.stringify(newBaseline, null, 2) + '\n', 'utf8');
  console.log('行尾基线生成完成：' + newBaseline.pas_lf_exceptions.length + ' pas LF, ' + newBaseline.pas_mixed_exceptions.length + ' pas mixed, ' + newBaseline.md_crlf_exceptions.length + ' md CRLF -> ' + BASELINE_P);
  process.exit(0);
}

const violations = [];
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  const buf = fs.readFileSync(f);
  let crlf = 0;
  let lf = 0;
  for (let i = 0; i < buf.length; i++) {
    if (buf[i] === 0x0A) {
      lf++;
      if (i > 0 && buf[i - 1] === 0x0D) crlf++;
    }
  }
  const ext = path.extname(f).toLowerCase();
  if (ext === '.pas') {
    if (lf > 0 && crlf === 0 && !pasLfAllowed.has(rel)) {
      violations.push('L1 .pas 源码非预期纯 LF (要求 CRLF): ' + rel);
    } else if (lf > 0 && crlf > 0 && crlf !== lf && !pasMixedAllowed.has(rel)) {
      violations.push('L3 .pas 源码混用 CRLF 与 LF (crlf=' + crlf + ', total_lf=' + lf + '): ' + rel);
    }
  } else if (ext === '.md') {
    if (crlf > 0 && !mdCrlfAllowed.has(rel)) {
      violations.push('L2 .md 文档非预期包含 CRLF (要求 LF): ' + rel);
    }
  }
}

if (violations.length) {
  console.error('行尾门禁失败，违规 ' + violations.length + ' 项:');
  violations.slice(0, 50).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log('行尾门禁通过：检查了 ' + files.length + ' 个文件（.pas CRLF / .md LF）');
