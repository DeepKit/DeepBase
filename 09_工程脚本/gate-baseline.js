// DeepBase 门禁基线文件状态自检（WO-20260923-AUDIT-乙-D5 §一-3）
//
// 与 B1 的分工（工单硬边界，不得重复实现）：
//   B1 守【写入动作】——`--emit-baseline` 防清空、防缩水、写前备份；
//   本模块守【文件状态】——基线不管被谁、用什么方式改坏（误用窄根 --emit-baseline、
//   merge 取错边、手工删条目、被另一道门的基线顶替），读进来时都必须先自证可信。
// 法源：2026-09-22 12:22 `eol_baseline.json` 被窄根 `--emit-baseline` 覆写（902→116 条）当场无人发现
//   （`CodeReview/20260922-AUDIT-主控-乙-P2b-验收结论.md` §四）。此前各门禁对坏基线的处理是
//   `try { JSON.parse(...) } catch (e) {}` 静默回落到空豁免集——把「基线坏了」伪装成「全库新增 886 条违规」，
//   既误导分诊又让真正的状态损坏混在噪声里。
//
// 校验项（都是状态断言；刻意【不做】条目数下限/「全空即疑清空」：存量归零是正当目标，
// 计数下限会在债务清完那天变成假警报，而基线被清空后的真实违规本来就会让门禁报红）：
//   T1 文件存在且可读
//   T2 可解析，且顶层为 JSON 对象（数组/null/标量一律不可信）
//   T3 溯源字段非空：generated / generatedFrom / _comment 三者之一为非空字符串
//      ——没有溯源就无法回答「它是哪一次全量扫描的产物」，与 12:22 那次窄根产物同构
//   T4 该门声明的必需键齐备且类型正确（array=字符串数组，object=非数组对象）
//      ——被别的门的基线顶替时，键缺失/类型不符在这里暴露，而不是让整棵树变成假违规海
//
// 失败即 process.exit(2)（门禁自身执行失败），与调用方既有退出码语义一致：绝不放行。
'use strict';

const fs = require('fs');

const PROVENANCE_KEYS = ['generated', 'generatedFrom', '_comment'];

function isPlainObject(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }

function problems(file, baseline, keys) {
  const errs = [];
  const found = PROVENANCE_KEYS.filter(k => typeof baseline[k] === 'string' && baseline[k].trim() !== '');
  if (found.length === 0) {
    errs.push(`T3 溯源字段缺失或为空（需 ${PROVENANCE_KEYS.join(' / ')} 三者之一的非空字符串）：` +
      `无法判断该基线来自哪次扫描，也就无法判断它是否被窄根扫描或他人覆写`);
  }
  for (const [key, kind] of Object.entries(keys)) {
    if (!(key in baseline)) { errs.push(`T4 必需键缺失: ${key}（该门禁的豁免集，键不在即视为基线被替换/清空）`); continue; }
    const v = baseline[key];
    if (kind === 'array' && !(Array.isArray(v) && v.every(x => typeof x === 'string'))) {
      errs.push(`T4 键 ${key} 应为字符串数组，实际为 ${Array.isArray(v) ? '含非字符串元素的数组' : typeof v}`);
    }
    if (kind === 'object' && !isPlainObject(v)) {
      errs.push(`T4 键 ${key} 应为对象，实际为 ${Array.isArray(v) ? 'array' : v === null ? 'null' : typeof v}`);
    }
  }
  return errs;
}

/**
 * 读取并校验门禁基线；不可信时按 fail-closed 直接 EXIT=2，不返回。
 * @param {{file:string, label:string, keys:Record<string,'array'|'object'>}} spec
 * @returns {object} 通过校验的基线对象
 */
function loadGateBaseline(spec) {
  const { file, label, keys } = spec;
  const die = (reasons) => {
    console.error(`${label}门禁失败：基线不可信（${file}）——已按 fail-closed 拒绝放行:`);
    reasons.forEach(r => console.error('  ' + r));
    process.exit(2);
  };

  let raw;
  try {
    raw = fs.readFileSync(file, 'utf8');
  } catch (e) {
    die([`T1 基线文件不可读（不存在或被删除）: ${e.code || e.message}`]);
  }
  let baseline;
  try {
    baseline = JSON.parse(raw);
  } catch (e) {
    die([`T2 基线不是合法 JSON（文件被截断/改写坏）: ${e.message}`]);
  }
  if (!isPlainObject(baseline)) die([`T2 基线顶层不是 JSON 对象（实际为 ${Array.isArray(baseline) ? 'array' : String(baseline)}）`]);
  const errs = problems(file, baseline, keys);
  if (errs.length) die(errs);
  return baseline;
}

module.exports = { loadGateBaseline, PROVENANCE_KEYS };
