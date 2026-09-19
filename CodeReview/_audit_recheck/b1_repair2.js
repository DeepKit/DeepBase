// 乙-B1 抢救 v3：对仍有残留的文件做"全史最优干净祖先"尝试（逐个干净 rev 做 R2 三元合并，取残留最少者）。
// 用法: node b1_repair2.js <files.json> [--apply]
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const BOM = Buffer.from([0xEF, 0xBB, 0xBF]);
const NL = String.fromCharCode(10), CR = String.fromCharCode(13);

function git(args) { return execFileSync('git', ['-C', ROOT, ...args], { maxBuffer: 256 * 1024 * 1024 }); }
function gitShow(rev, p) {
  try { return git(['show', `${rev}:${p}`]); }
  catch (e) { return (e.stdout && e.stdout.length) ? e.stdout : null; }
}
function validUtf8(buf) { try { new TextDecoder('utf-8', { fatal: true }).decode(buf); return true; } catch (e) { return false; } }
function gbkDecode(buf) { return new TextDecoder('gb18030').decode(buf); }
function skel(s) { return s.replace(/[\u0080-\uFFFF\r]+/g, '?'); }
function asciiCtx(s) { return s.replace(/[\u0080-\uFFFF]+/g, ''); }
function lines(txt) { return txt.replace(/^\uFEFF/, '').split(NL).map(s => s.endsWith(CR) ? s.slice(0, -1) : s); }
function stripBom(buf) { return buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF ? buf.slice(3) : buf; }
function ffCount(s) { return (s.match(/\uFFFD/g) || []).length; }
function textOf(buf) { return validUtf8(buf) ? stripBom(buf).toString('utf8') : gbkDecode(stripBom(buf)); }

function align(A, B) {
  const n = A.length, m = B.length;
  if ((n + 1) * (m + 1) > 4e7) return null;
  const dp = new Int32Array((n + 1) * (m + 1));
  const at = (i, j) => dp[i * (m + 1) + j];
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--)
    dp[i * (m + 1) + j] = A[i] === B[j] ? at(i + 1, j + 1) + 1 : Math.max(at(i + 1, j), at(i, j + 1));
  const pairs = []; let i = 0, j = 0;
  while (i < n && j < m) {
    if (A[i] === B[j]) { pairs.push([i, j]); i++; j++; }
    else if (at(i + 1, j) >= at(i, j + 1)) i++; else j++;
  }
  return pairs;
}

// 用干净祖先 C 与损坏 base D 合并恢复 W；返回 {text, residual, restored}
function tryMerge(W, C, D) {
  let Cmap;
  if (D) {
    const pairsCD = align(D.map(skel), C.map(skel));
    if (!pairsCD) return null;
    Cmap = D.map(() => null);
    for (const [iD, iC] of pairsCD) Cmap[iD] = C[iC];
  } else { D = C; Cmap = C.slice(); }
  const pairsWD = align(W.map(skel), D.map(skel));
  if (!pairsWD) return null;
  const wMatch = new Map();
  for (const [i, j] of pairsWD) wMatch.set(i, j);
  let restored = 0;
  const out = W.map((w, i) => {
    if (ffCount(w) === 0) return w;
    const j = wMatch.get(i);
    if (j === undefined) return w;
    const cj = Cmap[j];
    if (cj !== null && (D[j] === w || asciiCtx(w) === asciiCtx(D[j]))) { restored++; return cj; }
    return w;
  });
  const text = out.join(NL);
  return { text, residual: ffCount(text), restored };
}

const [,, filesP, applyFlag] = process.argv;
const APPLY = applyFlag === '--apply';
const list = JSON.parse(fs.readFileSync(filesP, 'utf8'));
const out = [];
for (const f of list) {
  const abs = path.join(ROOT, f);
  const buf = fs.readFileSync(abs);
  const wTxtRaw = buf.toString('utf8');
  const W = lines(wTxtRaw);
  const ffBefore = ffCount(wTxtRaw);
  // 全史 rev+path 条目
  const raw = git(['log', '--follow', '--format=C%H', '--name-only', '--', f]).toString('utf8');
  const entries = []; let curRev = null;
  for (const line of raw.split('\n')) {
    const s = line.trim();
    if (!s) continue;
    if (s.startsWith('C') && /^[0-9a-f]{40}$/.test(s.slice(1))) curRev = s.slice(1);
    else if (curRev) entries.push({ rev: curRev, p: s.replace(/\\/g, '/') });
  }
  // 从新到旧找受损边界 D：先扫到第一个 DAMAGED 即当前；对每个干净 rev 尝试
  let best = null;
  const kinds = [];
  for (const e of entries) {
    const b = gitShow(e.rev, e.p);
    if (!b) { kinds.push({ ...e, kind: 'MISS' }); continue; }
    const t = textOf(b);
    const kind = (!validUtf8(b) && ffCount(gbkDecode(stripBom(b))) === 0) ? 'CLEAN_GBK'
      : (ffCount(t) === 0 && validUtf8(b) ? 'CLEAN_UTF8' : 'DAMAGED');
    kinds.push({ ...e, kind, txt: kind !== 'DAMAGED' ? (kind === 'CLEAN_GBK' ? gbkDecode(stripBom(b)) : stripBom(b).toString('utf8')) : t });
  }
  for (let i = 0; i < kinds.length; i++) {
    if (kinds[i].kind === 'MISS') continue;
    if (kinds[i].kind !== 'DAMAGED') {
      const C = lines(kinds[i].txt);
      const D = kinds[i + 1] && kinds[i + 1].kind === 'DAMAGED' ? lines(kinds[i + 1].txt) : null;
      const r = tryMerge(W, C, D);
      if (r && (!best || r.residual < best.residual || (r.residual === best.residual && r.restored > best.restored)))
        best = { ...r, rev: kinds[i].rev, kind: kinds[i].kind, dRev: D ? kinds[i + 1].rev : null };
    }
  }
  const rec = { f, ffBefore, bestRev: best && best.rev, bestKind: best && best.kind, residual: best ? best.residual : ffBefore, restored: best ? best.restored : 0 };
  if (best && best.residual < ffBefore) {
    const crlf = wTxtRaw.includes(CR + NL);
    let body = best.text.split(CR + NL).join(NL); if (crlf) body = body.split(NL).join(CR + NL);
    if (APPLY) fs.writeFileSync(abs, Buffer.concat([BOM, Buffer.from(body, 'utf8')]));
  } else { rec.note = 'NO-IMPROVEMENT'; }
  out.push(rec);
  console.log(JSON.stringify(rec));
}
fs.writeFileSync(path.join(ROOT, '.tmp/b1-repair2-report.json'), JSON.stringify(out, null, 1));
