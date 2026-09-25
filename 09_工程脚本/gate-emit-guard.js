// DeepBase 基线写入守卫（WO-20260925-AUDIT-总控-封版后余量总单 包二 B1 §1；
// 承接 WO-20260922-AUDIT-乙-基线写入守卫 的守卫一/三，缩水口径按总单 §1 取代旧单）
//
// 为什么单独一个模块：各门 `--emit-baseline` 此前各写各的，写入语义并不一致——
//   eol / 托管拷贝 / 编译噪声 = 从空起算全量覆盖（2026-09-22 12:22 事故形态：窄根一次写出 902→116 条）；
//   丙类损坏门禁 = 内联自带只减不增（判据实现散落在门里，第二份判据必然漂移）；
//   构建归属门 = 会把新孤儿自动写成「待标注」（= 自动扩面）。
// 总单判据是「任何自动/脚本路径不得新增基线条目」——判据本身必须只有一份实现，故收口到此。
//
// 三条守卫：
//   一、扫描面自证：root 必须是仓库根（或显式 --allow-narrow-root 放开并打印告警），
//       且扫描数不得低于量级下限（个位数扫描 = SKIP 吃掉源码树 / root 指错）；
//   二、只减不增：新基线的条目集必须是旧基线的【子集】——新文件键、新增条目、任一数值字段抬升
//       一律拒绝写入并 EXIT=1；条目减少（债务清完）放行并打印降幅。
//       （旧单「缩水默认拒绝 + --force-shrink」被总单 §1「条目数下降放行」取代；缩水的事故形态
//         由守卫一兜住：窄根写入在到达比对之前就已经被拒。）
//   三、写前备份：旧基线先复制为 <file>.bak 再写，误写可一键还原（*.bak 已在 .gitignore）。
// 首建（目标基线不存在）无可比对象 ⇒ 跳过守卫二，守卫一仍生效。
//
// 退出码：拒绝写入 EXIT=1；旧基线存在但不可解析/顶层非对象 EXIT=2（与读侧 gate-baseline.js T2 同语义：
// 基线是 git 跟踪件，恢复路径 = `git checkout -- <file>`，不允许 emit 在坏基线上重刷）。
'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_MIN_SCAN = 10;

function isPlainObject(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }

/**
 * 纯函数：只减不增比对（可脱离写入动作单独做单元测试）。
 * 条目承载键的两种形态：数组 = 集合（字符串条目集）；对象 = 按条目键映射，
 * 其中字符串字段（reason/disposition 等人工标注）不参与比对，数值字段逐个只减不增。
 * @param {object|null} oldBaseline 旧基线（null = 首建，跳过比对）
 * @param {object} newBaseline 待写基线
 * @param {string[]} entryKeys 承载条目的顶层键
 * @returns {{added:string[], risen:string[], lostKeys:string[], removed:number, decreased:number, skipped:boolean}}
 */
function checkOnlyDecrease(oldBaseline, newBaseline, entryKeys) {
  const res = { added: [], risen: [], lostKeys: [], removed: 0, decreased: 0, skipped: oldBaseline === null || oldBaseline === undefined };
  if (res.skipped) return res;
  for (const key of entryKeys) {
    const oldV = oldBaseline[key];
    const newV = newBaseline[key];
    if (newV === undefined) { res.lostKeys.push(key); continue; } // 整键消失 = 读侧 T4 必红，写入侧同样拒绝
    if (Array.isArray(newV)) {
      const oldArr = Array.isArray(oldV) ? oldV : [];
      if (!Array.isArray(oldV) && oldV !== undefined) { res.added.push(`${key}: <条目类型改变>`); continue; }
      const oldSet = new Set(oldArr);
      const newSet = new Set(newV);
      for (const e of newV) if (!oldSet.has(e)) res.added.push(`${key}: ${e}`);
      for (const e of oldArr) if (!newSet.has(e)) res.removed++;
      continue;
    }
    if (!isPlainObject(newV)) { res.added.push(`${key}: <条目类型改变>`); continue; }
    const oldObj = isPlainObject(oldV) ? oldV : {};
    if (oldV !== undefined && !isPlainObject(oldV)) { res.added.push(`${key}: <条目类型改变>`); continue; }
    for (const [entry, nv] of Object.entries(newV)) {
      if (!(entry in oldObj)) { res.added.push(`${key}: ${entry}`); continue; }
      const ov = oldObj[entry];
      if (typeof nv === 'number' || typeof ov === 'number') {
        // 扁平计数映射（编译噪声 noise: {码: 次数}）
        const newNum = typeof nv === 'number' ? nv : 0;
        const oldNum = typeof ov === 'number' ? ov : 0;
        if (newNum > oldNum) res.risen.push(`${key}: ${entry} ${oldNum} → ${newNum}`);
        else if (newNum < oldNum) res.decreased++;
      } else if (nv && typeof nv === 'object' && ov && typeof ov === 'object') {
        // 复合计数条目（托管拷贝 files:{move,fillchar} / 丙类 pbStock:{count,reason}）：
        // 只比数值字段，字符串字段（reason/disposition 等人工标注）不参与只减不增。
        for (const [field, newNum] of Object.entries(nv)) {
          if (typeof newNum !== 'number') continue;
          const oldNum = typeof ov[field] === 'number' ? ov[field] : 0;
          if (newNum > oldNum) res.risen.push(`${key}: ${entry}.${field} ${oldNum} → ${newNum}`);
          else if (newNum < oldNum) res.decreased++;
        }
      }
    }
    res.removed += Object.keys(oldObj).filter(e => !(e in newV)).length;
  }
  return res;
}

/**
 * 守卫化写入：三守卫全过才落盘，否则拒绝并 process.exit。
 * 调用方只负责算出 newBaseline 并打印自己的生成摘要，不得绕过本函数写基线。
 * @param {object} o
 * @param {string} o.label          门禁名（报错前缀，如「行尾」）
 * @param {string} o.baselinePath   目标基线文件
 * @param {string} o.root           本轮扫描根
 * @param {string} o.repoRoot       完整仓库根
 * @param {boolean} o.allowNarrowRoot --allow-narrow-root 显式放开
 * @param {number} o.scanCount      本轮扫描文件数（守卫一量级自证）
 * @param {string[]} o.entryKeys    承载条目的顶层键
 * @param {object} o.newBaseline    待写对象
 * @param {string} [o.incomparableReason] 传入即拒绝（比对前提不成立的场景，由调用方给出原因）
 * @param {number} [o.space]        JSON 缩进（默认 2）
 * @param {boolean} [o.trailingNewline] 是否以 \n 收尾（默认 true）
 * @returns {{added:string[], risen:string[], lostKeys:string[], removed:number, decreased:number, skipped:boolean}}
 */
function guardedEmitBaseline(o) {
  const { label, baselinePath, root, repoRoot, allowNarrowRoot = false, scanCount, entryKeys, newBaseline,
    incomparableReason = null, space = 2, trailingNewline = true } = o;

  const reject = (lines) => {
    console.error(`${label}门禁：--emit-baseline 拒绝写入基线（EXIT≠0，目标文件保持原样）`);
    (Array.isArray(lines) ? lines : [lines]).forEach(l => console.error('  ' + l));
    process.exit(1);
  };

  // 守卫一：扫描面自证（窄根 = 2026-09-22 12:22 事故的直接成因）
  if (incomparableReason) reject(incomparableReason);
  const resolvedRoot = path.resolve(root);
  const resolvedRepo = path.resolve(repoRoot);
  if (resolvedRoot !== resolvedRepo) {
    if (!allowNarrowRoot) {
      reject([
        `扫描根不是仓库根：root=${resolvedRoot}（仓库根 ${resolvedRepo}）。`,
        '窄根扫描只会看到子树的违规，据此覆盖基线会把整片豁免集一次性缩水（2026-09-22 12:22 事故：902 → 116 条，行尾门禁当场 886 项红）。',
        '确要对子树定向重扫，请显式加 --allow-narrow-root（会打印告警，产物不得用作正式基线）。',
      ]);
    }
    console.error(`告警：--allow-narrow-root 放开窄根，本轮基线生成自 ${resolvedRoot}（条目面为子集，勿作正式基线）`);
  } else if (!allowNarrowRoot && !(scanCount >= DEFAULT_MIN_SCAN)) {
    reject(`扫描面自证失败：本轮仅扫到 ${scanCount} 个文件（量级下限 ${DEFAULT_MIN_SCAN}），疑似 root 指错或 SKIP 规则吃掉了源码树。`);
  }

  // 旧基线读取（存在即必须可解析：基线是 git 跟踪件，坏基线的恢复路径是 git checkout，不是重刷）
  let oldBaseline = null;
  let oldExists = false;
  if (fs.existsSync(baselinePath)) {
    oldExists = true;
    let raw;
    try { raw = fs.readFileSync(baselinePath, 'utf8'); } catch (e) {
      console.error(`${label}门禁：旧基线不可读 ${baselinePath} (${e.code || e.message})。基线不可信，已按 fail-closed 拒绝写入（EXIT=2）。`);
      process.exit(2);
    }
    try { oldBaseline = JSON.parse(raw); } catch (e) {
      console.error(`${label}门禁：旧基线不可解析（${e.message}）。基线不可信，已按 fail-closed 拒绝写入（EXIT=2）；恢复：git checkout -- ${baselinePath}`);
      process.exit(2);
    }
    if (!isPlainObject(oldBaseline)) {
      console.error(`${label}门禁：旧基线顶层不是 JSON 对象。基线不可信，已按 fail-closed 拒绝写入（EXIT=2）；恢复：git checkout -- ${baselinePath}`);
      process.exit(2);
    }
  }

  // 守卫二：只减不增
  const cmp = checkOnlyDecrease(oldBaseline, newBaseline, entryKeys);
  if (!cmp.skipped) {
    if (cmp.lostKeys.length) reject([`拒绝丢失原有条目键（整键消失会让读侧 T4 当场 EXIT=2，基线被锁死）：${cmp.lostKeys.join(', ')}`]);
    if (cmp.added.length) reject([
      '拒绝新增条目（自动/脚本路径不得新增基线条目；新增须人工写入并给出 reason 说明）：',
      ...cmp.added.slice(0, 30).map(x => '  ' + x),
      ...(cmp.added.length > 30 ? [`  …… 共 ${cmp.added.length} 项`] : []),
    ]);
    if (cmp.risen.length) reject([
      '拒绝抬高条目计数（只减不增；实测高于基线说明是新增违规或新增噪声，须先修复或人工评审改基线）：',
      ...cmp.risen.slice(0, 30).map(x => '  ' + x),
      ...(cmp.risen.length > 30 ? [`  …… 共 ${cmp.risen.length} 项`] : []),
    ]);
  }

  // 守卫三：写前备份 → 写入
  if (oldExists) {
    fs.copyFileSync(baselinePath, baselinePath + '.bak');
    console.log(`${label}门禁：写前备份 ${baselinePath}.bak（误写还原 = 用 .bak 覆盖回原文件）`);
  }
  fs.writeFileSync(baselinePath, JSON.stringify(newBaseline, null, space) + (trailingNewline ? '\n' : ''), 'utf8');
  if (cmp.skipped) console.log(`${label}门禁：目标基线不存在，首次生成（跳过只减不增比对，扫描面已自证）`);
  else if (cmp.removed || cmp.decreased) console.log(`${label}门禁：只减不增核对通过（条目减少 ${cmp.removed}，计数下调 ${cmp.decreased}，新增 0 / 抬升 0）`);
  return cmp;
}

module.exports = { guardedEmitBaseline, checkOnlyDecrease, DEFAULT_MIN_SCAN };
