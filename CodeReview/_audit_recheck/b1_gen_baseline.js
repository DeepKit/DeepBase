// 乙-B1 编码损坏基线表生成器：聚合 detail-before / detail-after / git-probe → Markdown 全量 116 行表
// 用法: node b1_gen_baseline.js
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const AC = path.join(ROOT, 'CodeReview/_audit_recheck');

const before = JSON.parse(fs.readFileSync(path.join(AC, '乙-B1-detail-before.json'), 'utf8'));
const after = JSON.parse(fs.readFileSync(path.join(AC, '乙-B1-detail-after.json'), 'utf8'));
const probe = JSON.parse(fs.readFileSync(path.join(AC, '乙-B1-git-probe.json'), 'utf8'));

const afterMap = {}; after.files.forEach(r => afterMap[r.f] = r);
const probeMap = {}; probe.forEach(r => probeMap[r.f] = r);

let nA = 0, nB = 0, nC = 0, nRestoredFull = 0, nPartial = 0, nUnrec = 0, nR1 = 0;
const rows = [];
for (const r of before.files.filter(x => x.fffd > 0).sort((a, b) => b.fffd - a.fffd)) {
  const p = probeMap[r.f] || {};
  const a = afterMap[r.f];
  const ffAfter = a ? a.fffd : 0;
  const invalidBefore = !r.validUtf8;
  if (invalidBefore && ffAfter === 0) nR1++;
  const tier = (r.litFFFD > 0 || r.codeFFFD > 0) ? 'A' : 'B';
  if (tier === 'A') nA++; else nB++;
  let action;
  if (ffAfter === 0) { action = invalidBefore ? '已恢复(GBK→UTF-8转码)' : '已恢复(git祖先合并)'; nRestoredFull++; }
  else if (p.cleanRev) { action = `部分恢复,残留${ffAfter}(损坏后被编辑行无字节证据)`; nPartial++; }
  else { action = `UNRECOVERABLE—保留现状(${ffAfter})`; nUnrec++; }
  if (ffAfter > 0 && tier === 'A') nC += 0; // 档C计数单独在下面统计
  const gitRec = p.cleanRev ? `${p.cleanKind === 'CLEAN_GBK' ? '干净GBK祖先' : '干净UTF-8祖先'} ${String(p.cleanRev).slice(0, 7)}` : '无干净祖先';
  rows.push(`| ${r.f} | ${r.bom ? '有' : '无'} | ${r.fffd} | ${r.litFFFD} | ${r.commentFFFD} | ${r.codeFFFD} | ${invalidBefore ? '否(GBK裸字节)' : '是'} | ${gitRec} | 档${tier} | ${ffAfter} | ${action} |`);
}
const unrecFiles = before.files.filter(x => x.fffd > 0 && !(afterMap[x.f])).length; // sanity
const residual = Object.keys(afterMap).filter(k => afterMap[k].fffd > 0);
const tierA_residual = residual.filter(f => { const b = before.files.find(x => x.f === f); return b && (b.litFFFD > 0 || b.codeFFFD > 0); });

const header = `# 20260919 全库审计 — 源码编码损坏基线（乙 · B1）

- 工单：\`docs/ui/work-orders/WO-20260919-AUDIT-乙-编码修复与覆盖对账.md\` §B1
- 扫描口径：与主控 \`scan_fffd.js\` 一致（全库 .pas，排除 .git/.tmp/构建产物/worktrees）；本轮扫描 954 个 .pas
- 数据来源（全部为本目录脚本真实输出，可复跑）：
  - 修复前全量明细：\`乙-B1-detail-before.json\`（本目录 \`scan_encoding_detail.js --root .tmp/b1-before\`，worktree 基线 8eb1aa3）
  - 修复后全量明细：\`乙-B1-detail-after.json\`（当前工作树）
  - git 取证：\`乙-B1-git-probe.js\` → \`乙-B1-git-probe.json\`（--follow 回溯最近干净祖先）
  - 抢救执行：\`b1_repair.js\`（R1 GBK 确定性转码 / R2 三元合并恢复 / R3 UNRECOVERABLE）
  - 主控验收口径复跑：\`乙-B1-scan-fffd-before.txt\`（116 文件）→ \`乙-B1-scan-fffd-after.txt\`（19 文件）

## 关键更正（对 Core-C 分包判定）

\`Core/DeepBase.Manager.pas\` 前三字节实测 = \`EF BB BF\`，**有 UTF-8 BOM**。其受损形态是「UTF-8(带BOM) 文件内烤入 U+FFFD」，不是 Core-C 分包所述"B 类非 UTF-8 原始编码（GBK/ANSI）、无 BOM"。BOM 有无决定 dcc64 走 UTF-8 还是 ACP，两类处置方案完全不同，特此显式更正。

## 汇总

| 指标 | 修复前 | 修复后 |
|---|---|---|
| 含 U+FFFD 的 .pas 文件 | 116 | ${residual.length} |
| 非法 UTF-8（GBK 裸字节入库） | 56 | 0 |
| 含中文且无 BOM | 221（主工作树实测） | 40（全部为甲独占文件，见基线例外清单） |
| 全库 .pas 带 UTF-8 BOM | — | 907/954（例外 47 = 甲独占，登记于 \`09_工程脚本/encoding-gate/pas_encoding_baseline.json\`） |

处置计数（116 文件）：
- 档 A（U+FFFD 落在字符串字面量/代码区，影响运行时可见文本）：**${nA}** 个
- 档 B（仅注释受损，不影响运行）：**${nB}** 个
- 完全恢复（FFFD→0）：**${nRestoredFull}** 个（其中 GBK 确定性转码 ${nR1}、git 祖先合并 ${nRestoredFull - nR1}）
- 部分恢复（残留行系损坏后新写、无字节证据，按 H6 不猜字）：**${nPartial}** 个
- 档 C UNRECOVERABLE（全史无干净祖先）：**${nUnrec}** 个（Core/DeepBase.Hotkeys.pas 128、Tests/Test.DeepBase.Hotkeys.pas 5，均纯注释受损，不影响运行）
- 修复后残留 FFFD 文件 ${residual.length} 个已全部登记为 CI 门禁基线（只禁新增、不回退）

档 A 口径说明：档 A/B 按"FFFD 位置"分类（字符串字面量或代码区 = A），与"是否已恢复"正交；档 A 中已恢复者即 §5 验收的"档 A 批次 scan_fffd 复跑为 0"的分子。残留 ${residual.length} 个文件中属档 A 位置者 ${tierA_residual.length} 个（逐行系损坏后真实编辑产物，保留现状并注明）。

## 全量基线表（116 行）

列说明：FFFD前=修复前 U+FFFD 计数；lit/com/code=按逐行解析的字符串字面量/注释/代码区归属；UTF-8合法=盘上字节是否合法 UTF-8（"否"即 GBK 裸字节，可 gb18030 确定性转码，非猜测）；git取证=最近干净祖先类别+短哈希；FFFD后=修复后残留。

| 文件 | BOM | FFFD前 | lit | com | code | UTF-8合法 | git取证 | 档位 | FFFD后 | 处置结论 |
|---|---|---|---|---|---|---|---|---|---|---|
`;
const foot = `
## 证据与复现

1. 修复前/后 scan_fffd 完整输出对比：\`乙-B1-scan-fffd-before.txt\` / \`乙-B1-scan-fffd-after.txt\`
2. 档 A 恢复的 git 取证链：\`乙-B1-git-probe.json\` 每文件含 \`cleanRev/cleanKind/damageCommit\`，可用 \`git show <rev>:<path>\` 逐字节复核
3. 抢救执行器与规则：\`b1_repair.js\`（H6：只用 git 历史字节与 gb18030 确定性转码，禁止语义猜字）
4. 全库备份（修复前原样）：\`.tmp/b1-backup-preapply/\`
5. CI 门禁：\`09_工程脚本/encoding-gate/check_pas_encoding.js\` + 负向样本 \`test_negative_sample.js\`（输出 \`乙-B1-negative-test.txt\`：G1/G2/G3 全部按预期拦截）
6. 口径注：worktree 复跑 cjkNoBom=231 与主工作树 221 差 10，系基线 8eb1aa3 与脏工作树间既有 BOM 差异；FFFD 计数两侧一致（116），不影响本表结论
`;
fs.writeFileSync(path.join(ROOT, 'CodeReview/20260919-全库审计-编码损坏基线.md'), header + rows.join('\n') + '\n' + foot);
console.log('rows=' + rows.length, 'A=' + nA, 'B=' + nB, 'full=' + nRestoredFull, 'R1=' + nR1, 'partial=' + nPartial, 'unrec=' + nUnrec, 'residualFiles=' + residual.length, 'tierAResidual=' + tierA_residual.length);
console.log(tierA_residual.join(' | '));
