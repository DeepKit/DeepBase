// 乙-B2 单元覆盖对账表生成器：565 生产单元 × 11 份 20260918 分包 → 归属/条目/状态；未覆盖单元列入补审
// 用法: node b2_gen_reconcile.js   （输出 md + .tmp/b2-uncovered.json）
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const PROD_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow'];
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy']);
const PKGS = fs.readdirSync(path.join(ROOT, 'CodeReview')).filter(n => /^20260918-.+\.md$/.test(n) && !/总报告|复核|每日/.test(n));
// 单元所在目录 → 主责分包候选（口径：先主责分包，再全分包兜底）
const DIR2PKG = {
  Core: n => /^20260918-Core-/.test(n),
  Features: n => /^20260918-Features-/.test(n),
  Persistence: n => /^20260918-Persistence/.test(n),
  VCL: n => /^20260918-VCL/.test(n),
  FMX: n => /^20260918-FMX/.test(n),
  DeepFlow: n => /^20260918-FMX/.test(n),
  Governance: n => /^20260918-Governance/.test(n),
  Tools: n => /^20260918-Governance/.test(n),
};

function walk(dir, out) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.isFile() && /\.pas$/i.test(e.name)) out.push(p);
  }
  return out;
}
const pkgText = {}; const pkgLines = {};
for (const p of PKGS) {
  const t = fs.readFileSync(path.join(ROOT, 'CodeReview', p), 'utf8').toLowerCase();
  pkgText[p] = t;
  pkgLines[p] = fs.readFileSync(path.join(ROOT, 'CodeReview', p), 'utf8').split(/\r?\n/);
}
const ID_RE = /[A-Z]{1,5}-(?:[A-Z]{2,6}-)?\d{2,4}\b/g;

const units = [];
for (const d of PROD_DIRS) for (const f of walk(path.join(ROOT, d), [])) {
  const rel = path.relative(ROOT, f).replace(/\\/g, '/');
  const m = /^unit\s+([A-Za-z_][\w.]*)/im.exec(fs.readFileSync(f, 'utf8'));
  units.push({ dir: d, path: rel, unit: m ? m[1] : path.basename(rel, '.pas') });
}
units.sort((a, b) => a.path.localeCompare(b.path));

const rows = []; const uncovered = [];
for (const u of units) {
  let stem = u.unit.toLowerCase();
  const short = stem.replace(/^deepbase\./, '');
  // 候选行：主责分包优先，其他分包兜底
  const primary = PKGS.filter(P => DIR2PKG[u.dir](P));
  const others = PKGS.filter(P => !DIR2PKG[u.dir](P));
  let hitPkg = null, ids = [], inTable = false;
  const scan = (pkgs) => {
    for (const P of pkgs) {
      const t = pkgText[P];
      if (t.includes(stem) || t.includes(short)) {
        if (!hitPkg) hitPkg = P;
        for (const line of pkgLines[P]) {
          const ll = line.toLowerCase();
          if (ll.includes(stem) || ll.includes(short)) {
            const mm = line.match(ID_RE);
            if (mm) for (const id of mm) if (!ids.includes(id)) ids.push(id);
            if (/^\|\s*\d+\s*\|/.test(line) && /\.pas/i.test(line)) inTable = true;
          }
        }
      }
    }
  };
  scan(primary); scan(others);
  let status;
  if (!hitPkg) { status = '未审 → 本单补审'; uncovered.push(u); }
  else if (ids.length || inTable) status = '已审（分包有条目/清单行）';
  else status = '已审·宽松匹配（分包正文出现名，无独立条目）→ 本单补审注记';
  rows.push({ ...u, hitPkg: hitPkg || '-', ids: ids.slice(0, 5).join(', ') || (inTable ? '（单元清单行）' : '-'), status });
}
fs.writeFileSync(path.join(ROOT, '.tmp/b2-uncovered.json'), JSON.stringify(uncovered, null, 1));

const counts = {};
for (const r of rows) counts[r.status] = (counts[r.status] || 0) + 1;
const byDir = {};
for (const r of rows) { byDir[r.dir] = (byDir[r.dir] || 0) + 1; }

const md = `# 20260919 全库审计 — 单元覆盖对账表（乙 · B2）

- 工单：\`docs/ui/work-orders/WO-20260919-AUDIT-乙-编码修复与覆盖对账.md\` §B2
- 生产单元全集：**${units.length}**（${Object.entries(byDir).map(([k, v]) => k + ' ' + v).join(' + ')}），递归目录、以 \`unit\` 声明名为准
- 分包报告（11 份，H5 不改正文）：${PKGS.join('、')}
- 匹配口径：与主控 \`scan_coverage2.js\` 一致（单元全名 / 去 \`DeepBase.\` 前缀名，大小写不敏感，先主责分包后全分包兜底）；条目提取 = 命中行中的 \`X-NNN/X-YYY-NNN\` 编号或单元清单行
- 状态三值：已审（有独立条目/清单行）/ 已审·宽松匹配（正文出现名但无独立条目，补审注记见 §补审）/ 未审（任何分包零出现 → 本单补审）
- 复现：\`node CodeReview/_audit_recheck/b2_gen_reconcile.js\`；未覆盖清单 \`.tmp/b2-uncovered.json\`

## 汇总

| 状态 | 数量 |
|---|---|
${Object.entries(counts).map(([k, v]) => `| ${k} | ${v} |`).join('\n')}

## 全量对账表（${rows.length} 行）

| # | 单元 | 文件 | 分包 | 条目编号 | 状态 |
|---|---|---|---|---|---|
${rows.map((r, i) => `| ${i + 1} | ${r.unit} | ${r.path} | ${r.hitPkg.replace(/^20260918-|\.md$/g, '')} | ${r.ids} | ${r.status} |`).join('\n')}
`;
fs.writeFileSync(path.join(ROOT, 'CodeReview/20260919-全库审计-单元覆盖对账表.md'), md);
// 拼入人工补审章节（SSOT：b2-supplement-fragment.md，生成器不另写一份）
const frag = path.join(ROOT, 'CodeReview/_audit_recheck/b2-supplement-fragment.md');
if (fs.existsSync(frag)) {
  fs.appendFileSync(path.join(ROOT, 'CodeReview/20260919-全库审计-单元覆盖对账表.md'), fs.readFileSync(frag, 'utf8'));
  console.log('supplement appended');
}
console.log('units=' + units.length, JSON.stringify(counts));
console.log('uncovered:', uncovered.map(u => u.unit).join(', '));
