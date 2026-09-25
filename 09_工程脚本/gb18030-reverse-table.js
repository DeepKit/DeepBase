// GB18030 反表唯一实现（WO-20260925-AUDIT-总控 §B1-2「反表三处合一」）
//
// 合并前同构副本三处：.tmp/gb18030_rev.json（数据）+ .tmp/mb_table.py（生成器）+
// 检测器内置（mojibake-core / encoding-gate G6 / evidence-encoding-gate E3）。
// 现统一：检测器一律 require 本模块取表；数据件 gb18030-reverse-table.json 由本脚本再生
//   node 09_工程脚本/gb18030-reverse-table.js --write
// 等价性判据（总单 §B1-2）：新旧表对全仓 .pas 扫描结果一致——见
//   CodeReview/20260925-AUDIT-乙-B1-证据/02-GB18030反表三处合一-evidence.md
//
// 为什么是 gb18030 而非 gbk（沿用 mojibake-core 实测结论）：encode('gbk') 对本仓头号样本
// （含 U+E6E6 GB18030 PUA 区）直接抛异常 ⇒ 漏检；gb18030 解码器对非法双字节给 U+FFFD，
// 占位解码不得入表（否则表外字符会被「编」回去造出假可逆）。
// 编码面参数 encoding='gbk' 仅供 encoding-gate G6 保持其历史判据（gbk 与 gb18030 两字节面
// 存在 ~200 键差异，见等价校验证据），不得新增第三种参数。
'use strict';

const CACHES = new Map();

/**
 * 构建 Unicode 字符 → 双字节 [b0,b1] 反表（首映射胜出）。
 * @param {string} encoding 'gb18030'（默认/权威）或 'gbk'（仅 encoding-gate G6 历史判据）
 * @returns {Map<string,[number,number]>|null} null = 本机无 ICU 解码支持，调用方须 fail-closed
 */
function buildReverseTable(encoding) {
  const key = encoding || 'gb18030';
  if (CACHES.has(key)) return CACHES.get(key);
  let dec;
  try { dec = new TextDecoder(key); } catch (e) { return null; }
  const table = new Map();
  for (let b0 = 0x81; b0 <= 0xFE; b0++) {
    for (let b1 = 0x40; b1 <= 0xFE; b1++) {
      if (b1 === 0x7F) continue;
      const s = dec.decode(Uint8Array.of(b0, b1));
      if (s === '�') continue; // 非法双字节的占位解码不入表
      if (s.length === 1 && !table.has(s)) table.set(s, [b0, b1]);
    }
  }
  CACHES.set(key, table);
  return table;
}

/** 权威反表（gb18030）。null = 无 ICU，调用方 fail-closed。 */
function gbkReverseTable() { return buildReverseTable('gb18030'); }

if (require.main === module) {
  if (process.argv[2] !== '--write') {
    console.error('用法: node gb18030-reverse-table.js --write  （再生 gb18030-reverse-table.json）');
    process.exit(2);
  }
  const fs = require('fs');
  const path = require('path');
  const table = gbkReverseTable();
  if (!table) { console.error('本机无 GB18030 解码支持（缺 ICU），无法再生数据表。'); process.exit(3); }
  const out = {};
  for (const [ch, pair] of table) out[ch] = [Buffer.from(pair).toString('hex')];
  for (let b = 0; b < 0x80; b++) out[String.fromCharCode(b)] = [b.toString(16).padStart(2, '0')]; // ASCII 面，与数据件历史格式一致
  const file = path.join(__dirname, 'gb18030-reverse-table.json');
  fs.writeFileSync(file, JSON.stringify(out));
  console.log(`written ${file} entries=${Object.keys(out).length}`);
}

module.exports = { buildReverseTable, gbkReverseTable };
