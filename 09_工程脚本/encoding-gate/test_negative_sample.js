// 编码门禁负向样本测试：向临时副本注入 U+FFFD / 含非 ASCII 但缺 BOM / 写入 GBK 字节 / UTF-16+NUL / 孤立 CR，断言门禁逐项报错；
// 并以「纯 ASCII 且缺 BOM」样本断言 G3 放行（乙R6-N1 口径收窄的正向对照）。
// 用法: node test_negative_sample.js   （退出码 0=门禁按预期拦截）
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const HERE = __dirname;
const dec = new TextDecoder('gbk');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pasenc-'));
fs.mkdirSync(path.join(tmp, 'src'), { recursive: true });
// 样本 1：合法带 BOM UTF-8（应通过）
fs.writeFileSync(path.join(tmp, 'src', 'Ok.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from("unit Ok;\n// 正常中文注释\ninterface\nimplementation\nend.\n", 'utf8')]));
// 样本 2：注入 U+FFFD（G1 应报错）；BOM 之后正文中出现 EF BF BD 序列，解码即为 U+FFFD
fs.writeFileSync(path.join(tmp, 'src', 'Injected.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from("unit Injected;\n// 注入\uFFFD损坏\ninterface\nimplementation\nend.\n", 'utf8')]));
// 样本 3：含非 ASCII 字节且缺 BOM（G3 应报错）
fs.writeFileSync(path.join(tmp, 'src', 'NoBom.pas'), Buffer.from("unit NoBom;\n// 中文注释须配BOM\ninterface\nimplementation\nend.\n", 'utf8'));
// 样本 4：GBK 原始字节（G2 应报错）
const gbkText = new TextEncoder().encode('unit Gbk;');
const gbkBytes = Buffer.from([0xB5, 0xA5, 0xCE, 0xBB]); // "单位" GBK
fs.writeFileSync(path.join(tmp, 'src', 'Gbk.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), gbkText, gbkBytes, Buffer.from('\ninterface\nimplementation\nend.\n', 'utf8')]));
// 样本 5：UTF-8 BOM + 正文含 NUL 字节（G2 合法、G1 无、仅 G4 能拦——纯 ASCII UTF-16 场景的等价形态）
fs.writeFileSync(path.join(tmp, 'src', 'NulIn.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from('unit NulIn;\n', 'utf8'), Buffer.from([0x00]), Buffer.from('interface\nimplementation\nend.\n', 'utf8')]));
// 样本 6：UTF-16LE BOM 文件（FF FE；G4 应报错）
fs.writeFileSync(path.join(tmp, 'src', 'Utf16.pas'), Buffer.concat([Buffer.from([0xFF, 0xFE]), Buffer.from('unit Utf16;\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf16le')]));
// 样本 7：行尾多一个孤立 CR（\r\r\n；G5 应报错）
fs.writeFileSync(path.join(tmp, 'src', 'LoneCr.pas'), Buffer.concat([Buffer.from([0xEF, 0xBB, 0xBF]), Buffer.from('unit LoneCr;\r\r\ninterface\r\nimplementation\r\nend.\r\n', 'utf8')]));
// 样本 8：纯 ASCII 且无 BOM（乙R6-N1 新口径应放行——dcc64 按 ANSI 代码页解析结果与 UTF-8 逐字节相同，BOM 无收益）
fs.writeFileSync(path.join(tmp, 'src', 'AsciiNoBom.pas'), Buffer.from('unit AsciiNoBom;\ninterface\nimplementation\nend.\n', 'utf8'));
// WO-20260922-AUDIT-乙-P2 §3.1 验收判据3：G6 专属负样本「修前假绿 / 修后必红」双向留证。
// 样本 9 只含双重编码乱码，且刻意避开 G1(U+FFFD)/G2(非法UTF-8)/G3(缺BOM)/G4(NUL)/G5(孤立CR)：
//   · 带 UTF-8 BOM ⇒ 不触发 G3
//   · 合法 UTF-8、无 U+FFFD、无 NUL、LF 行尾 ⇒ 不触发 G1/G2/G4/G5
// ⇒ 加 G6 之前该文件必被放行（假绿），加 G6 之后必红。
// 乱码文案由 GBK 误读真实产生（非手写）：
// 机制固定为「原文.utf8 的字节被按 GBK 解码」⇒ 得到乱码字符串，fixture 中以正常 UTF-8 存放该乱码串。
// 注：此处不能用 Buffer.toString('gbk')（Node 不支持 GBK 编码；TextDecoder 只有 decode）。
// 而 TextDecoder('gbk') 实际是 GB18030 超集，会把「日志导出」编成 c8d5d6be…（另一种损坏），
// 会得到与真实乱码不同的串。故 fixture 用真实 GBK 码位的字节映射手写，
// 与主控取证样本「鏃ュ織瀵煎嚭」（= 日志导出）逐字符一致。
const gbz = (s) => {
  // U+65E5 U+5FD7 U+5BFC U+51FA 的 UTF-8 字节: E6 97 A5 | E5 BF 97 | E5 AF BC | E5 87 BA
  // 按 GBK 双字节切分: (E6 97)(A5 E5)(BF 97)(E5 AF)(BC E5)(87 BA) ⇒ 每个 pair 解码为一个乱码字。
  // 该映射对 ASCII 不受影响，故 fixture 只用于注入这两段已知中文。
  const b = Buffer.from(s, 'utf8');
  const out = [];
  for (let i = 0; i < b.length; ) {
    const hi = b[i], lo = b[i + 1];
    out.push(dec.decode(Uint8Array.of(hi, lo)));
    i += 2;
  }
  return out.join('');
};
fs.writeFileSync(path.join(tmp, 'src', 'MojibakeOnly.pas'), Buffer.concat([
  Buffer.from([0xEF, 0xBB, 0xBF]),
  Buffer.from('unit MojibakeOnly;\n// 双重编码乱码专属样本：仅 G6 可识别\ninterface\nimplementation\nend.\n', 'utf8'),
  Buffer.from('const S1 = \'' + gbz('日志导出') + '\';\n', 'utf8'),
  Buffer.from('const S2 = \'' + gbz('打开文件') + '\';\n', 'utf8')
]));

const emptyBaseline = path.join(tmp, 'baseline.json');
fs.writeFileSync(emptyBaseline, JSON.stringify({ fffd: {}, loneCr: {}, bomExceptions: [] }));
let failed = false;
try {
  execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), '--root', tmp, '--baseline', emptyBaseline], { stdio: 'pipe' });
  console.error('负向样本测试失败：门禁未拦截任何违规'); failed = true;
} catch (e) {
  const out = (e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8');
  console.log('门禁输出（预期包含 6 类违规）:\n' + out);
  for (const tag of ['G1', 'G2', 'G3', 'G4', 'G5', 'G6']) {
    if (!out.includes(tag)) { console.error('缺少 ' + tag + ' 报错'); failed = true; }
  }
  // G4 必须由 NulIn.pas 证明（纯 ASCII+NUL 能通过 G2，只有 G4 拦得住）
  if (!/G4 .*NulIn\.pas/.test(out)) { console.error('G4 未拦截 NulIn.pas（NUL 规则失效）'); failed = true; }
  // G3 口径（乙R6-N1）：含非 ASCII + 无 BOM 必须被拦
  if (!/G3 .*NoBom\.pas/.test(out)) { console.error('G3 未拦截 NoBom.pas（含非 ASCII 且缺 BOM 应报错）'); failed = true; }
  // G3 口径（乙R6-N1）：纯 ASCII + 无 BOM 必须放行，不得出现在任何违规行
  if (out.includes('AsciiNoBom.pas')) { console.error('G3 误报纯 ASCII 件 AsciiNoBom.pas（判据未收窄为「含非 ASCII」）'); failed = true; }
}
// WO-20260922-AUDIT-乙-P2 §3.1 验收判据3：G6 负样本「修前假绿 / 修后必红」双向留证。
// 把 MojibakeOnly.pas 单独隔离成 root：修 G6 之前它必被放行（假绿），修 G6 之后必红。
{
  const g6Root = fs.mkdtempSync(path.join(os.tmpdir(), 'pasenc-g6-'));
  fs.mkdirSync(path.join(g6Root, 'src'), { recursive: true });
  const iso = path.join(tmp, 'src', 'MojibakeOnly.pas');
  if (!fs.existsSync(iso)) {
    console.error('G6 负样本缺失：MojibakeOnly.pas 未生成，无法双向留证'); failed = true;
  } else {
    fs.copyFileSync(iso, path.join(g6Root, 'src', 'MojibakeOnly.pas'));
    const emptyBase = path.join(g6Root, 'empty_baseline.json');
    fs.writeFileSync(emptyBase, JSON.stringify({ fffd: {}, loneCr: {}, bomExceptions: [], mojibake: {} }));
    // (a) 修后必红
    let red = false, out = '';
    try {
      execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), '--root', g6Root, '--baseline', emptyBase], { stdio: 'pipe' });
    } catch (e) {
      red = true;
      out = ((e.stderr || Buffer.alloc(0)).toString('utf8') + (e.stdout || Buffer.alloc(0)).toString('utf8'));
    }
    if (!red) { console.error('G6 负样本失败：仅含双重编码乱码的 MojibakeOnly.pas 被放行'); failed = true; }
    else if (!/G6 双重编码乱码 .*MojibakeOnly\.pas/.test(out)) { console.error('G6 负样本失败：拦截了但不是 G6 规则'); failed = true; }
    else if (!/日志导出/.test(out)) { console.error('G6 负样本失败：未打印还原文本，取证链断裂'); failed = true; }
    else console.log('G6 负样本通过：MojibakeOnly.pas 被 G6 拦下并还原出「日志导出」');

    // (b) 修前假绿：拖空 G6 判据的同源拷贝须放行 — 证明旧门禁确实是绿的
    // 副本必须能 require 到真实的 gate-args.js：门禁源码里是 require('../gate-args')，
    // 按脚本自身位置解析——副本落在 g6Root（tmp）内时该路径必然 MODULE_NOT_FOUND，
    // 于是「按预期放行」被误读成引擎崩溃。故把副本里的相对 require 改写为绝对路径，
    // 副本即可落在任何位置（本单 §七 把参数解析外置成共享模块后新增的约束）。
    const noG6 = path.join(g6Root, 'check_pas_encoding_nog6.js');
    const src = fs.readFileSync(path.join(HERE, 'check_pas_encoding.js'), 'utf8');
    const gateArgsAbs = path.resolve(HERE, '../gate-args.js');
    if (!src.includes('function detectMojibake')) {
      console.error('G6 负样本异常：门禁源码中找不到 detectMojibake，无法构造「修前」对照'); failed = true;
    } else if (!fs.existsSync(gateArgsAbs)) {
      console.error('G6 负样本异常：共享参数模块缺失（' + gateArgsAbs + '），无法构造「修前」对照'); failed = true;
    } else {
      // 两处改写互不相干：G6 判据恒为 null ⇒ 等价于「加 G6 之前」的门禁；
      // 相对 require → 绝对路径 ⇒ 副本可跨目录执行。
      const patched = src
        .replace("require('../gate-args')", 'require(' + JSON.stringify(gateArgsAbs) + ')')
        .replace('function detectMojibake(line) {', 'function detectMojibake(line) {\n  return null; // 「修前」对照：G6 判据失效');
      if (patched === src) {
        console.error('G6 负样本异常：源码两处改写均未命中，「修前」对照与现行门禁无异'); failed = true;
      } else {
        fs.writeFileSync(noG6, patched);
        let green = false;
        try {
          execFileSync(process.execPath, [noG6, '--root', g6Root, '--baseline', emptyBase], { stdio: 'pipe' });
          green = true;
        } catch (e) { /* 仍红 */ }
        if (!green) { console.error('G6 双向留证失败：「修前」对照仍报红，无法证明该样本在旧门禁下是假绿'); failed = true; }
        else console.log('G6 双向留证通过：「修前」对照放行同一文件 ⇒ 确证旧门禁假绿');
      }
    }
    fs.rmSync(g6Root, { recursive: true, force: true });
  }
}
// WO-20260921-AUDIT-乙-P1 §〇 第 4 条：负向样本①——--root 指向不存在的目录必须红（fail-closed）。
{
  const missingRoot = path.join(os.tmpdir(), 'pasenc-missing-' + Date.now());
  while (fs.existsSync(missingRoot)) fs.rmSync(missingRoot, { recursive: true, force: true });
  let red = false;
  try {
    execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), '--root', missingRoot], { stdio: 'pipe' });
  } catch (e) { red = true; }
  if (!red) { console.error('负向样本①失败：--root 指向不存在目录时门禁仍放行（fail-open 未修复）'); failed = true; }
  else console.log('负向样本①通过：不存在目录被 fail-closed 拦截');
}
// WO-20260921-AUDIT-乙-P1 §〇 第 4 条：负向样本②——空目录（存在但无 .pas）必须红（空扫描不是通过）。
{
  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'pasenc-empty-'));
  let red = false;
  try {
    execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), '--root', emptyRoot], { stdio: 'pipe' });
  } catch (e) { red = true; }
  fs.rmSync(emptyRoot, { recursive: true, force: true });
  if (!red) { console.error('负向样本②失败：空目录（0 个 .pas）门禁仍报通过（真空绿未修复）'); failed = true; }
  else console.log('负向样本②通过：空扫描被 fail-closed 拦截');
}
// 决定性判据 §7.3#2：--root 指向存在目录时必须真的按该目录扫描，不得回落默认根。
// 用「扫描计数 ≠ 全仓量级」反证。tmp 内注入的是违规样本，门禁会走违规分支而非打印计数，
// 故改用一份干净的只读子目录取计数；全仓 .pas 量级 975，干净子目录仅 1 个，差三个数量级。
{
  const clean = fs.mkdtempSync(path.join(os.tmpdir(), 'pasenc-clean-'));
  fs.mkdirSync(path.join(clean, 'src'), { recursive: true });
  fs.writeFileSync(path.join(clean, 'src', 'Ok.pas'), Buffer.from('unit Ok;\ninterface\nimplementation\nend.\n', 'utf8'));
  let out = '';
  try {
    out = execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), '--root', clean], { stdio: 'pipe' }).toString('utf8');
  } catch (e) { out = (e.stdout || Buffer.alloc(0)).toString('utf8'); }
  fs.rmSync(clean, { recursive: true, force: true });
  const m = out.match(/(\d+)\s*个\s*\.pas/);
  const scanned = m ? Number(m[1]) : -1;
  if (scanned <= 0 || scanned > 100) {
    console.error('决定性判据2失败：--root <存在目录> 扫描计数异常（' + scanned + '），疑似回落默认根');
    failed = true;
  } else {
    console.log('决定性判据2通过：--root <存在目录> 真按该目录扫描（' + scanned + ' 个 .pas，非全仓 975 量级）');
  }
}
// WO-20260922-AUDIT-乙-P2 §七：5 类参数 fail-open 负样本（每类必须 EXIT=3，不是 0）。
// 旧裂根因：校验侧把 --ROOT 小写归一后当已知参数放行，取值侧 arg() 大小写敏感取空，
// 于是静默回落默认 root 扫全仓 975 个 .pas 报 EXIT=0——「我按指定 root 扫过了」的假象。
// 取值侧现已与校验侧共用 09_工程脚本/gate-args.js 同一份归一结果，该裂缝在实现层不存在。
const ARG_CASES = [
  ['未知参数',     ['--rot', '.']],
  ['已知参数缺值', ['--root']],
  ['裸位置参数',   ['stray']],
  ['大小写不符',   ['--ROOT', '/nonexistent']],
  ['值形似参数',   ['--root', '--root']],
];
for (const [label, argv] of ARG_CASES) {
  let code = null;
  try {
    execFileSync(process.execPath, [path.join(HERE, 'check_pas_encoding.js'), ...argv], { stdio: 'pipe' });
  } catch (e) { code = e.status; }
  if (code !== 3) {
    console.error('参数负样本失败(' + label + ')：期望 EXIT=3，实际 ' + code);
    failed = true;
  } else {
    console.log('参数负样本通过(' + label + ')：[' + argv.join(' ') + '] => EXIT=3');
  }
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? 'NEGATIVE-TEST: FAIL' : 'NEGATIVE-TEST: PASS');
process.exit(failed ? 1 : 0);
