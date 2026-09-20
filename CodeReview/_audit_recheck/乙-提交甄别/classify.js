// 乙 提交范围甄别：解析 git diff -U0 输出，将 M 的 .pas 分为 BOM-only / 实质改动，并按所有权归类
const fs = require('fs');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const BOM = '\uFEFF';

// 1) git status 分类
const status = fs.readFileSync(ROOT + '/.tmp/b5/gitstatus.txt', 'utf8').split(/\r?\n/).filter(Boolean);
const M = [], UU = [], OTHER = [];
for (const l of status) {
  const xy = l.slice(0, 2);
  let p = l.slice(3);
  // 解八进制转义引号路径
  if (p.startsWith('"') && p.endsWith('"')) {
    p = p.slice(1, -1).replace(/\\([0-7]{3})/g, (_, o) => String.fromCharCode(parseInt(o, 8)));
  }
  if (xy === '??') OTHER.push({ xy, p });
  else if (xy === ' M' || xy === 'M ' || xy === 'MM') M.push(p);
  else UU.push({ xy, p });
}

// 2) 解析 diff0.txt
const raw = fs.readFileSync(ROOT + '/.tmp/b5/diff0.txt', 'utf8');
const fileDiffs = new Map(); // path -> {hunks:[{header,minus:[],plus:[]}]}
let cur = null, hunk = null;
for (const line of raw.split('\n')) {
  if (line.startsWith('diff --git ')) {
    const m = line.match(/^diff --git a\/(.*?) b\/(.*)$/);
    cur = { path: m[2], hunks: [] };
    fileDiffs.set(m[2], cur);
    hunk = null;
  } else if (line.startsWith('+++ ') || line.startsWith('--- ') || line.startsWith('index ') || line.startsWith('new file') || line.startsWith('deleted file') || line.startsWith('old mode') || line.startsWith('new mode') || line.startsWith('\\ ')) {
    continue;
  } else if (line.startsWith('@@')) {
    hunk = { header: line, minus: [], plus: [] };
    if (cur) cur.hunks.push(hunk);
  } else if (hunk) {
    if (line.startsWith('-')) hunk.minus.push(line.slice(1));
    else if (line.startsWith('+')) hunk.plus.push(line.slice(1));
  }
}

function isEOLBOMOnly(d) {
  // 仅 EOL(CRLF化) + 首行BOM：每个 hunk 内 minus/plus 行数相等且去掉行尾\r后逐行相等（首行允许多 BOM）
  if (!d || d.hunks.length === 0) return false;
  for (const h of d.hunks) {
    if (h.minus.length !== h.plus.length) return false;
    for (let i = 0; i < h.minus.length; i++) {
      const a = h.minus[i];
      const b2 = h.plus[i].startsWith(BOM) ? h.plus[i].slice(1) : h.plus[i];
      if (b2 === a || b2 === a + '\r' || a === b2 + '\r') continue;
      return false;
    }
  }
  return true;
}

function isBOMOnly(d) {
  if (!d) return false;
  if (d.hunks.length !== 1) return false;
  const h = d.hunks[0];
  if (!/^@@ -1 \+1 @@/.test(h.header)) return false;
  if (h.minus.length !== 1 || h.plus.length !== 1) return false;
  return h.plus[0] === BOM + h.minus[0];
}

// 3) 清单
const b1Repair = new Set(fs.readFileSync(ROOT + '/.tmp/b5/b1-repair-files.txt', 'utf8').split(/\r?\n/).filter(Boolean).map(s => s.trim()));
const yiSurgical = new Set([
  'Core/DeepBase.AIErrorHandler.pas', 'Core/DeepBase.MVVM.pas', 'Core/DeepBase.Feedback.pas',
  'Core/DeepBase.Scheduler.pas', 'Core/DeepBase.WorkerQueue.pas',
  'Features/DeepBase.Browser.CDP.pas', 'Tests/Test.DeepBase.Browser.CDP.pas',
  'Core/DeepBase.Plugins.CAbi.pas', 'Core/DeepBase.Plugins.CAbiLoader.pas', 'Core/DeepBase.Plugins.Contracts.pas',
  'Core/DeepBase.Plugins.Manager.pas', 'Core/DeepBase.Plugins.SafeGuard.pas', 'Core/DeepBase.Plugins.Verifier.pas',
]);
const jiaRe = [
  /^Core\/DeepBase\.Crypto/, /^Features\/DeepBase\.(Updater|AutoUpdate|UIA)/, /^Governance\//,
  /^Core\/DeepBase\.HB\./, /(^|\/)(VCL|FMX)\/.*\.HB\./, /^Tests\/.*\.HB\./,
  /^Features\/UIAutomationClient_TLB\.pas$/, /^CodeReview\//, /^docs\//, /^TestResults\//,
  /^DeepFlow\//, /^Examples\/Templates\/Common\/Template\.AutoUpdateBootstrap\.pas$/,
];
const isJia = p => jiaRe.some(re => re.test(p));

const out = { bomOnly: [], eolBomOnly: [], sub_YI_B1: [], sub_YI_surgical: [], sub_MIXED_YI: [], sub_JIA_or_2: [], sub_UNKNOWN: [], pas_no_diff: [] };
for (const p of M.filter(x => /\.pas$/i.test(x))) {
  const d = fileDiffs.get(p);
  if (!d) { out.pas_no_diff.push(p); continue; }
  if (isBOMOnly(d)) { out.bomOnly.push(p); continue; }
  if (d.hunks.length > 1 && isEOLBOMOnly(d)) { out.eolBomOnly.push(p); continue; }
  if (isEOLBOMOnly(d)) { out.eolBomOnly.push(p); continue; }
  const yiB1 = b1Repair.has(p), yiSur = yiSurgical.has(p);
  if (yiB1 && yiSur) out.sub_MIXED_YI.push(p);
  else if (yiSur) out.sub_YI_surgical.push(p);
  else if (yiB1) out.sub_YI_B1.push(p);
  else if (isJia(p)) out.sub_JIA_or_2.push(p);
  else {
    const h = d.hunks[0];
    out.sub_UNKNOWN.push({ p, first: (h.minus[0] || h.plus[0] || '').slice(0, 120), hunks: d.hunks.length });
  }
}
const nonPas = M.filter(x => !/\.pas$/i.test(x));
console.log(JSON.stringify({
  counts: { statusTotal: status.length, M: M.length, untracked: OTHER.length, UU: UU.length,
    bomOnly: out.bomOnly.length, eolBomOnly: out.eolBomOnly.length, sub_YI_B1: out.sub_YI_B1.length, sub_YI_surgical: out.sub_YI_surgical.length,
    sub_MIXED_YI: out.sub_MIXED_YI.length, sub_JIA_or_2: out.sub_JIA_or_2.length,
    sub_UNKNOWN: out.sub_UNKNOWN.length, pas_no_diff: out.pas_no_diff.length }
}, null, 1));
fs.writeFileSync(ROOT + '/.tmp/b5/classify.json', JSON.stringify(out, null, 1));
fs.writeFileSync(ROOT + '/.tmp/b5/classify-nonpas.txt', nonPas.join('\n') + '\n=== UU ===\n' + UU.map(u => u.xy + ' ' + u.p).join('\n') + '\n=== UNTRACKED ===\n' + OTHER.map(u => u.p).join('\n'));
console.log('--- sub_UNKNOWN ---');
for (const u of out.sub_UNKNOWN) console.log(u.p, '|hunks=' + u.hunks, '|', u.first);
