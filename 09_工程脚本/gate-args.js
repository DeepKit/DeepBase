// DeepBase 工程门禁参数解析（单一实现·两份门禁共用）
//
// 背景（WO-20260922-AUDIT-乙-P2 §3.3 打回补做 §七）：
// 原实现两张门禁各写一份内联校验，且裂成两半——校验侧把 `--ROOT` 小写归一后当已知参数放行，
// 取值侧 arg() 用大小写敏感的 indexOf 取不到该 key，于是【静默回落默认 root】，扫 975 个
// 文件报 EXIT=0。这是「验证器接受、取值器不认」型假绿，比没校验更危险：调用方以为指定了
// root，实际扫的是缺省根，绿单覆盖了真正该检查的目录。
//
// 本模块把校验与取值压回同一份实现：校验器只认它自己返回的归一化 key，取值侧从同一份
// 归一化结果读数，物理上不存在「校验接受的取值侧不认」的裂缝。
//
// 覆盖 5 类 fail-open：未知参数 / 缺值 / 裸位置参数 / 大小写不符 / 值形似参数。
// 一律 EXIT=3（大小写选 §7.2#2 方案 (a)：一律报错，不设别名，故无需取值侧归一）。
//
// 退出码语义由调用方各自产出；本模块只负责：成功→返回 opts，失败→process.exit(3)。
'use strict';

// 无 fs 依赖：纯字符串处理
const path = require('path');

/**
 * @param {string} argvSource 通常是 process.execPath 之后的 argv 切片，即 process.argv.slice(2)
 * @param {object} spec       { label, root, baseline, extra }
 *   label    失败信息里的门禁名（如「编码」）
 *   root     该门禁的默认 root（已 resolve 前的原始路径）
 *   baseline 该门禁的默认 baseline 文件路径
 *   extra    额外合法开关集合（eol 门禁的 --emit-baseline）
 * @returns {{ root: string, baseline: string, flags: Set<string>, consumed: string[] }}
 */
function parseGateArgs(argv, spec) {
  const known = new Set(['root', 'baseline', 'help', ...(spec.extra || [])]);
  const flags = new Set();
  const consumed = [];

  for (let i = 0; i < argv.length; i++) {
    const t = argv[i];
    if (typeof t !== 'string' || t === '') continue;
    if (!t.startsWith('--')) {
      fail(spec.label, t, '不是合法参数（应为 --root / --baseline 形式的命名参数）', known);
    }
    const eq = t.indexOf('=');
    const raw = eq > 0 ? t.slice(0, eq) : t;
    const key = raw.slice(2).toLowerCase();

    // 大小写一律 EXIT=3：`--ROOT` 与 `--root` 不是同一个参数。
    // 归一化（toLowerCase）在此【不适用】：一旦归一，这道裂隙会被原样重开——
    // 旧裂根因正是校验侧归一放行、取值侧大小写敏感取空。
    // 原参数名用于报错，归一结果只用于「是否已知」的判定与读值，两侧读同一份。
    const exact = raw.slice(2);
    if (exact !== exact.toLowerCase()) {
      fail(spec.label, t, `大小写不符（应为小写 --${exact.toLowerCase()}）；大小写变体一律拒绝，不接受为别名`, known);
    }
    if (!known.has(key)) {
      fail(spec.label, t, '为未知参数', known);
    }
    if (key === 'help') { flags.add('help'); continue; }

    const isFlagOnly = (spec.extra || []).includes(key);
    if (isFlagOnly) {
      if (eq >= 0) fail(spec.label, t, `${key} 为无值开关，不接受 = 取值`, known);
      flags.add(key);
      continue;
    }

    if (eq > 0) {
      const v = t.slice(eq + 1);
      if (v === '') fail(spec.label, t, '缺值（= 号后为空）', known);
      if (v.startsWith('--')) fail(spec.label, t, `值形似参数（实参为 ${v}）`, known);
      consumed.push(key, v);
      continue;
    }
    const nxt = argv[i + 1];
    if (nxt === undefined || nxt.startsWith('--')) {
      // `--root --root` / `--root` 收尾：旧实现让后一个被当 path 静默吞掉，或回退默认值
      fail(spec.label, t, '缺值（后无实参）', known);
    }
    consumed.push(key, nxt);
    i++;
  }

  const map = new Map();
  for (let i = 0; i < consumed.length; i += 2) {
    if (!map.has(consumed[i])) map.set(consumed[i], consumed[i + 1]);
  }
  return {
    root: path.resolve(map.get('root') || spec.root),
    baseline: path.resolve(map.get('baseline') || spec.baseline),
    flags,
    consumed,
  };
}

function fail(label, raw, why, known) {
  console.error(
    `${label}门禁失败：${raw ? '参数 ' + raw + ' ' : ''}${why}` +
    `（已知参数: --root <dir> / --baseline <file>${[...known].filter(k => k !== 'root' && k !== 'baseline' && k !== 'help').map(k => ' / --' + k).join('')}）。已按 fail-closed 拒绝放行。`
  );
  process.exit(3);
}

module.exports = { parseGateArgs };
