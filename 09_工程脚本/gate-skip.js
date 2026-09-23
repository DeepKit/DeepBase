// DeepBase 门禁 SKIP 目录名集（单一实现·多道门禁共用）
//
// 背景（WO-20260923-AUDIT-乙-D5 §一-2；法源 README-门禁覆盖面 §四-5）：
// 「哪些目录不是源码/证据现场」这一判断此前被抄成五份字面量，并且已经漂移到口径分裂——
// 编码/行尾/托管拷贝三道 SKIP `TestResults/`（CI 产物），构建归属那道却缺这一项，
// 证据门禁那道只有 7 项。于是「某个目录被哪道门跳过」无法一眼回答，而 SKIP 集每漂一次，
// 扫描面就静默缩一次（WO-20260921-AUDIT-乙-P1 §〇 把「扫描面缩水不可见」列为独立缺陷类）。
// 本模块是写入口唯一的真相源：口径差异只允许出现在「该门专属的额外目录」上，
// 且必须写在调用点、可被 grep 到。
'use strict';

// 共享口径：构建产物、编译器中间物、AI/工具工作目录、CI 测试输出。
// 这些目录里的文件不是审计现场，扫它们只会把门禁噪声变成豁免噪声。
const GATE_SKIP_DIRS = Object.freeze([
  '.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu',
  'node_modules', '.tmp', '.superpowers', '.workbuddy', 'TestResults',
]);

// 返回新 Set：调用方就地 add 改不动共享集合，避免某道门又把自己的一项目悄悄塞进公共口径。
function gateSkipSet(...extra) {
  return new Set([...GATE_SKIP_DIRS, ...extra]);
}

module.exports = { GATE_SKIP_DIRS, gateSkipSet };
