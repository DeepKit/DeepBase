// 乙-B1 全量编码扫描：口径 = scan_fffd.js（同 SKIP 目录集），扩展逐行分类
// 输出: 1) JSON 明细 2) 终端汇总。用法: node scan_encoding_detail.js [out.json] [--root <dir>]
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const _ri = process.argv.indexOf('--root');
const ROOT = _ri > 0 && process.argv[_ri + 1] ? path.resolve(process.argv[_ri + 1]) : 'D:/_Progs/02Business/DeepBase';
const SKIP = new Set(['.git', '.claude', '__history', 'BuildOutput', 'DCUOutput', 'bin', 'dcu', 'node_modules', '.worktrees', '.tmp']);

function walk(dir, out) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const e of ents) {
    if (e.name === '.claude') { if (!/^\.[^/]*worktree/i.test(e.name)) { if (SKIP.has(e.name)) continue; } }
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.isFile() && /\.pas$/i.test(e.name)) out.push(p);
  }
  return out;
}

function isValidUtf8(buf) {
  try { new TextDecoder('utf-8', { fatal: true }).decode(buf); return true; } catch (e) { return false; }
}

// 逐行分类 FFFD 位置：comment(// 或 {$} 块注释内) / string(单引号字面量内) / code(标识符等)
function classify(buf) {
  const txt = buf.toString('utf8');
  const lines = txt.split('\n');
  let inBlock = false;
  let lit = 0, com = 0, code = 0;
  const hitLines = [];
  for (let raw of lines) {
    let i = 0; let inStr = false; let nLit = 0, nCom = 0, nCode = 0;
    const blockAt = inBlock;
    while (i < raw.length) {
      const c = raw[i];
      if (inBlock) {
        if (c === '\uFFFD') nCom++;
        if (c === '}') { inBlock = false; if (raw[i + 1] === ')') i++; }
        i++; continue;
      }
      if (inStr) {
        if (c === "'") { if (raw[i + 1] === "'") { i += 2; continue; } inStr = false; i++; continue; }
        if (c === '\uFFFD') nLit++;
        i++; continue;
      }
      if (c === '/' && raw[i + 1] === '/') { // 行注释直到行尾
        for (let j = i; j < raw.length; j++) if (raw[j] === '\uFFFD') nCom++;
        break;
      }
      if (c === '{') { inBlock = true; i++; continue; }
      if (c === '(' && raw[i + 1] === '*') { inBlock = true; i += 2; continue; }
      if (c === "'") { inStr = true; i++; continue; }
      if (c === '\uFFFD') nCode++;
      i++;
    }
    if (nLit + nCom + nCode > 0) {
      lit += nLit; com += nCom; code += nCode;
      hitLines.push({ nLit, nCom, nCode });
    }
  }
  return { lit, com, code, hitLines, tailBlockOpen: inBlock };
}

const files = walk(ROOT, []);
const out = { total: files.length, files: [] };
let nFffd = 0, nNoBomCjk = 0, nBomCjk = 0, nInvalidUtf8 = 0;
for (const f of files) {
  const buf = fs.readFileSync(f);
  const bom = buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF;
  const valid = isValidUtf8(buf);
  const txt = buf.toString('utf8');
  const cjk = (txt.match(/[\u4e00-\u9fff]/g) || []).length;
  const ff = (txt.match(/\uFFFD/g) || []).length;
  if (ff > 0) nFffd++;
  if (cjk > 0 && !bom) nNoBomCjk++;
  if (cjk > 0 && bom) nBomCjk++;
  if (!valid) nInvalidUtf8++;
  if (ff > 0 || !valid) {
    const cl = classify(buf);
    out.files.push({ f: path.relative(ROOT, f).replace(/\\/g, '/'), bom, validUtf8: valid, cjk, fffd: ff, litFFFD: cl.lit, commentFFFD: cl.com, codeFFFD: cl.code });
  }
}
out.summary = { fffdFiles: nFffd, cjkNoBom: nNoBomCjk, cjkWithBom: nBomCjk, invalidUtf8Files: nInvalidUtf8 };
const json = JSON.stringify(out, null, 1);
if (process.argv[2]) fs.writeFileSync(process.argv[2], json);
else console.log(json);
console.error(`total=${out.total} fffd=${nFffd} cjkNoBom=${nNoBomCjk} cjkBom=${nBomCjk} invalidUtf8=${nInvalidUtf8}`);
