// DeepBase 行尾一致性门禁（WO-20260919-AUDIT-乙-R2 E9；L8 多重CR 扩展见 WO-20260920-AUDIT-乙-R4）
// 规则（四态分类：CRLF / LF / mixed / 多重CR，多重CR 独立成态，禁止混入 mixed）：
//  L1 CRLF 规则：*.pas 必须使用 CRLF 行尾（\r\n），禁止纯 LF。历史存量由 baseline 豁免，禁止新增违规。
//  L2 LF 规则：*.md 必须使用 LF 行尾（\n），禁止包含 CR（\r）。历史存量由 baseline 豁免，禁止新增违规。
//  L3 混用规则：*.pas 禁止在同一文件内混用单CR行尾（CRLF）与纯 LF；含多重CR的文件归 L4，不进 L3。
//  L4 多重CR规则：*.pas 禁止出现 \r\r\n 及以上的多重 CR 行尾（Delphi 按每个 CR 计行号，行号全部错位）。历史存量由 baseline 豁免，禁止新增违规。
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
const pasMultiCrAllowed = new Set(baseline.pas_multicr_exceptions || []);

// 四态行尾计数：以每个 LF 前置连续 CR 个数 k 分类——k=0 纯LF，k=1 CRLF，k>=2 多重CR
function countTerms(buf) {
  let crlf = 0, lf = 0, multicr = 0;
  for (let i = 0; i < buf.length; i++) {
    if (buf[i] !== 0x0A) continue;
    let k = 0, j = i - 1;
    while (j >= 0 && buf[j] === 0x0D) { k++; j--; }
    if (k === 0) lf++;
    else if (k === 1) crlf++;
    else multicr++;
  }
  return { crlf, lf, multicr };
}

if (EMIT) {
  const newBaseline = {
    _comment: 'DeepBase 历史行尾存量基线 (WO-20260919-AUDIT-乙-R2 E9)，禁止新增或扩增',
    pas_lf_exceptions: [],
    pas_mixed_exceptions: [],
    md_crlf_exceptions: [],
    pas_multicr_exceptions: []
  };
  for (const f of files) {
    const rel = path.relative(ROOT, f).replace(/\\/g, '/');
    const { crlf, lf, multicr } = countTerms(fs.readFileSync(f));
    const ext = path.extname(f).toLowerCase();
    if (ext === '.pas') {
      if (multicr > 0) newBaseline.pas_multicr_exceptions.push(rel);
      else if (lf > 0 && crlf === 0) newBaseline.pas_lf_exceptions.push(rel);
      else if (lf > 0 && crlf > 0) newBaseline.pas_mixed_exceptions.push(rel);
    } else if (ext === '.md') {
      if (crlf > 0 || multicr > 0) newBaseline.md_crlf_exceptions.push(rel);
    }
  }
  newBaseline.pas_lf_exceptions.sort();
  newBaseline.pas_mixed_exceptions.sort();
  newBaseline.md_crlf_exceptions.sort();
  newBaseline.pas_multicr_exceptions.sort();
  fs.writeFileSync(BASELINE_P, JSON.stringify(newBaseline, null, 2) + '\n', 'utf8');
  console.log('行尾基线生成完成：' + newBaseline.pas_lf_exceptions.length + ' pas LF, ' + newBaseline.pas_mixed_exceptions.length + ' pas mixed, ' + newBaseline.md_crlf_exceptions.length + ' md CRLF, ' + newBaseline.pas_multicr_exceptions.length + ' pas multicr -> ' + BASELINE_P);
  process.exit(0);
}

const violations = [];
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  const { crlf, lf, multicr } = countTerms(fs.readFileSync(f));
  const ext = path.extname(f).toLowerCase();
  if (ext === '.pas') {
    if (multicr > 0) {
      if (!pasMultiCrAllowed.has(rel)) {
        violations.push('L4 .pas 源码多重CR行尾 \\r{2,}\\n (multicr=' + multicr + ', crlf=' + crlf + ', lf=' + lf + '): ' + rel);
      }
    } else if (lf > 0 && crlf === 0 && !pasLfAllowed.has(rel)) {
      violations.push('L1 .pas 源码非预期纯 LF (要求 CRLF): ' + rel);
    } else if (lf > 0 && crlf > 0 && !pasMixedAllowed.has(rel)) {
      violations.push('L3 .pas 源码混用 CRLF 与 LF (crlf=' + crlf + ', lf=' + lf + '): ' + rel);
    }
  } else if (ext === '.md') {
    if ((crlf > 0 || multicr > 0) && !mdCrlfAllowed.has(rel)) {
      violations.push('L2 .md 文档非预期包含 CR (要求 LF): ' + rel);
    }
  }
}

if (violations.length) {
  console.error('行尾门禁失败，违规 ' + violations.length + ' 项:');
  violations.slice(0, 50).forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log('行尾门禁通过：检查了 ' + files.length + ' 个文件（.pas CRLF / .md LF）');
