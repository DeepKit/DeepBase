// 乙-B1 抢救执行器 v2。规则（H6：不猜字，只用 git 历史/盘上原始字节可证事实）：
//  R1 盘上仍是 GBK 原始字节 ⇒ gb18030 确定性转码 UTF-8+BOM
//  R2 盘上烤入 U+FFFD ⇒ 三元合并：C=最近干净祖先，D=损坏引入提交（base），W=现状。
//     W 中与 D 逐字相同的行（损坏后未被再编辑）→ 用 C 对应行恢复；
//     W 中被再编辑过的行 → 保持 W（真实后续工作优先），其残留 FFFFD 记入部分恢复。
//  R3 无干净祖先 ⇒ UNRECOVERABLE 保留现状。
// 用法: node b1_repair.js <probe.json> <scan.json> [--apply]
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const BOM = Buffer.from([0xEF, 0xBB, 0xBF]);
const NL = String.fromCharCode(10), CR = String.fromCharCode(13);

function gitShow(rev, p) {
  try {
    return execFileSync('git', ['-C', ROOT, 'show', `${rev}:${p}`], { maxBuffer: 256 * 1024 * 1024 });
  } catch (e) {
    if (e.stdout && e.stdout.length) return e.stdout; // stderr 警告导致的非0退出，内容完整可采信
    return null;
  }
}
function validUtf8(buf) { try { new TextDecoder('utf-8', { fatal: true }).decode(buf); return true; } catch (e) { return false; } }
function gbkDecode(buf) { return new TextDecoder('gb18030').decode(buf); }
function skel(s) { return s.replace(/[\u0080-\uFFFF\r]+/g, '?'); } // 压缩骨架：连续非ASCII→单个?（乱码长度≠原文长度，不能逐字对齐）
function asciiCtx(s) { return s.replace(/[\u0080-\uFFFF]+/g, ''); } // 去全部非ASCII串后的 ASCII 骨架（乱码/中文均消失，可直接比同源性）
function lines(txt) { return txt.replace(/^\uFEFF/, '').split(NL).map(s => s.endsWith(CR) ? s.slice(0, -1) : s); }
function stripBom(buf) { return buf.length >= 3 && buf[0] === 0xEF && buf[1] === 0xBB && buf[2] === 0xBF ? buf.slice(3) : buf; }

// LCS 对齐：返回 pairs=[[iW,iX],...]（骨架相等视为同位置）
function align(A, B) {
  const n = A.length, m = B.length;
  if ((n + 1) * (m + 1) > 4e7) return null; // 保护：超大矩阵放弃
  const dp = new Int32Array((n + 1) * (m + 1));
  const at = (i, j) => dp[i * (m + 1) + j];
  for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--)
    dp[i * (m + 1) + j] = A[i] === B[j] ? at(i + 1, j + 1) + 1 : Math.max(at(i + 1, j), at(i, j + 1));
  const pairs = [];
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (A[i] === B[j]) { pairs.push([i, j]); i++; j++; }
    else if (at(i + 1, j) >= at(i, j + 1)) i++;
    else j++;
  }
  return pairs;
}

const [,, probeP, scanP, applyFlag] = process.argv;
const APPLY = applyFlag === '--apply';
const probe = JSON.parse(fs.readFileSync(probeP, 'utf8'));

const report = [];
for (const pr of probe) {
  const f = pr.f, abs = path.join(ROOT, f);
  const buf = fs.readFileSync(abs);
  const rec = { f, rule: null, ffBefore: 0, ffAfter: 0, linesRestored: 0, linesEditedAfterDamage: 0, cleanRev: pr.cleanRev, cleanKind: pr.cleanKind, damageRev: pr.damageCommit || null, note: '' };
  const wStr = buf.toString('utf8');
  rec.ffBefore = wStr.split('\uFFFD').length - 1;

  let newText = null;
  if (!validUtf8(buf)) {
    const c = gbkDecode(stripBom(buf));
    if (!c.includes('\uFFFD')) { rec.rule = 'R1-GBK转码'; newText = c; }
    else rec.note = '混合受损(GBK+烤入FFFD)→走R2';
  }
  if (newText === null && rec.ffBefore > 0 && !rec.rule) {
    if (!pr.cleanRev) { rec.rule = 'R3-UNRECOVERABLE'; }
    else {
      let blob = gitShow(pr.cleanRev, pr.cleanPath);
      if (!blob) { rec.rule = 'R3-UNRECOVERABLE'; rec.note = '干净祖先取回失败'; }
      else {
        const cTxt = (pr.cleanKind === 'CLEAN_GBK' ? gbkDecode(stripBom(blob)) : stripBom(blob).toString('utf8'));
        if (cTxt.includes('\uFFFD')) { rec.rule = 'R3-UNRECOVERABLE'; rec.note = '干净祖先仍含FFFD'; }
        else {
          // W：盘上混合字节也用 gb18030 宽容解码以对齐
          const wTxt = validUtf8(buf) ? stripBom(buf).toString('utf8') : gbkDecode(stripBom(buf));
          const W = lines(wTxt), C = lines(cTxt);
          let Cmap = C, D = null;
          if (pr.damageCommit) {
            let dblob = gitShow(pr.damageCommit, pr.cleanPath) || gitShow(pr.damageCommit, f);
            if (dblob) {
              const dTxt = validUtf8(dblob) ? stripBom(dblob).toString('utf8') : gbkDecode(stripBom(dblob));
              const Dlines = lines(dTxt);
              const pairsCD = align(Dlines.map(skel), C.map(skel));
              if (pairsCD) {
                // D 行 → C 行 映射（仅骨架对齐对；D 独有行不在 C 中→其后继编辑保留 D 原文）
                Cmap = Dlines.map(() => null);
                for (const [iD, iC] of pairsCD) Cmap[iD] = C[iC];
                D = Dlines;
              }
            }
          }
          if (!D) { D = C; Cmap = C.map(x => x); } // 无损坏 base：退化为 W↔C 两两合并
          const pairsWD = align(W.map(skel), D.map(skel));
          if (!pairsWD) { rec.rule = 'R2-SKIP'; rec.note = '对齐矩阵过大'; }
          else {
            const wMatch = new Map();
            for (const [i, j] of pairsWD) wMatch.set(i, j);
            const out = W.map((w, i) => {
              if (!w.includes('\uFFFD')) return w; // 未受损行原样保留
              const j = wMatch.get(i);
              if (j === undefined) { rec.linesEditedAfterDamage++; return w; }
              const cj = Cmap[j];
              // 采纳条件：能取回 C 原文，且 W/D 同源（ASCII 结构一致），或 W 行与 D 行逐字相同
              if (cj !== null && (D[j] === w || asciiCtx(w) === asciiCtx(D[j]))) { rec.linesRestored++; return cj; }
              rec.linesEditedAfterDamage++;
              return w;
            });
            newText = out.join(NL);
            rec.ffAfter = (newText.match(/\uFFFD/g) || []).length;
            rec.rule = rec.ffAfter === 0 ? 'R2-全量恢复' : `R2-部分恢复(残留${rec.ffAfter})`;
          }
        }
      }
    }
  }

  if (newText !== null && (rec.rule === 'R1-GBK转码' || rec.ffAfter < rec.ffBefore)) {
    const crlf = wStr.includes(CR + NL);
    let body = newText.split(CR + NL).join(NL); if (crlf) body = body.split(NL).join(CR + NL);
    const outBuf = Buffer.concat([BOM, Buffer.from(body, 'utf8')]);
    rec.bytesDelta = outBuf.length - buf.length;
    if (APPLY && rec.rule !== 'R2-SKIP') fs.writeFileSync(abs, outBuf);
  }
  report.push(rec);
}
fs.writeFileSync(path.join(ROOT, '.tmp/b1-repair-report.json'), JSON.stringify(report, null, 1));
const byRule = {};
report.forEach(r => byRule[r.rule] = (byRule[r.rule] || 0) + 1);
console.log(APPLY ? '=== APPLIED ===' : '=== DRY RUN ===');
console.log(byRule);
report.filter(r => r.rule && r.rule !== 'R1-GBK转码' && r.rule !== 'R2-全量恢复')
  .forEach(r => console.log(r.f, '|', r.rule, '| editedAfterDamage:', r.linesEditedAfterDamage, '|', r.note));
