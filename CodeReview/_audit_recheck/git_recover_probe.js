// 乙-B1 git 取证：对每个受损文件，从 HEAD 往回找最近的"干净版本"（0×U+FFFD 且合法UTF-8），
// 并判断受损提交之后是否还有其他内容改动（决定整文件回滚 vs 行级合并 vs 不可恢复）。
// 用法: node git_recover_probe.js <files.json> <out.json>   files.json = ["path", ...]（仓库相对正斜杠）
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = 'D:/_Progs/02Business/DeepBase';

function git(args) {
  return execFileSync('git', ['-C', ROOT, ...args], { maxBuffer: 256 * 1024 * 1024 });
}
function validUtf8(buf) {
  try { new TextDecoder('utf-8', { fatal: true }).decode(buf); return true; } catch (e) { return false; }
}
function fffdCount(buf) { return buf.toString('utf8').split('\uFFFD').length - 1; }
// GBK/ANSI 原始字节版：非 UTF-8 但可用 gb18030 无损解码且无替换符 ⇒ 可确定性转码救回（非猜测）
function gbkClean(buf) {
  if (validUtf8(buf)) return false;
  let txt;
  try { txt = new TextDecoder('gb18030', { fatal: true }).decode(buf); }
  catch (e) { try { txt = new TextDecoder('gb18030').decode(buf); } catch (e2) { return false; } }
  return !txt.includes('\uFFFD');
}
function classifyBuf(buf) {
  const ff = fffdCount(buf);
  if (ff === 0 && validUtf8(buf)) return 'CLEAN_UTF8';
  if (gbkClean(buf)) return 'CLEAN_GBK';
  return 'DAMAGED';
}

const list = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const results = [];
for (const f of list) {
  const r = { f, cleanRev: null, cleanKind: null, cleanPath: null, commits: 0, damageCommit: null, note: '' };
  // --follow + name-only：每个 rev 后跟该提交中的实际路径（跨重命名可追）
  const raw = git(['log', '--follow', '--format=C%H', '--name-only', '--', f]).toString('utf8');
  const entries = []; // {rev, path}
  let curRev = null;
  for (const line of raw.split('\n')) {
    const s = line.trim();
    if (!s) continue;
    if (s.startsWith('C') && /^[0-9a-f]{40}$/.test(s.slice(1))) { curRev = s.slice(1); }
    else if (curRev) entries.push({ rev: curRev, p: s.replace(/\\/g, '/') });
  }
  r.commits = new Set(entries.map(e => e.rev)).size;
  let prevKind = null, prevRev = null;
  const seen = new Set();
  for (let i = 0; i < entries.length && i < 160; i++) {
    const { rev, p } = entries[i];
    if (seen.has(rev)) continue; seen.add(rev);
    const cur = p;
    let buf;
    try { buf = git(['show', `${rev}:${cur}`]); } catch (e) { r.note = 'show-fail:' + cur; break; }
    const kind = classifyBuf(buf);
    if (kind !== 'DAMAGED' && !r.cleanRev) {
      r.cleanRev = rev; r.cleanKind = kind; r.cleanPath = cur;
    }
    if (r.cleanRev) {
      r.commitsBetweenCleanAndHead = seen.size - 1; // 比 cleanRev 更新的提交数
      // 引入损坏的提交（三元合并 base）：紧接 cleanRev 之后(更新)的那个受损 rev，即 entries 中此位置之前的那一个
      // seen 按新→旧加入；rev=cleanRev；比它更新的是前一个加入的 prevRev… 需按序回取：
      const arr = [...seen];
      if (arr.length >= 2) r.damageCommit = arr[arr.length - 2]; // 紧邻更新提交（损坏引入点候选）
      break;
    }
  }
  if (!r.cleanRev) r.note = r.note || 'NO CLEAN REV IN HISTORY (首提交即受损或全史受损)';
  results.push(r);
  console.log(`${f} | commits=${r.commits} | cleanRev=${r.cleanRev ? r.cleanRev.slice(0, 8) : 'NONE'} (${r.cleanKind || '-'}) | gap=${r.commitsBetweenCleanAndHead ?? '-'} | damageRev=${r.damageCommit ? r.damageCommit.slice(0, 8) : '?'} | ${r.note}`);
}
fs.writeFileSync(process.argv[3], JSON.stringify(results, null, 1));
