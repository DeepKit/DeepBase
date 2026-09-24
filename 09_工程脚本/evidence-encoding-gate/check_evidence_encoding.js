// DeepBase 审计证据文件编码门禁（WO-20260920-AUDIT-乙-R5 N3；H18 的机器化落地）
// 背景：Delphi/PowerShell 的 `>` 重定向默认写 UTF-16LE，审计证据（控制台 log、NUnit
// XML、扫描清单）一旦被这样落盘就会带 NUL 字节，git 判为二进制后 -text/EOL 立法全部
// 失效，证据不可读也不可 diff（乙R4 L3/L9 的实证缺陷）。本门禁把 H18 变成 CI 阻断项。
// 规则：
//  E1 任何证据文件禁止含 NUL 字节（UTF-16/32 与二进制特征）；违规时报文件名、NUL 计数与首偏移。
//     存量债务按基线 nulStock 逐文件封顶（只减不增），条目由独占人按 H18 重落归零后删除。
//  E2 硬规则（不可豁免）：E1 通过后必须是合法 UTF-8（拦截 GBK/ANSI 原始字节入库）。
//  E3 硬规则（内容级·丙-C）：合法 UTF-8 还远远不够——双重编码乱码（中文原文的 UTF-8 字节被按
//     GBK 误读成另一串汉字，再以 UTF-8 正常入库）本身就是合法 UTF-8、无 NUL、无 U+FFFD，
//     E1/E2 恒绿而内容是垃圾。证据失真比源码失真更危险：源码乱码编译期显形，证据乱码任何地方
//     都不显形。判据与存量口径见下方 E3 段（WO-20260924-AUDIT-乙-D8 §1.1）。
// 扫描口径：默认只扫 git 已跟踪的证据文件（CI checkout 内即全量；本地 gitignored 的临时
//     log 不参与，避免把未入库的本地产物当成仓库违规）；--all-worktree 改走工作树枚举。
//     两种口径共用同一排除规则：路径任一成分命中共享 SKIP 目录集（gate-skip.js）即排除，
//     扩展名命中二进制清单（BINARY_EXT）即排除，其余一律纳入 —— 证据门禁的职责是「CodeReview/
//     下已入库的证据文件不得是 UTF-16LE/GBK 落盘」，与扩展名无关，所以白名单反向做成排除集。
// 用法: node check_evidence_encoding.js [--root <dir>] [--baseline <file>] [--all-worktree] [--list-files] [--list-mojibake]
// 退出码：0 通过；1 违规；2 自身执行失败（基线不可信/枚举失败）；3 扫描自身失败（扫到 0 个证据文件 / 本机无 GB18030 解码）——fail-closed，绝不放行。
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { gateSkipSet } = require('../gate-skip');
const { loadGateBaseline } = require('../gate-baseline');
const { parseGateArgs } = require('../gate-args');

// 参数一律走共享解析器（乙 D7 §一-3 同族口径）：本门旧用 --repo，与其余四道门的 --root 不同名，
// 且私有 arg() 会把 --REPO / 未知参数静默回落到默认根——「校验接受的取值侧不认」型假绿的入口。
const OPTS = parseGateArgs(process.argv.slice(2), {
  label: '证据编码',
  root: path.join(__dirname, '../..'),
  baseline: path.join(__dirname, 'evidence_encoding_baseline.json'),
  extra: ['all-worktree', 'list-files', 'list-mojibake'],
});
const REPO = OPTS.root;
const BASELINE_P = OPTS.baseline;
const ALL_WORKTREE = OPTS.flags.has('all-worktree');
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

// ── E3：双重编码乱码（丙-C）──────────────────────────────────────────────────
// 机理：中文原文的 UTF-8 字节（每字 3 字节）被按 GBK 逐对误读成另一串汉字（每字 2 字节），
// 再以 UTF-8 正常入库 ⇒「日志导出」变「鏃ュ織瀵煎嚭」。文件合法 UTF-8、无 NUL，E1/E2 零感知。
// 判据（可逆性）：整行能编回 GB18030 字节、且该字节流按 UTF-8 解出的多是真汉字 ⇒ 这行本就是乱码。
//   ① 行内含中日韩表意文字；
//   ② 逐字符可查 GB18030 反表（含 U+E6E6 等 GB18030 PUA 区；乙 D8 §1.1 实测：Python 的
//      encode('gbk') 在头号样本上直接抛 UnicodeEncodeError ⇒ 漏检，故解码侧必须用 gb18030，
//      Node 的反表由 gb18030 双字节面全枚举得到，U+E6E6 确在表内）；
//   ③ 干净还原出的非 ASCII 字符 clean ≥ MIN_RESTORED_UNITS（证据量下界），且替换符占比
//      broken/(clean+broken) ≤ MAX_BROKEN_RATIO；broken 就是还原串里的 U+FFFD 个数；
//   ④ 还原结果与原文不同；
//   ⑤ 还原结果仍以表意文字为主（cleanCjk/clean ≥ MIN_RESTORED_CJK_RATIO）：真双重编码还原后必是中文，
//      还原出拉丁/音标字符（如「前」→「ǰ」）说明只是 2 字节链的巧合，还原出 U+FFFD（「锟斤拷」族）
//      说明该件本身含丙-A 损坏，属另一面。这条是误报面真正的主拦截。
// 阈值不是拍脑袋（工单授权「你自己实测定并写进说明」；一键复算：
// `bash CodeReview/20260924-AUDIT-乙-D8-证据/d8_criterion_rerun.sh`，原始输出同目录
// `D8-阈值标定-良性语料零误报.txt`。标定不另写判据复算——那会变成第二真源——而是把真实中文
// 文档整批塞进一个临时 CodeReview 树，叫门禁自己扫；阈值变体只 sed 常量，逻辑仍是交付件本体）：
//   · MAX_BROKEN_RATIO = 20%，与主控建议一致。基准口径：按标准 UTF-8 解码器的 U+FFFD 个数计
//     （与主控 Python 参考实现 `encode('gb18030').decode('utf-8', errors='replace')` 逐行实测相等：
//     R7-gates-run.txt 第 1/3/5 行 = 3/4/1）。此前按字节计坏会把一个截断序列数成 2~3 个，
//     同一行读出 20.7%，属计数口径差异而非内容差异。
//   · 真命中侧：R7 点名三行门禁自报 替换符 3/26、4/39、1/15 ⇒ 11.5% / 10.3% / 6.7%，全部在 20% 阈内。
//   · 误报侧（负面控制的规模化）：docs/** 与 08_元管理/** 的 259 个 tracked .md、74,941 行真实中文
//     （中英混排、代码块、表格、链接全量入扫，不是抽样）在 ≤15% 与 ≤20% 下命中 0 行；
//     放到 ≤30% 才出第 1 行（一处正文里引用的双编码片段），≤50% 达 22 行 ⇒ 20% 距误报边界尚有整档余量。
//   · MIN_RESTORED_UNITS=4：同一语料上 clean≥2 仍 0 误报（真正拦下良性行的是判据 ⑤），
//     保留 ≥4 作为「不足以定罪的证据量下界」，避免 2~3 字符的巧合单独承载判定。
//   · MIN_RESTORED_CJK_RATIO=0.5：同一语料上提到 0.8 也 0 误报，但真命中行还原出来就是中文本身
//     （见判据 1 输出「→」后的还原串），再上抬就是在赌原文的每个字都可逆，赌不起，故取 0.5。
//   · 占比超标（不可逆损坏）的行不判 E3：那是丙-A/丙-B 面（U+FFFD / 裸损坏字节），本单只登记不判。
const MIN_RESTORED_UNITS = 4;
const MAX_BROKEN_RATIO = 0.20;
const MIN_RESTORED_CJK_RATIO = 0.5;
// 表意文字面：CJK 基本区 + 扩展 A + 兼容表意区（比 .pas 门 G6 的 [一-鿿] 更宽，
// 证据语料里扩展 A 段的双编码产物同样见过）。码位区间只写一次，行级正则与单元级判定都由它派生；
// 用转义而非字面字符，是为了让本门禁自己的源码在被误转码时判据也不会静默漂移。
const IDEOGRAPH_RANGES = [[0x3400, 0x4DBF], [0x4E00, 0x9FFF], [0xF900, 0xFAFF]];
function isIdeographic(cp) {
  return IDEOGRAPH_RANGES.some(([lo, hi]) => cp >= lo && cp <= hi);
}
const CJK_RE = new RegExp('[' + IDEOGRAPH_RANGES.map(([lo, hi]) =>
  '\\u' + lo.toString(16).padStart(4, '0') + '-\\u' + hi.toString(16).padStart(4, '0')).join('') + ']');

let GB_REV = null;
function gbkReverseTable() {
  if (GB_REV) return GB_REV;
  let dec;
  try { dec = new TextDecoder('gb18030'); } catch (e) {
    // 环境无 ICU GB18030 支持 ⇒ 无法判定。fail-closed：EXIT=3，不静默跳过 E3。
    console.error('证据编码门禁失败：本机 Node 无 GB18030 解码支持（缺 ICU），E3 无法评估。已按 fail-closed 拒绝放行。');
    process.exit(3);
  }
  GB_REV = new Map();
  for (let b0 = 0x81; b0 <= 0xFE; b0++) {
    for (let b1 = 0x40; b1 <= 0xFE; b1++) {
      if (b1 === 0x7F) continue;
      const s = dec.decode(Uint8Array.of(b0, b1));
      if (s === '\uFFFD') continue; // 非法双字节的占位解码不能进表（否则表外字符会被「编」回去）
      if (s.length === 1 && !GB_REV.has(s)) GB_REV.set(s, [b0, b1]);
    }
  }
  return GB_REV;
}
// 「替换符」一律以标准 UTF-8 解码器的 U+FFFD 个数为准（= 主控 Python 参考实现
// `line.encode('gb18030').decode('utf-8', errors='replace')` 的计数口径，实测逐行相等）：
// 手写按字节计坏的扫描器会把一个截断序列数成 2~3 个，数字与参考口径不一致，判据复算无法对齐。
function scanRestored(restored) {
  let clean = 0, cleanCjk = 0, broken = 0;
  for (const ch of restored) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) continue;
    if (cp === 0xFFFD) { broken++; continue; }
    clean++;
    if (isIdeographic(cp)) cleanCjk++;
  }
  return { clean, cleanCjk, broken };
}
// 命中时返回 {restored, clean, broken}，否则 null（不是双重编码 / 证据量不足 / 不可逆损坏）
function detectDoubleEncoding(line) {
  if (!CJK_RE.test(line)) return null;
  const rev = gbkReverseTable();
  const bytes = [];
  for (const ch of line) {
    const cp = ch.codePointAt(0);
    if (cp < 0x80) { bytes.push(cp); continue; }
    const pair = rev.get(ch);
    if (!pair) return null; // 表外字符（emoji/扩展 B 区…）⇒ 不可能是 GBK 误读产物
    bytes.push(pair[0], pair[1]);
  }
  const restored = Buffer.from(bytes).toString('utf8');
  if (restored === line) return null;
  const { clean, cleanCjk, broken } = scanRestored(restored);
  const total = clean + broken;
  if (total === 0 || clean < MIN_RESTORED_UNITS) return null;
  if (broken / total > MAX_BROKEN_RATIO) return null;
  if (cleanCjk / clean < MIN_RESTORED_CJK_RATIO) return null;
  return { restored, clean, broken };
}
function oneLine(s) { return s.replace(/\s+/g, ' ').trim().slice(0, 120); }

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

const { nulStock, mojibakeStock } = loadGateBaseline({
  file: BASELINE_P, label: '证据编码',
  keys: { nulStock: 'object', mojibakeStock: 'object' },
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
// 与判据同一次枚举（files 只有一处产出），不存在两套计数漂移。
if (OPTS.flags.has('list-files')) { files.forEach(f => console.log(f)); process.exit(0); }

const violations = [];
const hits = [];                 // E3 全部命中（含存量登记件）：门禁的职责是「看得见」
const perFile = new Map();       // rel → 命中行数
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
  if (nul > 0) { exempted++; continue; } // 存量豁免件按二进制处理，不再评估 E2/E3
  if (!validUtf8(buf)) { violations.push(`E2 证据非合法 UTF-8(GBK/ANSI 原始字节): ${rel}`); continue; }
  // E3：逐行判双重编码。命中一律上报明细（存量件也要能看见才谈得上递减），
  // 但只有「超出存量封顶」或「清单外新文件」才计入违规——门只拦新增（WO-20260924-AUDIT-乙-D8 §1.2）。
  let n = 0;
  const lines = buf.toString('utf8').split('\n');
  for (let i = 0; i < lines.length; i++) {
    const d = detectDoubleEncoding(lines[i]);
    if (!d) continue;
    n++;
    hits.push(`${rel}:${i + 1}: ${oneLine(lines[i])} → ${oneLine(d.restored)}（替换符 ${d.broken}/${d.broken + d.clean}）`);
  }
  if (n > 0) {
    perFile.set(rel, n);
    const mc = rel in mojibakeStock ? mojibakeStock[rel] : 0;
    if (n > mc) {
      violations.push(`E3 双重编码乱码 ${n} 行 > 存量基线 ${mc}（清单外新文件即为新增），本单只报不修，还原归双域分片单 B2/B3/A3: ${rel}`);
    }
  }
}

// 存量清单必须能从门禁自身复算：`--list-mojibake` 打印 rel<TAB>行数，登记/递减基线时逐行对照，
// 不靠人抄（抄错就等于把「只减不增」写坏）。
if (OPTS.flags.has('list-mojibake')) {
  for (const [rel, n] of [...perFile].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))) console.log(`${n}\t${rel}`);
  console.log(`# 扫描 ${files.length} 件 / 命中 ${hits.length} 行 / ${perFile.size} 件`);
  process.exit(0);
}

if (hits.length) {
  console.log(`E3 双重编码命中 ${hits.length} 行 / ${perFile.size} 件（存量登记 ${Object.keys(mojibakeStock).length} 件封顶，逐条 路径:行号: 原文 → 还原后；括号内「替换符 坏/总」= 还原串里的 U+FFFD 数 / 还原出的非 ASCII 字符总数，占比即 坏÷总）:`);
  hits.forEach(h => console.log('  ' + h));
}

if (violations.length) {
  console.error(`证据编码门禁失败：扫描 ${files.length} 个 ${SUBDIR} 证据文件，E3 命中 ${hits.length} 行，违规 ${violations.length} 项:`);
  violations.forEach(v => console.error('  ' + v));
  process.exit(1);
}
console.log(`证据编码门禁通过：扫描 ${files.length} 个 ${SUBDIR} 证据文件，NUL 违规 0（存量基线豁免 ${Object.keys(nulStock).length} 项 / 本次命中 ${exempted} 项），全部为合法 UTF-8；E3 命中 ${hits.length} 行，均在存量清单 ${Object.keys(mojibakeStock).length} 件的封顶内`);
