// DeepBase 行尾一致性门禁（WO-20260919-AUDIT-乙-R2 E9；L8 多重CR 扩展见 WO-20260920-AUDIT-乙-R4）
// 规则（四态分类：CRLF / LF / mixed / 多重CR，多重CR 独立成态，禁止混入 mixed）：
//  L1 CRLF 规则：*.pas 必须使用 CRLF 行尾（\r\n），禁止纯 LF。历史存量由 baseline 豁免，禁止新增违规。
//  L2 LF 规则：*.md 必须使用 LF 行尾（\n），禁止包含 CR（\r）。历史存量由 baseline 豁免，禁止新增违规。
//  L3 混用规则：*.pas 禁止在同一文件内混用单CR行尾（CRLF）与纯 LF；含多重CR的文件归 L4，不进 L3。
//  L4 多重CR规则：*.pas 禁止出现 \r\r\n 及以上的多重 CR 行尾（Delphi 按每个 CR 计行号，行号全部错位）。历史存量由 baseline 豁免，禁止新增违规。
// 用法: node check_eol.js [--root <dir>] [--baseline <file>] [--emit-baseline]
// 退出码：0 通过；1 违规；2 基线不可信（WO-20260923-AUDIT-乙-D5 §一-3，见 gate-baseline.js）；
//        3 扫描自身失败（root 不可读/扫到 0 个文件/参数解析失败）——fail-closed，绝不放行。
const fs = require('fs');
const path = require('path');
const { parseGateArgs } = require('../gate-args');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');

// 参数解析收敛到 09_工程脚本/gate-args.js 单一实现（WO-20260922-AUDIT-乙-P2 §七）。
// 本门禁此前零参数校验（--ROOT / --rot 被静默忽略，回落默认根后照常报 EXIT=0），
// 而 check_pas_encoding.js 另有一份内联校验——两份等价物各自维护，正是被禁止的形态。
{
  const opts = parseGateArgs(process.argv.slice(2), {
    label: '行尾',
    root: path.join(__dirname, '../..'),
    baseline: path.join(__dirname, 'eol_baseline.json'),
    extra: ['emit-baseline'],
  });
  if (opts.flags.has('help')) {
    console.log('用法: node check_eol.js [--root <dir>] [--baseline <file>] [--emit-baseline]');
    process.exit(0);
  }
  var ROOT = opts.root;
  var BASELINE_P = opts.baseline;
  var EMIT = opts.flags.has('emit-baseline');
}
const SKIP = gateSkipSet();
// 记录被 SKIP 规则吃掉的顶层目录，让「扫描面缩了什么」可见（WO-20260921-AUDIT-乙-P1 §〇 第 3 条）。
const skippedDirs = new Set();

function walk(dir, out) {
  let ents;
  // fail-closed：readdir 失败不得静默返回空数组，否则门禁扫到 0 个文件却报「通过」，
  // 把「没扫」伪装成「扫过且干净」（WO-20260921-AUDIT-乙-P1 §〇 主控实测缺陷）。
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) {
    console.error(`行尾门禁无法读取目录: ${dir} (${e.message})`);
    process.exit(3);
  }
  for (const e of ents) {
    if (SKIP.has(e.name)) { skippedDirs.add(e.name); continue; }
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
// 空扫描即失败：仓库内必有 .pas/.md；扫到 0 个说明 root 指错或 SKIP 规则吃掉了源码树。
if (files.length === 0) {
  console.error(`行尾门禁失败：扫描 0 个文件（root=${ROOT}）。根因通常是 --root 指错目录；已按 fail-closed 拒绝放行。`);
  process.exit(3);
}
// 基线只在检查路径被读取，故放在 EMIT 之后：`--emit-baseline` 是修复基线的动作，
// 不能因为基线已坏就把自己锁在门外（守写入侧是 B1，守读取侧是 gate-baseline.js）。
// 四态豁免集必须齐备——缺键即说明这份 JSON 不是本门禁的基线（被顶替/被清空），EXIT=2。

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

const baseline = loadGateBaseline({
  file: BASELINE_P, label: '行尾',
  keys: { pas_lf_exceptions: 'array', pas_mixed_exceptions: 'array', md_crlf_exceptions: 'array', pas_multicr_exceptions: 'array' },
});
const pasLfAllowed = new Set(baseline.pas_lf_exceptions);
const pasMixedAllowed = new Set(baseline.pas_mixed_exceptions);
const mdCrlfAllowed = new Set(baseline.md_crlf_exceptions);
const pasMultiCrAllowed = new Set(baseline.pas_multicr_exceptions);

const violations = [];
for (const f of files) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  let buf;
  try { buf = fs.readFileSync(f); } catch (e) {
    console.error(`行尾门禁无法读取文件: ${rel} (${e.message})`);
    process.exit(3);
  }
  const { crlf, lf, multicr } = countTerms(buf);
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
console.log('行尾门禁通过：检查了 ' + files.length + ' 个文件（.pas CRLF / .md LF），跳过目录 ' + skippedDirs.size);
