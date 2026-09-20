// DeepBase 审计证据文件编码门禁（WO-20260920-AUDIT-乙-R5 N3；H18 的机器化落地）
// 背景：Delphi/PowerShell 的 `>` 重定向默认写 UTF-16LE，审计证据（控制台 log、NUnit
// XML、扫描清单）一旦被这样落盘就会带 NUL 字节，git 判为二进制后 -text/EOL 立法全部
// 失效，证据不可读也不可 diff（乙R4 L3/L9 的实证缺陷）。本门禁把 H18 变成 CI 阻断项。
// 规则：
//  E1 任何证据文件禁止含 NUL 字节（UTF-16/32 与二进制特征）；违规时报文件名、NUL 计数与首偏移。
//     存量债务按基线 nulStock 逐文件封顶（只减不增），条目由独占人按 H18 重落归零后删除。
//  E2 硬规则（不可豁免）：E1 通过后必须是合法 UTF-8（拦截 GBK/ANSI 原始字节入库）。
// 扫描口径：默认只扫 git 已跟踪的证据文件（CI checkout 内即全量；本地 gitignored 的临时
//     log 不参与，避免把未入库的本地产物当成仓库违规）；--all-worktree 改走工作树枚举。
// 用法: node check_evidence_encoding.js [--repo <dir>] [--baseline <file>] [--all-worktree]
// 退出码：0 通过；1 违规；2 自身执行失败。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}
const REPO = path.resolve(arg('repo', path.join(__dirname, '../..')));
const BASELINE_P = arg('baseline', path.join(__dirname, 'evidence_encoding_baseline.json'));
const ALL_WORKTREE = process.argv.includes('--all-worktree');
const SUBDIR = 'CodeReview';
const EXT = /\.(txt|log|csv|xml)$/i;
const SKIP_DIRS = new Set(['.git', '__history', 'node_modules', '.tmp', '.superpowers', '.workbuddy', 'TestResults']);

function countNul(buf) {
  let n = 0;
  for (const b of buf) if (b === 0x00) n++;
  return n;
}
function firstNul(buf) {
  for (let i = 0; i < buf.length; i++) if (buf[i] === 0x00) return i;
  return -1;
}
function validUtf8(buf) {
  try { new TextDecoder('utf-8', { fatal: true }).decode(buf); return true; } catch (e) { return false; }
}

function trackedFiles() {
  const out = execFileSync('git', ['-C', REPO, '-c', 'core.quotepath=false', 'ls-files', '-z', '--',
    SUBDIR + '/**/*.txt', SUBDIR + '/**/*.log', SUBDIR + '/**/*.csv', SUBDIR + '/**/*.xml'],
    { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 });
  return out.toString('utf8').split('\0').filter(Boolean);
}

function walkFiles(dir, acc) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return acc; }
  for (const e of ents) {
    if (SKIP_DIRS.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walkFiles(p, acc);
    else if (e.isFile() && EXT.test(e.name)) acc.push(path.relative(REPO, p).replace(/\\/g, '/'));
  }
  return acc;
}

let baseline = { nulStock: {} };
try {
  baseline = JSON.parse(fs.readFileSync(BASELINE_P, 'utf8'));
} catch (e) {
  if (fs.existsSync(BASELINE_P)) {
    console.error(`证据编码门禁基线文件不可读或非法 JSON: ${BASELINE_P} (${e.message})`);
    process.exit(2);
  }
}
const nulStock = baseline.nulStock || {};

let files;
try {
  files = ALL_WORKTREE ? walkFiles(path.join(REPO, SUBDIR), []) : trackedFiles();
} catch (e) {
  console.error('证据编码门禁无法枚举文件: ' + e.message);
  process.exit(2);
}

const violations = [];
let exempted = 0;
for (const rel of files) {
  const abs = path.join(REPO, rel);
  let buf;
  try { buf = fs.readFileSync(abs); } catch (e) { violations.push(`E0 读取失败: ${rel} (${e.message})`); continue; }
  const nul = countNul(buf);
  const cap = rel in nulStock ? nulStock[rel] : 0;
  if (nul > cap) {
    violations.push(`E1 证据含 NUL 字节(NUL=${nul}, 首偏移=${firstNul(buf)}, 存量基线=${cap})，疑为 UTF-16LE/二进制落盘，须按 H18 以 UTF-8 重落: ${rel}`);
    continue;
  }
  if (nul > 0) { exempted++; continue; } // 存量豁免件按二进制处理，不再评估 E2
  if (!validUtf8(buf)) violations.push(`E2 证据非合法 UTF-8(GBK/ANSI 原始字节): ${rel}`);
}

if (violations.length) {
  console.error(`证据编码门禁失败：扫描 ${files.length} 个 ${SUBDIR} 证据文件，违规 ${violations.length} 项:`);
  violations.forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log(`证据编码门禁通过：扫描 ${files.length} 个 ${SUBDIR} 证据文件，NUL 违规 0（存量基线豁免 ${Object.keys(nulStock).length} 项 / 本次命中 ${exempted} 项），全部为合法 UTF-8`);
