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
//     两种口径共用同一排除规则：路径任一成分命中共享 SKIP 目录集（gate-skip.js）即排除，
//     扩展名命中二进制清单（BINARY_EXT）即排除，其余一律纳入 —— 证据门禁的职责是「CodeReview/
//     下已入库的证据文件不得是 UTF-16LE/GBK 落盘」，与扩展名无关，所以白名单反向做成排除集。
// 用法: node check_evidence_encoding.js [--repo <dir>] [--baseline <file>] [--all-worktree] [--list-files]
// 退出码：0 通过；1 违规；2 自身执行失败（基线不可信/枚举失败）；3 扫描自身失败（扫到 0 个证据文件）——fail-closed，绝不放行。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt;
}
const REPO = path.resolve(arg('repo', path.join(__dirname, '../..')));
const BASELINE_P = arg('baseline', path.join(__dirname, 'evidence_encoding_baseline.json'));
const ALL_WORKTREE = process.argv.includes('--all-worktree');
const SUBDIR = 'CodeReview';
const SKIP_DIRS = gateSkipSet();
// E1（NUL 计数）与 E2（严格 UTF-8 解码）只对文本证据有意义；二进制容器（图片/压缩包/编译
// 产物/office 文档）本身就是合法的非 UTF-8 字节流，纳入即必然误报，故按扩展名排除。
// 清单外的扩展名默认纳入：新增证据类型不必改本门禁（WO-20260923-AUDIT-乙-D5 §一-1）。
const BINARY_EXT = new Set(['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.webp', '.tif', '.tiff',
  '.pdf', '.zip', '.gz', '.7z', '.rar', '.tar', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
  '.exe', '.dll', '.bpl', '.dcu', '.obj', '.lib', '.o', '.a', '.so', '.res', '.map', '.bin', '.dat',
  '.mp3', '.mp4', '.wav', '.avi', '.mov', '.gifv', '.ttf', '.otf', '.woff', '.woff2', '.pkl', '.db', '.sqlite']);

function isBinaryName(name) {
  return BINARY_EXT.has(path.extname(name).toLowerCase());
}
// 已跟踪口径下 git 返回的是仓库相对路径，需按目录成分判断是否落在 SKIP 目录内。
function inSkipDir(rel) {
  return rel.split('/').slice(0, -1).some(seg => SKIP_DIRS.has(seg));
}

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
  const out = execFileSync('git', ['-C', REPO, '-c', 'core.quotepath=false', 'ls-files', '-z', '--', SUBDIR],
    { encoding: 'buffer', maxBuffer: 64 * 1024 * 1024 });
  return out.toString('utf8').split('\0').filter(Boolean)
    .filter(rel => !inSkipDir(rel) && !isBinaryName(path.posix.basename(rel)));
}

function walkFiles(dir, acc) {
  let ents;
  // fail-closed：同 WO-20260921-AUDIT-乙-P1 §〇。readdir 失败不得静默返回空数组，
  // 否则扫到 0 个证据文件却报「通过」。
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) {
    console.error(`证据编码门禁无法读取目录: ${dir} (${e.message})`);
    process.exit(3);
  }
  for (const e of ents) {
    if (SKIP_DIRS.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walkFiles(p, acc);
    else if (e.isFile() && !isBinaryName(e.name)) acc.push(path.relative(REPO, p).replace(/\\/g, '/'));
  }
  return acc;
}

const { nulStock } = loadGateBaseline({
  file: BASELINE_P, label: '证据编码',
  keys: { nulStock: 'object' },
});

let files;
try {
  files = ALL_WORKTREE ? walkFiles(path.join(REPO, SUBDIR), []) : trackedFiles();
} catch (e) {
  console.error('证据编码门禁无法枚举文件: ' + e.message);
  process.exit(2);
}
// 空扫描即失败：CodeReview/ 下必有 .txt/.log/.xml 证据；扫到 0 个说明 repo 指错、
// git 不可用或 pathspec 口径失效。fail-closed，绝不放行（WO-20260921-AUDIT-乙-P1 §〇）。
if (files.length === 0) {
  console.error(`证据编码门禁失败：扫描 0 个 ${SUBDIR} 证据文件（repo=${REPO}, all-worktree=${ALL_WORKTREE}）。已按 fail-closed 拒绝放行。`);
  process.exit(3);
}

// 取证用：打印本次实际纳入的文件清单后退出。「哪些证据件进了门禁」必须能从门禁自身复算，
// 而不是靠 README 复述一份会漂移的清单（WO-20260923-AUDIT-乙-D5 §一-1）。
if (process.argv.includes('--list-files')) { files.forEach(f => console.log(f)); process.exit(0); }

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
