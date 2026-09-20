// 乙-B3 构建归属清单生成器：孤儿单元 × 引用面统计 × 三选一处置 → 回写 baseline + 产出 Markdown 清单
// 用法: node b3_gen_list.js
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const OWN = path.join(ROOT, '09_工程脚本/build-ownership');
const PROD_DIRS = ['Core', 'Features', 'Persistence', 'VCL', 'FMX', 'Governance', 'Tools', 'DeepFlow'];
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.tmp', '.superpowers', '.workbuddy']);

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
const baseline = JSON.parse(fs.readFileSync(path.join(OWN, 'build_ownership_baseline.json'), 'utf8'));
const prodFiles = [];
for (const d of PROD_DIRS) walk(path.join(ROOT, d), prodFiles);

// 每个孤儿：被多少个其他生产单元按单元名引用（隐式编译风险面）
const rows = [];
for (const rel of Object.keys(baseline.orphans).sort()) {
  const unit = /^unit\s+([A-Za-z_][\w.]*)/m.exec(fs.readFileSync(path.join(ROOT, rel), 'utf8'));
  const u = unit ? unit[1] : path.basename(rel, '.pas');
  const re = new RegExp('\\b' + u.replace(/\./g, '\\.') + '\\b');
  const referrers = [];
  for (const f of prodFiles) {
    const r = path.relative(ROOT, f).replace(/\\/g, '/');
    if (r === rel) continue;
    if (re.test(fs.readFileSync(f, 'utf8'))) referrers.push(r);
  }
  let disposition, reason;
  if (referrers.length > 0) {
    disposition = '建议入构建（待构建责任人执行）';
    reason = `被 ${referrers.length} 个生产单元按名引用，可能经隐式搜索路径编译入包（构建清单失真源）`;
  } else {
    disposition = '显式标记为非构建资产';
    reason = '全仓构建文件与生产单元源码均零引用';
  }
  if (rel.includes('DeepBase.FMX.HB.') || rel.includes('DeepBase.VCL.HB.')) {
    reason += '；HB 视觉系统观察期单元，最终处置须报主控（H2）';
  }
  if (rel === 'Core/DeepBase.Manifest.Verifier.pas' || rel === 'Core/DeepBase.Crypto.JCS.pas') {
    reason += '；相邻线（Manifest 观察期 / Crypto 甲独占域）处置报主控';
  }
  baseline.orphans[rel] = { unit: u, disposition, reason, referrerCount: referrers.length, referrers: referrers.slice(0, 6) };
  rows.push({ rel, u, n: referrers.length, disposition, reason });
}
fs.writeFileSync(path.join(OWN, 'build_ownership_baseline.json'), JSON.stringify(baseline, null, 1));

const NEWTRACK_ROWS = ['CAbi', 'CAbiLoader', 'Contracts', 'Manager', 'SafeGuard', 'Verifier'].map(n => ({
  rel: `Core/DeepBase.Plugins.${n}.pas`, u: `DeepBase.Plugins.${n}`
}));

const md = `# 20260919 全库审计 — 构建归属清单（乙 · B3）

- 工单：\`docs/ui/work-orders/WO-20260919-AUDIT-乙-编码修复与覆盖对账.md\` §B3；双轨法源：H10 + 主控终裁 commit \`2f011fd\`（生产唯一真相源 = 旧轨 BPL，新轨冻结隔离 C1–C5）
- 机器口径（可一键复现）：\`node 09_工程脚本/build-ownership/check_build_ownership.js\`
  - 生产单元全集 = Core/Features/Persistence/VCL/FMX/Governance/Tools/DeepFlow 八目录 565 个 .pas（与 B2 同口径）
  - 构建文件全集 = 仓内全部 .dpk（contains）/ .dproj（DCCReference/MainSource）/ .dpr（uses），共 122 个
  - 孤儿 = 单元名在构建文件全集零显式列名。**注意**：Delphi 允许单元不经 contains 显式列名而经搜索路径被隐式编译，故"零列名"≠"零参与"；下表 referrers 列即隐式引用面
- 门禁规则：O1 新增未登记孤儿 ⇒ FAIL；O2 新轨进入 .dpk/.dproj ⇒ BLOCK；O3 新轨同名类 \`TDeepBasePluginManager\` 复活 ⇒ FAIL；O4 非新轨生产单元源码引用新轨 ⇒ BLOCK
- 基线（SSOT）：\`09_工程脚本/build-ownership/build_ownership_baseline.json\`（本清单由其生成，逐条含处置三选一）
- 负向样本：\`09_工程脚本/build-ownership/test_negative_sample.js\`，输出 \`CodeReview/_audit_recheck/乙-B3-negative-test.txt\`（O1/O2/O4 全拦截，OWNERSHIP-NEGATIVE-TEST: PASS）

## 新轨 DeepBase.Plugins.* 六单元（按 H10/C1–C5 冻结隔离登记）

| 单元 | 构建归属 | 处置 |
|---|---|---|
${NEWTRACK_ROWS.map(r => `| ${r.u} | 不在任何 .dpk/.dproj（仅 Tests\\Plugins\\*.dpr 测试具案引用） | 非构建资产（待复活评估）；FROZEN 头标记已加（C3）；同名类已消解 TDllPluginManager（C1，Manager.pas 35 处） |`).join('\n')}

**C4 声明**：本清单与回执不表述新轨"已具备"任何运行时能力；其 SafeGuard/Verifier/Lease 门禁无运行时证据，且 \`Plugins.Manager.pas:431\` 编译不过（PChar→PAnsiChar 未修）。

**C5 复活门槛（四条全满足才允许评估启用，登记备查）**：① 修 \`Plugins.Manager.pas:431\`、\`Plugins.CAbiLoader.pas:228/:236\` 的 PChar→PAnsiChar，6 单元进独立测试包编译通过；② \`PluginLifecycleHarness.dpr\` 在 CI 独立 job 跑通、产物留存；③ 三个等价回归迁移全绿（沙箱 BUG062 / 配置绕过 BUG063 / 卸载顺序 BUG340）+ 新增验签用例；④ 存在真实生产调用需求（跨语言插件 / 非 Windows 平台 / 热重载），不得为"架构更好看"启用。

## 孤儿单元机器清单（${rows.length} 个，dpk/dproj 零显式列名口径）

| 文件 | 单元名 | 生产侧按名引用数 | 处置（三选一） | 理由 |
|---|---|---|---|---|
${rows.map(r => `| ${r.rel} | ${r.u} | ${r.n} | ${r.disposition} | ${r.reason} |`).join('\n')}

## 旧轨完整性声明

\`Core/DeepBase.PluginManager.pas\`（生产唯一真相源）除 B1 编码抢救（其 41 处 U+FFFD 系注释区恢复，档B）外无逻辑改动；类名 \`TDeepBasePluginManager\` 保留于旧轨（30 处），新轨已改名消解遮蔽风险。

## 遗留决策移交（不在本单决策）

- "建议入构建"的 ${rows.filter(r => r.n > 0).length} 个单元是否补列名进对应 .dpk contains，属构建责任人/主控裁定（涉及包结构变更），本单只登记不执行；CI 门禁已保证其不会静默扩大。
`;
fs.writeFileSync(path.join(ROOT, 'CodeReview/20260919-全库审计-构建归属清单.md'), md);
console.log('orphans=' + rows.length, 'implicit=' + rows.filter(r => r.n > 0).length, 'zero-ref=' + rows.filter(r => r.n === 0).length);
