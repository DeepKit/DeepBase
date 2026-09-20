// 乙-B2 补审特征提取：对 .tmp/b2-uncovered.json 的单元输出紧凑机械面（LOC/类/资源原语旗标），供人工判审
// 用法: node b2_probe_uncovered.js  → .tmp/b2-uncovered-probe.txt
const fs = require('fs');
const path = require('path');
const ROOT = 'D:/_Progs/02Business/DeepBase';
const unc = JSON.parse(fs.readFileSync(path.join(ROOT, '.tmp/b2-uncovered.json'), 'utf8'));
const out = [];
for (const u of unc) {
  const txt = fs.readFileSync(path.join(ROOT, u.path), 'utf8');
  const lines = txt.split(/\r?\n/);
  const classes = [...txt.matchAll(/(\w+)\s*=\s*class(?:\(([^)]*)\))?/g)].map(m => m[1] + (m[2] ? ':' + m[2].split('.').pop() : ''));
  const flags = [];
  const test = (re, tag) => { const n = (txt.match(re) || []).length; if (n) flags.push(tag + '×' + n); };
  test(/\bTThread\b/g, 'TThread'); test(/FreeOnTerminate\s*:=\s*True/g, 'FreeOnTerm');
  test(/\.WaitFor\b/g, 'WaitFor'); test(/\bTCriticalSection\b/g, 'CritSec');
  test(/TThread\.Queue|Queue\(/g, 'TQueue'); test(/\bTTimer\b/g, 'Timer');
  test(/\bInterlocked\w+/g, 'Atomic'); test(/\bfinalization\b/g, 'finalization');
  test(/~\s*$|\bDestroy\b\s*;|destructor/g, 'Destroy'); test(/\bFireDAC|\bTFDConnection\b|sqlite/i, 'DB');
  test(/\bhttpclient\b|THTTP|\bNet\b\.HTTPClient/i, 'HTTP'); test(/\bcatch\(|\bexcept\b/g, 'Except');
  test(/\uFFFD/g, 'FFFD残留');
  const iface = (txt.match(/function\s|procedure\s/g) || []).length;
  out.push(`${u.path} | ${lines.length}L | procs:${iface} | ${classes.slice(0, 6).join(',') || '-'} | ${flags.join(' ') || '无资源旗标'}`);
}
fs.writeFileSync(path.join(ROOT, '.tmp/b2-uncovered-probe.txt'), out.join('\n'));
console.log('probed', out.length);
