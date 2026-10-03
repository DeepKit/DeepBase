// 判据6 NC3：门禁阴性对照——证明「乱码修错」会被真门禁抓住（不是 vacuous green）。
//  NC3a: 把 HEAD 的 L6（已还原行）换成一条纯双重编码乱码行（由「日志导出」UTF-8 字节
//        经 GBK 误读程序化构造，与 gate 文档样本同源）→ 预期 encoding-gate G6 红（1 行 > 基线 0）。
//  NC3b: 把 HEAD 的 L6 中一个字替换成 U+FFFD（模拟「补错一个字符」补成替换符）
//        → 预期 encoding-gate G1 红（U+FFFD 1 > 基线 0）。
// 两个探针都在隔离 root 里跑真门禁（--baseline 归零副本，不动真基线）。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '../..');
const TARGET = path.join(REPO, 'Examples/Templates/Common/Template.AutoUpdateBootstrap.pas');
const OUT = path.join(__dirname, '_probe_out');
const ZERO_BASE = path.join(__dirname, '_probe_baseline_zero.json');
const GATE = path.join(REPO, '09_工程脚本/encoding-gate/check_pas_encoding.js');

const buf = fs.readFileSync(TARGET);
const lines = buf.toString('utf8').split('\n');
// L6 = idx 5（1-based 第 6 行）已确认为「      - 后台轮询安装窗口」
console.log('HEAD L6 =', JSON.stringify(lines[5]));
if (!lines[5].includes('后台轮询安装窗口')) { console.error('HEAD L6 与预期不符，中止'); process.exit(3); }

function makeRoot(name, newL6) {
  const root = path.join(OUT, name, 'Examples/Templates/Common');
  fs.mkdirSync(root, { recursive: true });
  const v = lines.slice();
  v[5] = newL6;
  fs.writeFileSync(path.join(root, 'Template.AutoUpdateBootstrap.pas'), Buffer.concat([buf.slice(0, 3), Buffer.from(v.join('\n'), 'utf8')]));
  return path.join(OUT, name);
}

function runGate(label, root) {
  const r = require('child_process').spawnSync(process.execPath, [GATE, '--root', root, '--baseline', ZERO_BASE], { encoding: 'utf8' });
  console.log(`===== ${label} =====`);
  console.log(`GATE_EXIT=${r.status}`);
  console.log((r.stdout || '') + (r.stderr || '').trim());
}

// NC3a：纯乱码行（程序构造，保证可 GBK 可逆）
const pure = new TextDecoder('gbk').decode(Buffer.from('日志导出', 'utf8'));
console.log(`[构造] 纯乱码样本 = ${JSON.stringify(pure)}（= 「日志导出」UTF-8 字节的 GBK 误读）`);
runGate('NC3a 纯乱码行（预期 G6 红 EXIT=1）', makeRoot('NC3a-pure-mojibake', '      - ' + pure));

// NC3b：还原补错一个字符 → U+FFFD（用转义构造，避免字面量转写偏差）
runGate('NC3b L6 一字补成 U+FFFD（预期 G1 红 EXIT=1）', makeRoot('NC3b-fffd', '      - 后台轮询安装窗�?'));
